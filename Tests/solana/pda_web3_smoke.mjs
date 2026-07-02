import {
  Keypair,
  PublicKey,
} from "@solana/web3.js";
import fs from "node:fs";

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function keypairFromByte(byte) {
  return Keypair.fromSeed(Uint8Array.from(Array(32).fill(byte & 0xff)));
}

function keypairFromCounter(counter) {
  const seed = new Uint8Array(32);
  seed[0] = counter & 0xff;
  seed[1] = (counter >> 8) & 0xff;
  seed[2] = (counter >> 16) & 0xff;
  seed[3] = (counter >> 24) & 0xff;
  for (let i = 4; i < seed.length; i += 1) {
    seed[i] = (counter + i * 17) & 0xff;
  }
  return Keypair.fromSeed(seed);
}

function bufferEquals(left, right) {
  return Buffer.compare(Buffer.from(left), Buffer.from(right)) === 0;
}

function require(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function resolveSeed(descriptor, context) {
  switch (descriptor.kind) {
    case "literal":
    case "utf8":
      return Buffer.from(descriptor.value, "utf8");
    case "account": {
      const account = context.accounts[descriptor.value];
      if (!account) {
        throw new Error(`missing account seed source: ${descriptor.value}`);
      }
      return account.toBuffer();
    }
    case "bump": {
      const bump = context.bumps[descriptor.value];
      if (!Number.isInteger(bump) || bump < 0 || bump > 255) {
        throw new Error(`missing u8 bump seed source: ${descriptor.value}`);
      }
      return Buffer.from([bump]);
    }
    case "instruction-param": {
      const param = context.params[descriptor.value];
      if (!param) {
        throw new Error(`missing instruction parameter seed source: ${descriptor.value}`);
      }
      return Buffer.from(param);
    }
    default:
      throw new Error(`unsupported PDA seed kind: ${descriptor.kind}`);
  }
}

function findAuthorityWithBump255(programId, literalSeed) {
  for (let attempt = 0; attempt < 4096; attempt += 1) {
    const authority = keypairFromCounter(attempt).publicKey;
    const seeds = [Buffer.from(literalSeed, "utf8"), authority.toBuffer()];
    const [pda, bump] = PublicKey.findProgramAddressSync(seeds, programId);
    if (bump === 255) {
      return { authority, pda, bump, attempt };
    }
  }
  throw new Error("failed to find deterministic authority with PDA bump=255");
}

function main() {
  const artifactPath = process.env.PROOF_FORGE_SOLANA_ARTIFACT;
  if (!artifactPath) {
    throw new Error("missing PROOF_FORGE_SOLANA_ARTIFACT");
  }

  const artifact = readJson(artifactPath);
  const pdas = artifact.solanaExtensions?.pdas ?? [];
  require(pdas.length > 0, "artifact missing Solana PDA extensions");
  const vault = pdas.find((pda) => pda.name === "vault");
  require(vault, "artifact missing vault PDA extension");

  const typedSeeds = vault.typedSeeds ?? [];
  require(JSON.stringify(vault.seeds) === JSON.stringify(["vault", "authority"]),
    `unexpected compatibility seeds: ${JSON.stringify(vault.seeds)}`);
  require(JSON.stringify(typedSeeds) === JSON.stringify([
    { kind: "literal", value: "vault" },
    { kind: "account", value: "authority" },
    { kind: "bump", value: "vault_bump" },
  ]), `unexpected typed seeds: ${JSON.stringify(typedSeeds)}`);

  const programId = keypairFromByte(42).publicKey;
  const literal = typedSeeds.find((seed) => seed.kind === "literal")?.value;
  require(literal === "vault", "vault PDA fixture should start with literal seed `vault`");
  const { authority, pda, bump, attempt } = findAuthorityWithBump255(programId, literal);
  const context = {
    accounts: { authority },
    bumps: { vault_bump: bump },
    params: {},
  };
  const resolvedSeeds = typedSeeds.map((seed) => resolveSeed(seed, context));
  const created = PublicKey.createProgramAddressSync(resolvedSeeds, programId);
  require(created.equals(pda),
    `createProgramAddressSync mismatch: created=${created.toBase58()} expected=${pda.toBase58()}`);

  const utf8Seed = resolveSeed({ kind: "utf8", value: "unicode-ok" }, context);
  require(bufferEquals(utf8Seed, Buffer.from("unicode-ok", "utf8")),
    "utf8 seed resolver mismatch");

  const paramValue = Buffer.alloc(8);
  paramValue.writeBigUInt64LE(42n, 0);
  const paramSeed = resolveSeed(
    { kind: "instruction-param", value: "amount" },
    { ...context, params: { amount: paramValue } },
  );
  require(bufferEquals(paramSeed, paramValue), "instruction-param seed resolver mismatch");

  console.log(JSON.stringify({
    pda: vault.name,
    programId: programId.toBase58(),
    authority: authority.toBase58(),
    bump,
    bumpSearchAttempt: attempt,
    derived: pda.toBase58(),
    created: created.toBase58(),
    typedSeedKinds: typedSeeds.map((seed) => seed.kind),
  }));
}

try {
  main();
} catch (err) {
  console.error(err);
  process.exit(1);
}

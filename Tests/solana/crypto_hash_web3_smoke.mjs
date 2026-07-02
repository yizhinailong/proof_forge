import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import crypto from "node:crypto";
import fs from "node:fs";

function readKeypair(path) {
  const bytes = JSON.parse(fs.readFileSync(path, "utf8"));
  return Keypair.fromSecretKey(Uint8Array.from(bytes));
}

function writeU64LE(value) {
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64LE(value, 0);
  return buffer;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendAndPollTransaction(connection, transaction, signers) {
  const latest = await connection.getLatestBlockhash("confirmed");
  transaction.recentBlockhash = latest.blockhash;
  transaction.feePayer = signers[0].publicKey;
  transaction.sign(...signers);
  const signature = await connection.sendRawTransaction(transaction.serialize(), {
    skipPreflight: false,
  });
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const statuses = await connection.getSignatureStatuses([signature], {
      searchTransactionHistory: true,
    });
    const status = statuses.value[0];
    if (status?.err) {
      throw new Error(`transaction ${signature} failed: ${JSON.stringify(status.err)}`);
    }
    if (status?.confirmationStatus === "confirmed" || status?.confirmationStatus === "finalized") {
      return signature;
    }
    await sleep(500);
  }
  throw new Error(`transaction ${signature} was not confirmed`);
}

async function createProgramState(connection, payer, programId, space) {
  const state = Keypair.generate();
  const lamports = await connection.getMinimumBalanceForRentExemption(space);
  const ix = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: state.publicKey,
    lamports,
    space,
    programId,
  });
  await sendAndPollTransaction(connection, new Transaction().add(ix), [payer, state]);
  return state;
}

function requireBufferEqual(actual, expected, label) {
  if (!Buffer.from(actual).equals(Buffer.from(expected))) {
    throw new Error(`${label} mismatch: expected ${Buffer.from(expected).toString("hex")}, got ${Buffer.from(actual).toString("hex")}`);
  }
}

async function main() {
  const rpcUrl = process.env.PROOF_FORGE_SOLANA_RPC_URL;
  const wsUrl = process.env.PROOF_FORGE_SOLANA_WS_URL;
  const payerPath = process.env.PROOF_FORGE_SOLANA_PAYER;
  const programIdValue = process.env.PROOF_FORGE_SOLANA_PROGRAM_ID;
  if (!rpcUrl || !payerPath || !programIdValue) {
    throw new Error("missing PROOF_FORGE_SOLANA_RPC_URL, PROOF_FORGE_SOLANA_PAYER, or PROOF_FORGE_SOLANA_PROGRAM_ID");
  }

  const connection = new Connection(rpcUrl, {
    commitment: "confirmed",
    wsEndpoint: wsUrl,
  });
  const payer = readKeypair(payerPath);
  const programId = new PublicKey(programIdValue);
  const state = await createProgramState(connection, payer, programId, 40);
  const preimageValue = 0x1122334455667788n;
  const preimageBytes = writeU64LE(preimageValue);

  const setPreimageIx = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.concat([Buffer.from([0]), preimageBytes]),
  });
  const setPreimageSignature = await sendAndPollTransaction(
    connection,
    new Transaction().add(setPreimageIx),
    [payer]
  );

  const hashIx = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.from([1]),
  });
  const hashSignature = await sendAndPollTransaction(
    connection,
    new Transaction().add(hashIx),
    [payer]
  );

  const account = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (account === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }

  requireBufferEqual(account.data.subarray(0, 8), preimageBytes, "preimage state");
  const actualDigest = account.data.subarray(8, 40);
  const expectedDigest = crypto.createHash("sha256").update(preimageBytes).digest();
  requireBufferEqual(actualDigest, expectedDigest, "sha256 digest");

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    setPreimageSignature,
    hashSignature,
    preimageHex: preimageBytes.toString("hex"),
    digestHex: Buffer.from(actualDigest).toString("hex"),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

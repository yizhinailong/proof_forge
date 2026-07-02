import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import fs from "node:fs";

function readKeypair(path) {
  const bytes = JSON.parse(fs.readFileSync(path, "utf8"));
  return Keypair.fromSecretKey(Uint8Array.from(bytes));
}

function readU64LE(data, offset) {
  if (data.length < offset + 8) {
    throw new Error(`expected at least ${offset + 8} bytes, got ${data.length}`);
  }
  return Buffer.from(data.subarray(offset, offset + 8)).readBigUInt64LE(0);
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
  const state = await createProgramState(connection, payer, programId, 32);
  const sourceValue = 0x1122334455667788n;

  const setSourceIx = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.concat([Buffer.from([0]), writeU64LE(sourceValue)]),
  });
  const setSourceSignature = await sendAndPollTransaction(
    connection,
    new Transaction().add(setSourceIx),
    [payer]
  );

  const memoryIx = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.from([1]),
  });
  const memorySignature = await sendAndPollTransaction(
    connection,
    new Transaction().add(memoryIx),
    [payer]
  );

  const account = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (account === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }

  const source = readU64LE(account.data, 0);
  const copied = readU64LE(account.data, 8);
  const filled = account.data.subarray(16, 24);
  const cmpResult = readU64LE(account.data, 24);
  if (source !== sourceValue) {
    throw new Error(`source mismatch: expected ${sourceValue}, got ${source}`);
  }
  if (copied !== sourceValue) {
    throw new Error(`copied mismatch: expected ${sourceValue}, got ${copied}`);
  }
  if (cmpResult !== 0n) {
    throw new Error(`memcmp result mismatch: expected 0, got ${cmpResult}`);
  }
  for (const byte of filled) {
    if (byte !== 0xaa) {
      throw new Error(`memset byte mismatch: expected 0xaa, got 0x${byte.toString(16)}`);
    }
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    setSourceSignature,
    memorySignature,
    source: source.toString(),
    copied: copied.toString(),
    cmpResult: cmpResult.toString(),
    filledHex: Buffer.from(filled).toString("hex"),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

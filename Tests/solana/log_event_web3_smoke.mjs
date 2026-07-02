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

function readU64LE(data) {
  if (data.length < 8) {
    throw new Error(`expected at least 8 bytes, got ${data.length}`);
  }
  return Buffer.from(data).readBigUInt64LE(0);
}

function writeEmitData(amount) {
  const data = Buffer.alloc(9);
  data[0] = 0;
  data.writeBigUInt64LE(amount, 1);
  return data;
}

function stableEventTag(name) {
  let acc = 5381n;
  const modulus = 4294967296n;
  for (const byte of Buffer.from(name, "utf8")) {
    acc = (acc * 33n + BigInt(byte)) % modulus;
  }
  return acc;
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

async function pollTransactionLogs(connection, signature) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const tx = await connection.getTransaction(signature, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    const logs = tx?.meta?.logMessages;
    if (logs && logs.length > 0) {
      return logs;
    }
    await sleep(500);
  }
  throw new Error(`transaction logs not available for ${signature}`);
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

function logContainsNumber(logs, value) {
  const decimal = value.toString(10);
  const hex = `0x${value.toString(16)}`;
  return logs.some((line) => line.includes(decimal) || line.toLowerCase().includes(hex));
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
  const state = await createProgramState(connection, payer, programId, 8);
  const amount = BigInt(process.env.PROOF_FORGE_SOLANA_LOG_AMOUNT ?? "42424242");
  const eventTag = stableEventTag("AmountEvent");

  const ix = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: writeEmitData(amount),
  });
  const signature = await sendAndPollTransaction(
    connection,
    new Transaction().add(ix),
    [payer]
  );

  const account = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (account === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  const recordedAmount = readU64LE(account.data);
  if (recordedAmount !== amount) {
    throw new Error(`state last_logged_amount mismatch: expected ${amount}, got ${recordedAmount}`);
  }

  const logs = await pollTransactionLogs(connection, signature);
  if (!logs.some((line) => line.includes("Program log:"))) {
    throw new Error(`expected at least one program log: ${JSON.stringify(logs)}`);
  }
  if (!logContainsNumber(logs, eventTag)) {
    throw new Error(`logs missing AmountEvent tag ${eventTag}: ${JSON.stringify(logs)}`);
  }
  if (!logContainsNumber(logs, amount)) {
    throw new Error(`logs missing amount ${amount}: ${JSON.stringify(logs)}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    signature,
    event: "AmountEvent",
    eventTag: eventTag.toString(),
    amount: amount.toString(),
    recordedAmount: recordedAmount.toString(),
    logs,
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

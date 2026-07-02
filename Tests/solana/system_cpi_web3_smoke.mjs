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
  return Number(Buffer.from(data).readBigUInt64LE(0));
}

function writeU64LE(value) {
  const data = Buffer.alloc(9);
  data[0] = 0;
  data.writeBigUInt64LE(BigInt(value), 1);
  return data;
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

async function createSystemRecipient(connection, payer) {
  const recipient = Keypair.generate();
  const lamports = await connection.getMinimumBalanceForRentExemption(0);
  const ix = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: recipient.publicKey,
    lamports,
    space: 0,
    programId: SystemProgram.programId,
  });
  await sendAndPollTransaction(connection, new Transaction().add(ix), [payer, recipient]);
  return recipient;
}

async function main() {
  const rpcUrl = process.env.PROOF_FORGE_SOLANA_RPC_URL;
  const payerPath = process.env.PROOF_FORGE_SOLANA_PAYER;
  const programIdValue = process.env.PROOF_FORGE_SOLANA_PROGRAM_ID;
  if (!rpcUrl || !payerPath || !programIdValue) {
    throw new Error("missing PROOF_FORGE_SOLANA_RPC_URL, PROOF_FORGE_SOLANA_PAYER, or PROOF_FORGE_SOLANA_PROGRAM_ID");
  }

  const connection = new Connection(rpcUrl, "confirmed");
  const payer = readKeypair(payerPath);
  const programId = new PublicKey(programIdValue);
  const state = await createProgramState(connection, payer, programId, 8);
  const recipient = await createSystemRecipient(connection, payer);

  const lamports = Number(process.env.PROOF_FORGE_SOLANA_TRANSFER_LAMPORTS ?? "5000");
  const recipientBefore = await connection.getBalance(recipient.publicKey, "confirmed");
  const payerBefore = await connection.getBalance(payer.publicKey, "confirmed");

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: state.publicKey, isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: true },
      { pubkey: recipient.publicKey, isSigner: false, isWritable: true },
      { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
    ],
    data: writeU64LE(lamports),
  });
  const signature = await sendAndPollTransaction(connection, new Transaction().add(ix), [payer]);

  const recipientAfter = await connection.getBalance(recipient.publicKey, "confirmed");
  const payerAfter = await connection.getBalance(payer.publicKey, "confirmed");
  const delta = recipientAfter - recipientBefore;
  if (delta !== lamports) {
    throw new Error(`recipient lamports delta mismatch: expected ${lamports}, got ${delta}`);
  }
  if (payerAfter >= payerBefore) {
    throw new Error(`payer balance did not decrease: before=${payerBefore} after=${payerAfter}`);
  }

  const stateAccount = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (stateAccount === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  const recorded = readU64LE(stateAccount.data);
  if (recorded !== lamports) {
    throw new Error(`state last_transfer_lamports mismatch: expected ${lamports}, got ${recorded}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    recipient: recipient.publicKey.toBase58(),
    signature,
    lamports,
    recipientBefore,
    recipientAfter,
    recorded,
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

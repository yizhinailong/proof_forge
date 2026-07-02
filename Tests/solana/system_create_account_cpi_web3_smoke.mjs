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

function readU64LEAt(data, offset) {
  if (data.length < offset + 8) {
    throw new Error(`expected at least ${offset + 8} bytes, got ${data.length}`);
  }
  return Number(Buffer.from(data).readBigUInt64LE(offset));
}

function writeCreateData(lamports, space) {
  const data = Buffer.alloc(17);
  data[0] = 0;
  data.writeBigUInt64LE(BigInt(lamports), 1);
  data.writeBigUInt64LE(BigInt(space), 9);
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
  const state = await createProgramState(connection, payer, programId, 16);
  const newAccount = Keypair.generate();
  const space = Number(process.env.PROOF_FORGE_SOLANA_CREATE_SPACE ?? "24");
  const lamports = Number(
    process.env.PROOF_FORGE_SOLANA_CREATE_LAMPORTS ??
      await connection.getMinimumBalanceForRentExemption(space)
  );

  const before = await connection.getAccountInfo(newAccount.publicKey, "confirmed");
  if (before !== null) {
    throw new Error(`new account unexpectedly exists: ${newAccount.publicKey.toBase58()}`);
  }
  const payerBefore = await connection.getBalance(payer.publicKey, "confirmed");

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: state.publicKey, isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: true },
      { pubkey: newAccount.publicKey, isSigner: true, isWritable: true },
      { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
    ],
    data: writeCreateData(lamports, space),
  });
  const signature = await sendAndPollTransaction(
    connection,
    new Transaction().add(ix),
    [payer, newAccount]
  );

  const created = await connection.getAccountInfo(newAccount.publicKey, "confirmed");
  if (created === null) {
    throw new Error(`created account not found: ${newAccount.publicKey.toBase58()}`);
  }
  if (!created.owner.equals(programId)) {
    throw new Error(`created account owner mismatch: expected ${programId.toBase58()}, got ${created.owner.toBase58()}`);
  }
  if (created.data.length !== space) {
    throw new Error(`created account data length mismatch: expected ${space}, got ${created.data.length}`);
  }
  if (created.lamports !== lamports) {
    throw new Error(`created account lamports mismatch: expected ${lamports}, got ${created.lamports}`);
  }
  const payerAfter = await connection.getBalance(payer.publicKey, "confirmed");
  if (payerAfter >= payerBefore) {
    throw new Error(`payer balance did not decrease: before=${payerBefore} after=${payerAfter}`);
  }

  const stateAccount = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (stateAccount === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  const recordedLamports = readU64LEAt(stateAccount.data, 0);
  const recordedSpace = readU64LEAt(stateAccount.data, 8);
  if (recordedLamports !== lamports) {
    throw new Error(`state last_created_lamports mismatch: expected ${lamports}, got ${recordedLamports}`);
  }
  if (recordedSpace !== space) {
    throw new Error(`state last_created_space mismatch: expected ${space}, got ${recordedSpace}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    created: newAccount.publicKey.toBase58(),
    signature,
    lamports,
    space,
    recordedLamports,
    recordedSpace,
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

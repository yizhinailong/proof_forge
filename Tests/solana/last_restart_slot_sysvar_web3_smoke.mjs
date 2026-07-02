import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import fs from "node:fs";

const SYSVAR_LAST_RESTART_SLOT_PUBKEY = new PublicKey("SysvarLastRestartS1ot1111111111111111111111");

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
  const state = await createProgramState(connection, payer, programId, 8);

  const lastRestartSlotAccount = await connection.getAccountInfo(SYSVAR_LAST_RESTART_SLOT_PUBKEY, "confirmed");
  if (lastRestartSlotAccount === null) {
    throw new Error(`LastRestartSlot sysvar account not found: ${SYSVAR_LAST_RESTART_SLOT_PUBKEY.toBase58()}`);
  }
  const expectedLastRestartSlot = readU64LE(lastRestartSlotAccount.data);

  const ix = new TransactionInstruction({
    programId,
    keys: [{ pubkey: state.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.from([0]),
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
  const recordedLastRestartSlot = readU64LE(account.data);
  if (recordedLastRestartSlot !== expectedLastRestartSlot) {
    throw new Error(
      `LastRestartSlot mismatch: recorded=${recordedLastRestartSlot} expected=${expectedLastRestartSlot}`
    );
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    signature,
    recordedLastRestartSlot: recordedLastRestartSlot.toString(),
    expectedLastRestartSlot: expectedLastRestartSlot.toString(),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

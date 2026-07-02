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

function readU64LE(data, offset = 0) {
  if (data.length < offset + 8) {
    throw new Error(`expected at least ${offset + 8} bytes, got ${data.length}`);
  }
  return Buffer.from(data).readBigUInt64LE(offset);
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
  const state = await createProgramState(connection, payer, programId, 40);
  const epochSchedule = await connection.getEpochSchedule();
  const expectedSlotsPerEpoch = BigInt(epochSchedule.slotsPerEpoch);
  const expectedLeaderScheduleSlotOffset = BigInt(epochSchedule.leaderScheduleSlotOffset);
  const expectedWarmup = epochSchedule.warmup ? 1n : 0n;
  const expectedFirstNormalEpoch = BigInt(epochSchedule.firstNormalEpoch);
  const expectedFirstNormalSlot = BigInt(epochSchedule.firstNormalSlot);
  if (expectedSlotsPerEpoch === 0n) {
    throw new Error("RPC EpochSchedule.slotsPerEpoch was zero");
  }
  if (expectedLeaderScheduleSlotOffset === 0n) {
    throw new Error("RPC EpochSchedule.leaderScheduleSlotOffset was zero");
  }

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
  const recordedSlotsPerEpoch = readU64LE(account.data, 0);
  if (recordedSlotsPerEpoch !== expectedSlotsPerEpoch) {
    throw new Error(
      `EpochSchedule.slots_per_epoch mismatch: recorded=${recordedSlotsPerEpoch} expected=${expectedSlotsPerEpoch}`
    );
  }
  const recordedLeaderScheduleSlotOffset = readU64LE(account.data, 8);
  if (recordedLeaderScheduleSlotOffset !== expectedLeaderScheduleSlotOffset) {
    throw new Error(
      `EpochSchedule.leader_schedule_slot_offset mismatch: recorded=${recordedLeaderScheduleSlotOffset} expected=${expectedLeaderScheduleSlotOffset}`
    );
  }
  const recordedWarmup = readU64LE(account.data, 16);
  if (recordedWarmup !== expectedWarmup) {
    throw new Error(
      `EpochSchedule.warmup mismatch: recorded=${recordedWarmup} expected=${expectedWarmup}`
    );
  }
  const recordedFirstNormalEpoch = readU64LE(account.data, 24);
  if (recordedFirstNormalEpoch !== expectedFirstNormalEpoch) {
    throw new Error(
      `EpochSchedule.first_normal_epoch mismatch: recorded=${recordedFirstNormalEpoch} expected=${expectedFirstNormalEpoch}`
    );
  }
  const recordedFirstNormalSlot = readU64LE(account.data, 32);
  if (recordedFirstNormalSlot !== expectedFirstNormalSlot) {
    throw new Error(
      `EpochSchedule.first_normal_slot mismatch: recorded=${recordedFirstNormalSlot} expected=${expectedFirstNormalSlot}`
    );
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    signature,
    recordedSlotsPerEpoch: recordedSlotsPerEpoch.toString(),
    expectedSlotsPerEpoch: expectedSlotsPerEpoch.toString(),
    recordedLeaderScheduleSlotOffset: recordedLeaderScheduleSlotOffset.toString(),
    expectedLeaderScheduleSlotOffset: expectedLeaderScheduleSlotOffset.toString(),
    recordedWarmup: recordedWarmup.toString(),
    expectedWarmup: expectedWarmup.toString(),
    recordedFirstNormalEpoch: recordedFirstNormalEpoch.toString(),
    expectedFirstNormalEpoch: expectedFirstNormalEpoch.toString(),
    recordedFirstNormalSlot: recordedFirstNormalSlot.toString(),
    expectedFirstNormalSlot: expectedFirstNormalSlot.toString(),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

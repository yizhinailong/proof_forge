import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import fs from "node:fs";

const SYSVAR_EPOCH_REWARDS_PUBKEY = new PublicKey("SysvarEpochRewards1111111111111111111111111");

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

function readBoolAsU64(data, offset) {
  if (data.length < offset + 1) {
    throw new Error(`expected at least ${offset + 1} bytes, got ${data.length}`);
  }
  return data[offset] === 0 ? 0n : 1n;
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

function expectedEpochRewardsWords(sysvarData) {
  return [
    ["distribution_starting_block_height", readU64LE(sysvarData, 0)],
    ["num_partitions", readU64LE(sysvarData, 8)],
    ["parent_blockhash_word0", readU64LE(sysvarData, 16)],
    ["parent_blockhash_word1", readU64LE(sysvarData, 24)],
    ["parent_blockhash_word2", readU64LE(sysvarData, 32)],
    ["parent_blockhash_word3", readU64LE(sysvarData, 40)],
    ["total_points_low", readU64LE(sysvarData, 48)],
    ["total_points_high", readU64LE(sysvarData, 56)],
    ["total_rewards", readU64LE(sysvarData, 64)],
    ["distributed_rewards", readU64LE(sysvarData, 72)],
    ["active", readBoolAsU64(sysvarData, 80)],
  ];
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
  const state = await createProgramState(connection, payer, programId, 88);

  const epochRewardsAccount = await connection.getAccountInfo(SYSVAR_EPOCH_REWARDS_PUBKEY, "confirmed");
  if (epochRewardsAccount === null) {
    throw new Error(`EpochRewards sysvar account not found: ${SYSVAR_EPOCH_REWARDS_PUBKEY.toBase58()}`);
  }
  const expected = expectedEpochRewardsWords(epochRewardsAccount.data);

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

  const recorded = [];
  for (const [index, [name, expectedValue]] of expected.entries()) {
    const recordedValue = readU64LE(account.data, index * 8);
    recorded.push([name, recordedValue]);
    if (recordedValue !== expectedValue) {
      throw new Error(
        `EpochRewards.${name} mismatch: recorded=${recordedValue} expected=${expectedValue}`
      );
    }
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    signature,
    sysvar: SYSVAR_EPOCH_REWARDS_PUBKEY.toBase58(),
    recorded: Object.fromEntries(recorded.map(([name, value]) => [name, value.toString()])),
    expected: Object.fromEntries(expected.map(([name, value]) => [name, value.toString()])),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

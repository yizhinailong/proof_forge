import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
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
  return Number(data.readBigUInt64LE(0));
}

async function sendCounterInstruction(connection, payer, programId, counter, tag) {
  const ix = new TransactionInstruction({
    programId,
    keys: [{ pubkey: counter.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.from([tag]),
  });
  return await sendAndConfirmTransaction(connection, new Transaction().add(ix), [payer], {
    commitment: "confirmed",
  });
}

async function fetchCounter(connection, counter) {
  const account = await connection.getAccountInfo(counter.publicKey, "confirmed");
  if (account === null) {
    throw new Error(`counter account not found: ${counter.publicKey.toBase58()}`);
  }
  return readU64LE(Buffer.from(account.data));
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
  const counter = Keypair.generate();

  const rentLamports = await connection.getMinimumBalanceForRentExemption(8);
  const createCounter = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: counter.publicKey,
    lamports: rentLamports,
    space: 8,
    programId,
  });
  await sendAndConfirmTransaction(connection, new Transaction().add(createCounter), [payer, counter], {
    commitment: "confirmed",
  });

  await sendCounterInstruction(connection, payer, programId, counter, 0);
  const afterInitialize = await fetchCounter(connection, counter);
  if (afterInitialize !== 0) {
    throw new Error(`initialize expected counter=0, got ${afterInitialize}`);
  }

  await sendCounterInstruction(connection, payer, programId, counter, 1);
  const afterIncrement = await fetchCounter(connection, counter);
  if (afterIncrement !== 1) {
    throw new Error(`increment expected counter=1, got ${afterIncrement}`);
  }

  await sendCounterInstruction(connection, payer, programId, counter, 1);
  const afterSecondIncrement = await fetchCounter(connection, counter);
  if (afterSecondIncrement !== 2) {
    throw new Error(`second increment expected counter=2, got ${afterSecondIncrement}`);
  }

  const getIx = new TransactionInstruction({
    programId,
    keys: [{ pubkey: counter.publicKey, isSigner: false, isWritable: true }],
    data: Buffer.from([2]),
  });
  const sim = await connection.simulateTransaction(new Transaction().add(getIx), [payer]);
  if (sim.value.err) {
    throw new Error(`get simulation failed: ${JSON.stringify(sim.value.err)}`);
  }
  const returnData = sim.value.returnData;
  if (!returnData || returnData.programId !== programId.toBase58()) {
    throw new Error(`get simulation missing return data for ${programId.toBase58()}`);
  }
  const [encoded, encoding] = returnData.data;
  if (encoding !== "base64") {
    throw new Error(`expected base64 return data, got ${encoding}`);
  }
  const returned = readU64LE(Buffer.from(encoded, "base64"));
  if (returned !== 2) {
    throw new Error(`get expected return_data=2, got ${returned}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    counter: counter.publicKey.toBase58(),
    afterInitialize,
    afterIncrement,
    afterSecondIncrement,
    getReturnData: returned,
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

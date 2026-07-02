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

function readArtifact(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
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

function instructionByName(artifact, name) {
  const instruction = (artifact.solanaInstructions ?? []).find((entry) => entry.name === name);
  if (!instruction) {
    throw new Error(`instruction ${name} not found in artifact`);
  }
  return instruction;
}

function instructionData(artifact, name, value = undefined) {
  const instruction = instructionByName(artifact, name);
  if (typeof instruction.tag !== "number") {
    throw new Error(`instruction ${name} missing numeric tag`);
  }
  if (value === undefined) {
    return Buffer.from([instruction.tag]);
  }
  return Buffer.concat([Buffer.from([instruction.tag]), writeU64LE(value)]);
}

function buildKeys(instruction, state) {
  const accounts = instruction.accounts ?? [];
  const accountNames = accounts.map((account) => account.name);
  if (JSON.stringify(accountNames) !== JSON.stringify(["result"])) {
    throw new Error(`unexpected account schema for ${instruction.name}: ${JSON.stringify(accountNames)}`);
  }
  return accounts.map((account) => ({
    pubkey: state.publicKey,
    isSigner: account.signer === true,
    isWritable: account.writable === true,
  }));
}

function decodeReturnData(returnData) {
  if (!returnData) {
    throw new Error("missing return data");
  }
  const [encoded, encoding] = returnData.data;
  if (encoding !== "base64") {
    throw new Error(`expected base64 return data, got ${encoding}`);
  }
  return Buffer.from(encoded, "base64");
}

function programIdWords(programId) {
  const bytes = Buffer.from(programId.toBytes());
  return [0, 8, 16, 24].map((offset) => readU64LE(bytes, offset));
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

async function invoke(connection, payer, programId, artifact, state, name, value = undefined) {
  const instruction = instructionByName(artifact, name);
  const ix = new TransactionInstruction({
    programId,
    keys: buildKeys(instruction, state),
    data: instructionData(artifact, name, value),
  });
  return sendAndPollTransaction(connection, new Transaction().add(ix), [payer]);
}

async function simulate(connection, payer, programId, artifact, state, name, value = undefined) {
  const instruction = instructionByName(artifact, name);
  const ix = new TransactionInstruction({
    programId,
    keys: buildKeys(instruction, state),
    data: instructionData(artifact, name, value),
  });
  const result = await connection.simulateTransaction(new Transaction().add(ix), [payer]);
  if (result.value.err) {
    throw new Error(`${name} simulation failed: ${JSON.stringify(result.value.err)}`);
  }
  return result.value;
}

async function fetchState(connection, state) {
  const account = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (account === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  return account.data;
}

function assertStateWords(data, expected) {
  const entries = [
    ["result", 0],
    ["last_return", 8],
    ["return_len", 16],
    ["return_program0", 24],
    ["return_program1", 32],
    ["return_program2", 40],
    ["return_program3", 48],
    ["remaining", 56],
  ];
  for (const [name, offset] of entries) {
    if (!(name in expected)) {
      continue;
    }
    const actual = readU64LE(data, offset);
    if (actual !== expected[name]) {
      throw new Error(`${name} mismatch: expected ${expected[name]}, got ${actual}`);
    }
  }
}

async function main() {
  const rpcUrl = process.env.PROOF_FORGE_SOLANA_RPC_URL;
  const wsUrl = process.env.PROOF_FORGE_SOLANA_WS_URL;
  const payerPath = process.env.PROOF_FORGE_SOLANA_PAYER;
  const programIdValue = process.env.PROOF_FORGE_SOLANA_PROGRAM_ID;
  const artifactPath = process.env.PROOF_FORGE_SOLANA_ARTIFACT;
  if (!rpcUrl || !payerPath || !programIdValue || !artifactPath) {
    throw new Error("missing PROOF_FORGE_SOLANA_RPC_URL, PROOF_FORGE_SOLANA_PAYER, PROOF_FORGE_SOLANA_PROGRAM_ID, or PROOF_FORGE_SOLANA_ARTIFACT");
  }

  const artifact = readArtifact(artifactPath);
  const expectedInstructionNames = [
    "set_result",
    "publish_result",
    "record_compute",
    "read_return_data",
    "log_compute",
    "roundtrip_return_data",
  ];
  const actualInstructionNames = (artifact.solanaInstructions ?? []).map((instruction) => instruction.name);
  if (JSON.stringify(actualInstructionNames) !== JSON.stringify(expectedInstructionNames)) {
    throw new Error(`instruction schema mismatch: ${JSON.stringify(actualInstructionNames)}`);
  }

  const connection = new Connection(rpcUrl, {
    commitment: "confirmed",
    wsEndpoint: wsUrl,
  });
  const payer = readKeypair(payerPath);
  const programId = new PublicKey(programIdValue);
  const state = await createProgramState(connection, payer, programId, 64);
  const resultValue = BigInt(process.env.PROOF_FORGE_SOLANA_RETURN_DATA_VALUE ?? "72623859790382856");

  const setSignature = await invoke(connection, payer, programId, artifact, state, "set_result", resultValue);
  let stateData = await fetchState(connection, state);
  assertStateWords(stateData, {
    result: resultValue,
    last_return: 0n,
    return_len: 0n,
    return_program0: 0n,
    return_program1: 0n,
    return_program2: 0n,
    return_program3: 0n,
    remaining: 0n,
  });

  const emptyReadSignature = await invoke(connection, payer, programId, artifact, state, "read_return_data");
  stateData = await fetchState(connection, state);
  assertStateWords(stateData, {
    result: resultValue,
    last_return: 0n,
    return_len: 0n,
    return_program0: 0n,
    return_program1: 0n,
    return_program2: 0n,
    return_program3: 0n,
  });

  const publishSimulation = await simulate(connection, payer, programId, artifact, state, "publish_result");
  const publishReturnData = decodeReturnData(publishSimulation.returnData);
  const publishedValue = readU64LE(publishReturnData, 0);
  if (publishedValue !== resultValue || publishSimulation.returnData.programId !== programId.toBase58()) {
    throw new Error(`publish_result return data mismatch: value=${publishedValue} program=${publishSimulation.returnData.programId}`);
  }

  const roundtripSignature = await invoke(connection, payer, programId, artifact, state, "roundtrip_return_data");
  stateData = await fetchState(connection, state);
  const [program0, program1, program2, program3] = programIdWords(programId);
  assertStateWords(stateData, {
    result: resultValue,
    last_return: resultValue,
    return_len: 8n,
    return_program0: program0,
    return_program1: program1,
    return_program2: program2,
    return_program3: program3,
  });

  const recordComputeSignature = await invoke(connection, payer, programId, artifact, state, "record_compute");
  stateData = await fetchState(connection, state);
  const remaining = readU64LE(stateData, 56);
  if (remaining === 0n) {
    throw new Error("remaining compute units should be nonzero");
  }

  const logComputeSignature = await invoke(connection, payer, programId, artifact, state, "log_compute");
  const logLines = await pollTransactionLogs(connection, logComputeSignature);
  const hasComputeLog = logLines.some((line) => {
    const normalized = line.toLowerCase();
    return normalized.includes("remaining") || normalized.includes("consumed");
  });
  if (!hasComputeLog) {
    throw new Error(`compute-unit logs missing remaining/consumed marker: ${JSON.stringify(logLines)}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    setSignature,
    emptyReadSignature,
    roundtripSignature,
    recordComputeSignature,
    logComputeSignature,
    publishedValue: publishedValue.toString(),
    roundtripValue: readU64LE(stateData, 8).toString(),
    returnLen: readU64LE(stateData, 16).toString(),
    remaining: remaining.toString(),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

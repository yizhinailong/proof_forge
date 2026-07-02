import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  createMint,
  getAccount,
  getMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";
import fs from "node:fs";

function readKeypair(path) {
  const bytes = JSON.parse(fs.readFileSync(path, "utf8"));
  return Keypair.fromSecretKey(Uint8Array.from(bytes));
}

function readU64LEAt(data, offset) {
  if (data.length < offset + 8) {
    throw new Error(`expected at least ${offset + 8} bytes, got ${data.length}`);
  }
  return Buffer.from(data).readBigUInt64LE(offset);
}

function writeInstructionData(tag, amount = undefined) {
  if (amount === undefined) {
    return Buffer.from([tag]);
  }
  const data = Buffer.alloc(9);
  data[0] = tag;
  data.writeBigUInt64LE(amount, 1);
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

function readArtifact(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function validateInstructionSchemas(artifact) {
  const instructions = artifact.solanaInstructions ?? [];
  const names = instructions.map((instruction) => instruction.name);
  const expectedNames = ["mint", "burn", "approve", "revoke"];
  if (JSON.stringify(names) !== JSON.stringify(expectedNames)) {
    throw new Error(`instruction names mismatch: ${JSON.stringify(names)}`);
  }
  const baseAccounts = instructions[0].accounts ?? [];
  const baseAccountNames = baseAccounts.map((account) => account.name);
  for (const instruction of instructions) {
    const accountNames = (instruction.accounts ?? []).map((account) => account.name);
    if (JSON.stringify(accountNames) !== JSON.stringify(baseAccountNames)) {
      throw new Error(`instruction ${instruction.name} account schema differs: ${JSON.stringify(accountNames)}`);
    }
  }
  for (const instruction of instructions.slice(0, 3)) {
    const params = instruction.params ?? [];
    const expectedParams = [
      { name: "amount", type: "U64", offset: 1, byteSize: 8, encoding: "le-u64" },
    ];
    if (JSON.stringify(params) !== JSON.stringify(expectedParams)) {
      throw new Error(`instruction ${instruction.name} params mismatch: ${JSON.stringify(params)}`);
    }
  }
  if ((instructions[3].params ?? []).length !== 0) {
    throw new Error(`revoke should not declare params: ${JSON.stringify(instructions[3].params)}`);
  }
  return baseAccounts;
}

function buildKeys(accounts, pubkeys) {
  return accounts.map((account) => {
    const pubkey = pubkeys[account.name];
    if (!pubkey) {
      throw new Error(`missing pubkey for account ${account.name}`);
    }
    return {
      pubkey,
      isSigner: account.signer === true,
      isWritable: account.writable === true,
    };
  });
}

function assertTokenAccountAmount(label, account, expected) {
  if (account.amount !== expected) {
    throw new Error(`${label} amount mismatch: expected ${expected}, got ${account.amount}`);
  }
}

async function invoke(connection, payer, programId, keys, tag, amount = undefined) {
  const ix = new TransactionInstruction({
    programId,
    keys,
    data: writeInstructionData(tag, amount),
  });
  return sendAndPollTransaction(connection, new Transaction().add(ix), [payer]);
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
  const accounts = validateInstructionSchemas(artifact);
  const connection = new Connection(rpcUrl, {
    commitment: "confirmed",
    wsEndpoint: wsUrl,
  });
  const payer = readKeypair(payerPath);
  const programId = new PublicKey(programIdValue);
  const state = await createProgramState(connection, payer, programId, 32);
  const decimals = Number(process.env.PROOF_FORGE_SOLANA_TOKEN_DECIMALS ?? "9");
  const initialSourceAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_INITIAL_SOURCE_AMOUNT ?? "1000000000");
  const mintAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_MINT_AMOUNT ?? "125000000");
  const burnAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_BURN_AMOUNT ?? "75000000");
  const approveAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_APPROVE_AMOUNT ?? "333000000");
  if (initialSourceAmount < burnAmount) {
    throw new Error(`initial source amount ${initialSourceAmount} is smaller than burn amount ${burnAmount}`);
  }

  const recipient = Keypair.generate();
  const delegate = Keypair.generate();
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey,
    null,
    decimals,
    undefined,
    { commitment: "confirmed" },
    TOKEN_PROGRAM_ID
  );
  const source = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    payer.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_PROGRAM_ID
  );
  const destination = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    recipient.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_PROGRAM_ID
  );
  await mintTo(
    connection,
    payer,
    mint,
    source.address,
    payer,
    initialSourceAmount,
    [],
    { commitment: "confirmed" },
    TOKEN_PROGRAM_ID
  );

  const pubkeys = {
    last_mint_amount: state.publicKey,
    mint,
    destination: destination.address,
    authority: payer.publicKey,
    spl_token: TOKEN_PROGRAM_ID,
    source: source.address,
    delegate: delegate.publicKey,
  };
  const keys = buildKeys(accounts, pubkeys);

  const sourceBefore = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  const destinationBefore = await getAccount(connection, destination.address, "confirmed", TOKEN_PROGRAM_ID);
  const mintBefore = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);

  const mintSignature = await invoke(connection, payer, programId, keys, 0, mintAmount);
  const destinationAfterMint = await getAccount(connection, destination.address, "confirmed", TOKEN_PROGRAM_ID);
  const mintAfterMint = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  assertTokenAccountAmount("destination after mint", destinationAfterMint, destinationBefore.amount + mintAmount);
  if (mintAfterMint.supply !== mintBefore.supply + mintAmount) {
    throw new Error(`mint supply after mint mismatch: expected ${mintBefore.supply + mintAmount}, got ${mintAfterMint.supply}`);
  }

  const burnSignature = await invoke(connection, payer, programId, keys, 1, burnAmount);
  const sourceAfterBurn = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  const mintAfterBurn = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  assertTokenAccountAmount("source after burn", sourceAfterBurn, sourceBefore.amount - burnAmount);
  if (mintAfterBurn.supply !== mintAfterMint.supply - burnAmount) {
    throw new Error(`mint supply after burn mismatch: expected ${mintAfterMint.supply - burnAmount}, got ${mintAfterBurn.supply}`);
  }

  const approveSignature = await invoke(connection, payer, programId, keys, 2, approveAmount);
  const sourceAfterApprove = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  if (!sourceAfterApprove.delegate?.equals(delegate.publicKey)) {
    throw new Error(`source delegate mismatch after approve: ${sourceAfterApprove.delegate?.toBase58() ?? "none"}`);
  }
  if (sourceAfterApprove.delegatedAmount !== approveAmount) {
    throw new Error(`delegated amount mismatch: expected ${approveAmount}, got ${sourceAfterApprove.delegatedAmount}`);
  }

  const revokeSignature = await invoke(connection, payer, programId, keys, 3);
  const sourceAfterRevoke = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  if (sourceAfterRevoke.delegate !== null) {
    throw new Error(`delegate should be cleared after revoke: ${sourceAfterRevoke.delegate.toBase58()}`);
  }
  if (sourceAfterRevoke.delegatedAmount !== 0n) {
    throw new Error(`delegated amount should be zero after revoke: ${sourceAfterRevoke.delegatedAmount}`);
  }

  const stateAccount = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (stateAccount === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  const recordedMint = readU64LEAt(stateAccount.data, 0);
  const recordedBurn = readU64LEAt(stateAccount.data, 8);
  const recordedApprove = readU64LEAt(stateAccount.data, 16);
  const recordedRevoke = readU64LEAt(stateAccount.data, 24);
  if (recordedMint !== mintAmount) {
    throw new Error(`state last_mint_amount mismatch: expected ${mintAmount}, got ${recordedMint}`);
  }
  if (recordedBurn !== burnAmount) {
    throw new Error(`state last_burn_amount mismatch: expected ${burnAmount}, got ${recordedBurn}`);
  }
  if (recordedApprove !== approveAmount) {
    throw new Error(`state last_approve_amount mismatch: expected ${approveAmount}, got ${recordedApprove}`);
  }
  if (recordedRevoke !== 1n) {
    throw new Error(`state last_revoke_marker mismatch: expected 1, got ${recordedRevoke}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    mint: mint.toBase58(),
    source: source.address.toBase58(),
    destination: destination.address.toBase58(),
    delegate: delegate.publicKey.toBase58(),
    tokenProgram: TOKEN_PROGRAM_ID.toBase58(),
    signatures: {
      mint: mintSignature,
      burn: burnSignature,
      approve: approveSignature,
      revoke: revokeSignature,
    },
    decimals,
    mintAmount: mintAmount.toString(),
    burnAmount: burnAmount.toString(),
    approveAmount: approveAmount.toString(),
    sourceBefore: sourceBefore.amount.toString(),
    sourceAfterBurn: sourceAfterBurn.amount.toString(),
    destinationBefore: destinationBefore.amount.toString(),
    destinationAfterMint: destinationAfterMint.amount.toString(),
    supplyBefore: mintBefore.supply.toString(),
    supplyAfterMint: mintAfterMint.supply.toString(),
    supplyAfterBurn: mintAfterBurn.supply.toString(),
    recordedMint: recordedMint.toString(),
    recordedBurn: recordedBurn.toString(),
    recordedApprove: recordedApprove.toString(),
    recordedRevoke: recordedRevoke.toString(),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

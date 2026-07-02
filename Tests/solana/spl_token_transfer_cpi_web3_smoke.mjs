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

function writeTransferData(amount) {
  const data = Buffer.alloc(9);
  data[0] = 0;
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
  const decimals = Number(process.env.PROOF_FORGE_SOLANA_TOKEN_DECIMALS ?? "9");
  const transferAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_TRANSFER_AMOUNT ?? "250000000");
  const initialAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_INITIAL_AMOUNT ?? "1000000000");
  if (transferAmount <= 0n) {
    throw new Error(`transfer amount must be positive: ${transferAmount}`);
  }
  if (initialAmount < transferAmount) {
    throw new Error(`initial amount ${initialAmount} is smaller than transfer amount ${transferAmount}`);
  }

  const recipient = Keypair.generate();
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
    initialAmount,
    [],
    { commitment: "confirmed" },
    TOKEN_PROGRAM_ID
  );

  const sourceBefore = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  const destinationBefore = await getAccount(connection, destination.address, "confirmed", TOKEN_PROGRAM_ID);

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: state.publicKey, isSigner: false, isWritable: true },
      { pubkey: source.address, isSigner: false, isWritable: true },
      { pubkey: mint, isSigner: false, isWritable: false },
      { pubkey: destination.address, isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data: writeTransferData(transferAmount),
  });
  const signature = await sendAndPollTransaction(
    connection,
    new Transaction().add(ix),
    [payer]
  );

  const sourceAfter = await getAccount(connection, source.address, "confirmed", TOKEN_PROGRAM_ID);
  const destinationAfter = await getAccount(connection, destination.address, "confirmed", TOKEN_PROGRAM_ID);
  const expectedSourceAfter = sourceBefore.amount - transferAmount;
  const expectedDestinationAfter = destinationBefore.amount + transferAmount;
  if (sourceAfter.amount !== expectedSourceAfter) {
    throw new Error(`source amount mismatch: expected ${expectedSourceAfter}, got ${sourceAfter.amount}`);
  }
  if (destinationAfter.amount !== expectedDestinationAfter) {
    throw new Error(`destination amount mismatch: expected ${expectedDestinationAfter}, got ${destinationAfter.amount}`);
  }

  const stateAccount = await connection.getAccountInfo(state.publicKey, "confirmed");
  if (stateAccount === null) {
    throw new Error(`state account not found: ${state.publicKey.toBase58()}`);
  }
  const recordedAmount = readU64LEAt(stateAccount.data, 0);
  if (recordedAmount !== transferAmount) {
    throw new Error(`state last_transfer_amount mismatch: expected ${transferAmount}, got ${recordedAmount}`);
  }

  console.log(JSON.stringify({
    programId: programId.toBase58(),
    state: state.publicKey.toBase58(),
    payer: payer.publicKey.toBase58(),
    mint: mint.toBase58(),
    source: source.address.toBase58(),
    destination: destination.address.toBase58(),
    tokenProgram: TOKEN_PROGRAM_ID.toBase58(),
    signature,
    decimals,
    transferAmount: transferAmount.toString(),
    sourceBefore: sourceBefore.amount.toString(),
    sourceAfter: sourceAfter.amount.toString(),
    destinationBefore: destinationBefore.amount.toString(),
    destinationAfter: destinationAfter.amount.toString(),
    recordedAmount: recordedAmount.toString(),
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

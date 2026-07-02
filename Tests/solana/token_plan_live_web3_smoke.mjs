import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
} from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  AuthorityType,
  TOKEN_PROGRAM_ID,
  createApproveInstruction,
  createBurnInstruction,
  createMint,
  createMintToInstruction,
  createRevokeInstruction,
  createSetAuthorityInstruction,
  createTransferCheckedInstruction,
  getAccount,
  getMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";
import fs from "node:fs";

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function readKeypair(path) {
  const bytes = JSON.parse(fs.readFileSync(path, "utf8"));
  return Keypair.fromSecretKey(Uint8Array.from(bytes));
}

function require(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function instructionByName(plan, name) {
  const instruction = plan.solana.instructions.find((item) => item.name === name);
  require(instruction, `missing Solana token instruction plan: ${name}`);
  return instruction;
}

function validatePlan(plan) {
  require(plan.format === "proof-forge-token-plan-v0", "unexpected token plan format");
  require(plan.targetFamily === "solana", "token plan is not a Solana plan");
  require(plan.standard === "spl-token", "live token plan smoke currently executes legacy SPL Token plans only");
  require(plan.solana?.programs?.token === TOKEN_PROGRAM_ID.toBase58(), "SPL Token program id mismatch");
  require(
    plan.solana?.programs?.associatedToken === ASSOCIATED_TOKEN_PROGRAM_ID.toBase58(),
    "Associated Token program id mismatch",
  );
  require(plan.solana?.programs?.system === SystemProgram.programId.toBase58(), "System program id mismatch");
  for (const name of [
    "create_mint_account",
    "initialize_mint",
    "create_owner_ata",
    "create_recipient_ata",
    "mint_to_initial_supply",
    "mint_to",
    "transfer_checked",
    "approve_delegate",
    "burn",
    "revoke_delegate",
    "set_mint_authority",
  ]) {
    instructionByName(plan, name);
  }
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

function assertAmount(label, actual, expected) {
  if (actual !== expected) {
    throw new Error(`${label} amount mismatch: expected ${expected}, got ${actual}`);
  }
}

async function sendInstruction(connection, payer, instruction) {
  return sendAndPollTransaction(connection, new Transaction().add(instruction), [payer]);
}

async function main() {
  const rpcUrl = process.env.PROOF_FORGE_SOLANA_RPC_URL;
  const wsUrl = process.env.PROOF_FORGE_SOLANA_WS_URL;
  const payerPath = process.env.PROOF_FORGE_SOLANA_PAYER;
  const planPath = process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN;
  if (!rpcUrl || !payerPath || !planPath) {
    throw new Error("missing PROOF_FORGE_SOLANA_RPC_URL, PROOF_FORGE_SOLANA_PAYER, or PROOF_FORGE_SOLANA_TOKEN_PLAN");
  }

  const plan = readJson(planPath);
  validatePlan(plan);

  const connection = new Connection(rpcUrl, {
    commitment: "confirmed",
    wsEndpoint: wsUrl,
  });
  const payer = readKeypair(payerPath);
  const owner = payer;
  const mintAuthority = payer;
  const recipient = Keypair.generate();
  const delegate = Keypair.generate();
  const decimals = Number(plan.token.decimals);
  const initialSupply = BigInt(plan.token.initialSupply ?? 0);
  const mintAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_MINT_AMOUNT ?? "125000");
  const transferAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_TRANSFER_AMOUNT ?? "250000");
  const approveAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_APPROVE_AMOUNT ?? "333000");
  const burnAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_BURN_AMOUNT ?? "75000");
  if (initialSupply <= transferAmount + burnAmount) {
    throw new Error(`initial supply ${initialSupply} is too small for transfer ${transferAmount} and burn ${burnAmount}`);
  }

  const mint = await createMint(
    connection,
    payer,
    mintAuthority.publicKey,
    null,
    decimals,
    undefined,
    { commitment: "confirmed" },
    TOKEN_PROGRAM_ID,
  );
  const ownerAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    owner.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );
  const recipientAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    recipient.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );

  await mintTo(
    connection,
    payer,
    mint,
    ownerAta.address,
    mintAuthority,
    initialSupply,
    [],
    { commitment: "confirmed" },
    TOKEN_PROGRAM_ID,
  );

  let ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  let recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_PROGRAM_ID);
  let mintAccount = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  assertAmount("owner after initial mint", ownerAccount.amount, initialSupply);
  assertAmount("recipient initial", recipientAccount.amount, 0n);
  assertAmount("supply after initial mint", mintAccount.supply, initialSupply);

  const mintSignature = await sendInstruction(
    connection,
    payer,
    createMintToInstruction(
      mint,
      ownerAta.address,
      mintAuthority.publicKey,
      mintAmount,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  mintAccount = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  assertAmount("owner after planned mint_to", ownerAccount.amount, initialSupply + mintAmount);
  assertAmount("supply after planned mint_to", mintAccount.supply, initialSupply + mintAmount);

  const transferSignature = await sendInstruction(
    connection,
    payer,
    createTransferCheckedInstruction(
      ownerAta.address,
      mint,
      recipientAta.address,
      owner.publicKey,
      transferAmount,
      decimals,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_PROGRAM_ID);
  assertAmount("owner after transfer_checked", ownerAccount.amount, initialSupply + mintAmount - transferAmount);
  assertAmount("recipient after transfer_checked", recipientAccount.amount, transferAmount);

  const approveSignature = await sendInstruction(
    connection,
    payer,
    createApproveInstruction(
      ownerAta.address,
      delegate.publicKey,
      owner.publicKey,
      approveAmount,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  require(ownerAccount.delegate?.equals(delegate.publicKey), "delegate was not recorded after approve");
  assertAmount("delegated amount after approve", ownerAccount.delegatedAmount, approveAmount);

  const burnSignature = await sendInstruction(
    connection,
    payer,
    createBurnInstruction(
      ownerAta.address,
      mint,
      owner.publicKey,
      burnAmount,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  mintAccount = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  assertAmount("owner after burn", ownerAccount.amount, initialSupply + mintAmount - transferAmount - burnAmount);
  assertAmount("supply after burn", mintAccount.supply, initialSupply + mintAmount - burnAmount);

  const revokeSignature = await sendInstruction(
    connection,
    payer,
    createRevokeInstruction(
      ownerAta.address,
      owner.publicKey,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_PROGRAM_ID);
  require(ownerAccount.delegate === null, "delegate should be cleared after revoke");
  assertAmount("delegated amount after revoke", ownerAccount.delegatedAmount, 0n);

  const setAuthoritySignature = await sendInstruction(
    connection,
    payer,
    createSetAuthorityInstruction(
      mint,
      mintAuthority.publicKey,
      AuthorityType.MintTokens,
      null,
      [],
      TOKEN_PROGRAM_ID,
    ),
  );
  mintAccount = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
  require(mintAccount.mintAuthority === null, "mint authority should be revoked after set_authority");

  console.log(JSON.stringify({
    standard: plan.standard,
    token: plan.token.id,
    mint: mint.toBase58(),
    owner: owner.publicKey.toBase58(),
    ownerAta: ownerAta.address.toBase58(),
    recipient: recipient.publicKey.toBase58(),
    recipientAta: recipientAta.address.toBase58(),
    delegate: delegate.publicKey.toBase58(),
    tokenProgram: TOKEN_PROGRAM_ID.toBase58(),
    decimals,
    initialSupply: initialSupply.toString(),
    mintAmount: mintAmount.toString(),
    transferAmount: transferAmount.toString(),
    approveAmount: approveAmount.toString(),
    burnAmount: burnAmount.toString(),
    ownerFinal: ownerAccount.amount.toString(),
    recipientFinal: recipientAccount.amount.toString(),
    supplyFinal: mintAccount.supply.toString(),
    signatures: {
      mint: mintSignature,
      transfer: transferSignature,
      approve: approveSignature,
      burn: burnSignature,
      revoke: revokeSignature,
      setAuthority: setAuthoritySignature,
    },
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

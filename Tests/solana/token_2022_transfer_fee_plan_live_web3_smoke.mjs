import {
  Connection,
  Keypair,
  SystemProgram,
  Transaction,
} from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  ExtensionType,
  TOKEN_2022_PROGRAM_ID,
  calculateEpochFee,
  createInitializeMintInstruction,
  createInitializeTransferFeeConfigInstruction,
  createHarvestWithheldTokensToMintInstruction,
  createTransferCheckedWithFeeInstruction,
  createWithdrawWithheldTokensFromAccountsInstruction,
  createWithdrawWithheldTokensFromMintInstruction,
  getAccount,
  getMint,
  getMintLen,
  getOrCreateAssociatedTokenAccount,
  getTransferFeeAmount,
  getTransferFeeConfig,
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

function extensionByName(plan, name) {
  const extension = (plan.solana.extensions ?? []).find((item) => item.extension === name);
  require(extension, `missing Solana token extension plan: ${name}`);
  return extension;
}

function validatePlan(plan) {
  require(plan.format === "proof-forge-token-plan-v0", "unexpected token plan format");
  require(plan.targetFamily === "solana", "token plan is not a Solana plan");
  require(plan.standard === "spl-token-2022", "live transfer-fee smoke expects a Token-2022 plan");
  require(plan.operations.includes("token-2022.extension.transfer_fee"), "plan is missing transfer-fee operation");
  require(
    plan.solana?.programs?.token === TOKEN_2022_PROGRAM_ID.toBase58(),
    "Token-2022 program id mismatch",
  );
  require(
    plan.solana?.programs?.associatedToken === ASSOCIATED_TOKEN_PROGRAM_ID.toBase58(),
    "Associated Token program id mismatch",
  );
  require(plan.solana?.programs?.system === SystemProgram.programId.toBase58(), "System program id mismatch");

  extensionByName(plan, "transfer_fee_config");
  const initTransferFee = instructionByName(plan, "initialize_transfer_fee_config");
  const initializeMint = instructionByName(plan, "initialize_mint");
  instructionByName(plan, "create_mint_account");
  instructionByName(plan, "create_owner_ata");
  instructionByName(plan, "create_recipient_ata");
  instructionByName(plan, "mint_to_initial_supply");
  instructionByName(plan, "transfer_checked");
  instructionByName(plan, "transfer_checked_with_fee");
  instructionByName(plan, "withdraw_withheld_tokens_from_accounts");
  instructionByName(plan, "harvest_withheld_tokens_to_mint");
  instructionByName(plan, "withdraw_withheld_tokens_from_mint");
  require(
    initTransferFee.order < initializeMint.order,
    "transfer-fee config must be initialized before initialize_mint",
  );
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
  const withdrawWithheldAuthority = payer;
  const recipient = Keypair.generate();
  const harvestRecipient = Keypair.generate();
  const feeReceiver = Keypair.generate();
  const decimals = Number(plan.token.decimals);
  const initialSupply = BigInt(plan.token.initialSupply ?? 0);
  const transferFeeBasisPoints = Number(process.env.PROOF_FORGE_SOLANA_TRANSFER_FEE_BPS ?? "125");
  const maximumFee = BigInt(process.env.PROOF_FORGE_SOLANA_TRANSFER_FEE_MAX_FEE ?? "10000");
  const transferAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_TRANSFER_AMOUNT ?? "250000");
  if (!Number.isInteger(transferFeeBasisPoints) || transferFeeBasisPoints < 0 || transferFeeBasisPoints > 10000) {
    throw new Error(`invalid transfer fee basis points: ${transferFeeBasisPoints}`);
  }
  if (initialSupply <= transferAmount * 2n) {
    throw new Error(`initial supply ${initialSupply} is too small for two transfers of ${transferAmount}`);
  }

  const mint = Keypair.generate();
  const mintLen = getMintLen([ExtensionType.TransferFeeConfig]);
  const mintRent = await connection.getMinimumBalanceForRentExemption(mintLen);
  const createMintSignature = await sendAndPollTransaction(
    connection,
    new Transaction().add(
      SystemProgram.createAccount({
        fromPubkey: payer.publicKey,
        newAccountPubkey: mint.publicKey,
        lamports: mintRent,
        space: mintLen,
        programId: TOKEN_2022_PROGRAM_ID,
      }),
      createInitializeTransferFeeConfigInstruction(
        mint.publicKey,
        mintAuthority.publicKey,
        withdrawWithheldAuthority.publicKey,
        transferFeeBasisPoints,
        maximumFee,
        TOKEN_2022_PROGRAM_ID,
      ),
      createInitializeMintInstruction(
        mint.publicKey,
        decimals,
        mintAuthority.publicKey,
        null,
        TOKEN_2022_PROGRAM_ID,
      ),
    ),
    [payer, mint],
  );

  let mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  const feeConfig = getTransferFeeConfig(mintAccount);
  require(feeConfig !== null, "mint missing TransferFeeConfig extension");
  require(feeConfig.transferFeeConfigAuthority.equals(mintAuthority.publicKey), "transfer-fee config authority mismatch");
  require(feeConfig.withdrawWithheldAuthority.equals(withdrawWithheldAuthority.publicKey), "withdraw-withheld authority mismatch");
  require(feeConfig.newerTransferFee.transferFeeBasisPoints === transferFeeBasisPoints, "transfer-fee basis points mismatch");
  assertAmount("transfer-fee maximum", feeConfig.newerTransferFee.maximumFee, maximumFee);

  const ownerAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint.publicKey,
    owner.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_2022_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );
  const recipientAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint.publicKey,
    recipient.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_2022_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );
  const harvestRecipientAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint.publicKey,
    harvestRecipient.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_2022_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );
  const feeReceiverAta = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint.publicKey,
    feeReceiver.publicKey,
    false,
    "confirmed",
    undefined,
    TOKEN_2022_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID,
  );

  const mintToSignature = await mintTo(
    connection,
    payer,
    mint.publicKey,
    ownerAta.address,
    mintAuthority,
    initialSupply,
    [],
    { commitment: "confirmed" },
    TOKEN_2022_PROGRAM_ID,
  );

  let ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  let recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  let harvestRecipientAccount = await getAccount(connection, harvestRecipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  let feeReceiverAccount = await getAccount(connection, feeReceiverAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  assertAmount("owner after initial mint", ownerAccount.amount, initialSupply);
  assertAmount("recipient initial", recipientAccount.amount, 0n);
  assertAmount("harvest recipient initial", harvestRecipientAccount.amount, 0n);
  assertAmount("fee receiver initial", feeReceiverAccount.amount, 0n);
  assertAmount("supply after initial mint", mintAccount.supply, initialSupply);

  const epochInfo = await connection.getEpochInfo("confirmed");
  const currentFeeConfig = getTransferFeeConfig(mintAccount);
  require(currentFeeConfig !== null, "mint missing TransferFeeConfig extension after mint_to");
  const expectedFee = calculateEpochFee(currentFeeConfig, BigInt(epochInfo.epoch), transferAmount);
  const transferSignature = await sendInstruction(
    connection,
    payer,
    createTransferCheckedWithFeeInstruction(
      ownerAta.address,
      mint.publicKey,
      recipientAta.address,
      owner.publicKey,
      transferAmount,
      decimals,
      expectedFee,
      [],
      TOKEN_2022_PROGRAM_ID,
    ),
  );

  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  const recipientFeeAmount = getTransferFeeAmount(recipientAccount);
  require(recipientFeeAmount !== null, "recipient account missing TransferFeeAmount extension");
  assertAmount("owner after transfer_checked_with_fee", ownerAccount.amount, initialSupply - transferAmount);
  assertAmount("recipient after transfer_checked_with_fee", recipientAccount.amount, transferAmount - expectedFee);
  assertAmount("recipient withheld transfer fee", recipientFeeAmount.withheldAmount, expectedFee);

  const withdrawFromAccountsSignature = await sendInstruction(
    connection,
    payer,
    createWithdrawWithheldTokensFromAccountsInstruction(
      mint.publicKey,
      feeReceiverAta.address,
      withdrawWithheldAuthority.publicKey,
      [],
      [recipientAta.address],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  feeReceiverAccount = await getAccount(connection, feeReceiverAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  const recipientFeeAfterDirectWithdraw = getTransferFeeAmount(recipientAccount);
  require(recipientFeeAfterDirectWithdraw !== null, "recipient account missing TransferFeeAmount after withdraw");
  assertAmount("recipient withheld fee after direct withdraw", recipientFeeAfterDirectWithdraw.withheldAmount, 0n);
  assertAmount("fee receiver after direct withdraw", feeReceiverAccount.amount, expectedFee);

  const harvestTransferSignature = await sendInstruction(
    connection,
    payer,
    createTransferCheckedWithFeeInstruction(
      ownerAta.address,
      mint.publicKey,
      harvestRecipientAta.address,
      owner.publicKey,
      transferAmount,
      decimals,
      expectedFee,
      [],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  harvestRecipientAccount = await getAccount(connection, harvestRecipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  const harvestRecipientFeeAmount = getTransferFeeAmount(harvestRecipientAccount);
  require(harvestRecipientFeeAmount !== null, "harvest recipient account missing TransferFeeAmount extension");
  assertAmount("owner after harvest-path transfer", ownerAccount.amount, initialSupply - (transferAmount * 2n));
  assertAmount("harvest recipient after transfer_checked_with_fee", harvestRecipientAccount.amount, transferAmount - expectedFee);
  assertAmount("harvest recipient withheld transfer fee", harvestRecipientFeeAmount.withheldAmount, expectedFee);

  const harvestToMintSignature = await sendInstruction(
    connection,
    payer,
    createHarvestWithheldTokensToMintInstruction(
      mint.publicKey,
      [harvestRecipientAta.address],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  harvestRecipientAccount = await getAccount(connection, harvestRecipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  const harvestRecipientFeeAfterHarvest = getTransferFeeAmount(harvestRecipientAccount);
  const feeConfigAfterHarvest = getTransferFeeConfig(mintAccount);
  require(harvestRecipientFeeAfterHarvest !== null, "harvest recipient account missing TransferFeeAmount after harvest");
  require(feeConfigAfterHarvest !== null, "mint missing TransferFeeConfig after harvest");
  assertAmount("harvest recipient withheld fee after harvest", harvestRecipientFeeAfterHarvest.withheldAmount, 0n);
  assertAmount("mint withheld fee after harvest", feeConfigAfterHarvest.withheldAmount, expectedFee);

  const withdrawFromMintSignature = await sendInstruction(
    connection,
    payer,
    createWithdrawWithheldTokensFromMintInstruction(
      mint.publicKey,
      feeReceiverAta.address,
      withdrawWithheldAuthority.publicKey,
      [],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  feeReceiverAccount = await getAccount(connection, feeReceiverAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  const feeConfigAfterMintWithdraw = getTransferFeeConfig(mintAccount);
  require(feeConfigAfterMintWithdraw !== null, "mint missing TransferFeeConfig after mint withdraw");
  assertAmount("fee receiver after mint withdraw", feeReceiverAccount.amount, expectedFee * 2n);
  assertAmount("mint withheld fee after mint withdraw", feeConfigAfterMintWithdraw.withheldAmount, 0n);

  console.log(JSON.stringify({
    standard: plan.standard,
    token: plan.token.id,
    mint: mint.publicKey.toBase58(),
    owner: owner.publicKey.toBase58(),
    ownerAta: ownerAta.address.toBase58(),
    recipient: recipient.publicKey.toBase58(),
    recipientAta: recipientAta.address.toBase58(),
    harvestRecipient: harvestRecipient.publicKey.toBase58(),
    harvestRecipientAta: harvestRecipientAta.address.toBase58(),
    feeReceiver: feeReceiver.publicKey.toBase58(),
    feeReceiverAta: feeReceiverAta.address.toBase58(),
    tokenProgram: TOKEN_2022_PROGRAM_ID.toBase58(),
    decimals,
    initialSupply: initialSupply.toString(),
    transferAmount: transferAmount.toString(),
    transferFeeBasisPoints,
    maximumFee: maximumFee.toString(),
    expectedFee: expectedFee.toString(),
    ownerFinal: ownerAccount.amount.toString(),
    recipientFinal: recipientAccount.amount.toString(),
    harvestRecipientFinal: harvestRecipientAccount.amount.toString(),
    feeReceiverFinal: feeReceiverAccount.amount.toString(),
    recipientWithheldFeeAfterWithdraw: recipientFeeAfterDirectWithdraw.withheldAmount.toString(),
    harvestRecipientWithheldFeeAfterHarvest: harvestRecipientFeeAfterHarvest.withheldAmount.toString(),
    mintWithheldFeeAfterWithdraw: feeConfigAfterMintWithdraw.withheldAmount.toString(),
    signatures: {
      createMint: createMintSignature,
      mintTo: mintToSignature,
      transfer: transferSignature,
      withdrawFromAccounts: withdrawFromAccountsSignature,
      harvestTransfer: harvestTransferSignature,
      harvestToMint: harvestToMintSignature,
      withdrawFromMint: withdrawFromMintSignature,
    },
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

import {
  Keypair,
  PublicKey,
  SystemProgram,
} from "@solana/web3.js";
import * as splToken from "@solana/spl-token";
import fs from "node:fs";

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function require(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function keypairFromByte(byte) {
  return Keypair.fromSeed(Uint8Array.from(Array(32).fill(byte & 0xff)));
}

function pubkey(value) {
  return new PublicKey(value);
}

function instructionByName(plan, name) {
  const instruction = plan.solana.instructions.find((item) => item.name === name);
  require(instruction, `missing Solana token instruction plan: ${name}`);
  return instruction;
}

function assertInstructionProgram(planInstruction, actualInstruction) {
  require(
    actualInstruction.programId.equals(pubkey(planInstruction.programId)),
    `${planInstruction.name} program mismatch: expected ${planInstruction.programId}, got ${actualInstruction.programId.toBase58()}`,
  );
}

function extensionTypeForPlan(extensionName) {
  const extensionType = splToken.ExtensionType;
  if (!extensionType) {
    return undefined;
  }
  switch (extensionName) {
    case "transfer_fee_config":
      return extensionType.TransferFeeConfig;
    case "non_transferable":
      return extensionType.NonTransferable;
    case "confidential_transfer_mint":
      return extensionType.ConfidentialTransferMint;
    case "transfer_hook":
      return extensionType.TransferHook;
    default:
      return undefined;
  }
}

function mintSpaceForPlan(plan) {
  const extensionTypes = (plan.solana.extensions ?? [])
    .map((extension) => extensionTypeForPlan(extension.extension))
    .filter((extensionType) => extensionType !== undefined);
  if (extensionTypes.length > 0 && typeof splToken.getMintLen === "function") {
    return splToken.getMintLen(extensionTypes);
  }
  return 82;
}

function validatePlanShape(plan) {
  require(plan.format === "proof-forge-token-plan-v0", "unexpected token plan format");
  require(plan.targetFamily === "solana", "token plan is not a Solana plan");
  require(plan.solana && typeof plan.solana === "object", "token plan missing structured solana section");
  const tokenProgram = plan.standard === "spl-token-2022"
    ? splToken.TOKEN_2022_PROGRAM_ID
    : splToken.TOKEN_PROGRAM_ID;
  require(tokenProgram, `@solana/spl-token missing program constant for ${plan.standard}`);
  require(plan.solana.programs.token === tokenProgram.toBase58(), "token program id mismatch");
  require(
    plan.solana.programs.associatedToken === splToken.ASSOCIATED_TOKEN_PROGRAM_ID.toBase58(),
    "associated token program id mismatch",
  );
  require(plan.solana.programs.system === SystemProgram.programId.toBase58(), "system program id mismatch");

  const orders = plan.solana.instructions.map((instruction) => instruction.order);
  const sortedOrders = [...orders].sort((left, right) => left - right);
  require(JSON.stringify(orders) === JSON.stringify(sortedOrders),
    `instruction order is not sorted: ${JSON.stringify(orders)}`);

  const expectedInstructions = [
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
  ];
  for (const name of expectedInstructions) {
    instructionByName(plan, name);
  }
  if (plan.standard === "spl-token-2022") {
    require((plan.solana.extensions ?? []).length > 0, "Token-2022 plan missing extension metadata");
    for (const extension of plan.solana.extensions) {
      instructionByName(plan, extension.initInstruction);
    }
    if ((plan.solana.extensions ?? []).some((extension) => extension.extension === "transfer_fee_config")) {
      for (const name of [
        "transfer_checked_with_fee",
        "withdraw_withheld_tokens_from_accounts",
        "harvest_withheld_tokens_to_mint",
        "withdraw_withheld_tokens_from_mint",
      ]) {
        instructionByName(plan, name);
      }
    }
  }
}

function validateInstructionBuilders(plan) {
  const payer = keypairFromByte(1).publicKey;
  const mint = keypairFromByte(2).publicKey;
  const mintAuthority = keypairFromByte(3).publicKey;
  const owner = keypairFromByte(4).publicKey;
  const recipient = keypairFromByte(5).publicKey;
  const delegate = keypairFromByte(6).publicKey;
  const tokenProgram = pubkey(plan.solana.programs.token);
  const associatedTokenProgram = pubkey(plan.solana.programs.associatedToken);
  const decimals = Number(plan.token.decimals);
  const initialSupply = BigInt(plan.token.initialSupply ?? 0);
  const ownerAta = splToken.getAssociatedTokenAddressSync(
    mint,
    owner,
    false,
    tokenProgram,
    associatedTokenProgram,
  );
  const recipientAta = splToken.getAssociatedTokenAddressSync(
    mint,
    recipient,
    false,
    tokenProgram,
    associatedTokenProgram,
  );
  require(ownerAta instanceof PublicKey, "owner ATA derivation failed");
  require(recipientAta instanceof PublicKey, "recipient ATA derivation failed");

  const createMintIx = SystemProgram.createAccount({
    fromPubkey: payer,
    newAccountPubkey: mint,
    lamports: 1_000_000,
    space: mintSpaceForPlan(plan),
    programId: tokenProgram,
  });
  assertInstructionProgram(instructionByName(plan, "create_mint_account"), createMintIx);

  if (plan.standard === "spl-token-2022" &&
      (plan.solana.extensions ?? []).some((extension) => extension.extension === "non_transferable")) {
    const initializeNonTransferableIx = splToken.createInitializeNonTransferableMintInstruction(
      mint,
      tokenProgram,
    );
    assertInstructionProgram(instructionByName(plan, "initialize_non_transferable_mint"), initializeNonTransferableIx);
  }

  const initializeMintIx = splToken.createInitializeMintInstruction(
    mint,
    decimals,
    mintAuthority,
    null,
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "initialize_mint"), initializeMintIx);

  const createOwnerAtaIx = splToken.createAssociatedTokenAccountInstruction(
    payer,
    ownerAta,
    owner,
    mint,
    tokenProgram,
    associatedTokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "create_owner_ata"), createOwnerAtaIx);

  const createRecipientAtaIx = splToken.createAssociatedTokenAccountInstruction(
    payer,
    recipientAta,
    recipient,
    mint,
    tokenProgram,
    associatedTokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "create_recipient_ata"), createRecipientAtaIx);

  const mintToIx = splToken.createMintToInstruction(
    mint,
    ownerAta,
    mintAuthority,
    initialSupply,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "mint_to_initial_supply"), mintToIx);

  const futureMintToIx = splToken.createMintToInstruction(
    mint,
    ownerAta,
    mintAuthority,
    10n,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "mint_to"), futureMintToIx);

  const transferCheckedIx = splToken.createTransferCheckedInstruction(
    ownerAta,
    mint,
    recipientAta,
    owner,
    10n,
    decimals,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "transfer_checked"), transferCheckedIx);

  const approveIx = splToken.createApproveInstruction(
    ownerAta,
    delegate,
    owner,
    10n,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "approve_delegate"), approveIx);

  const burnIx = splToken.createBurnInstruction(
    ownerAta,
    mint,
    owner,
    1n,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "burn"), burnIx);

  const revokeIx = splToken.createRevokeInstruction(
    ownerAta,
    owner,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "revoke_delegate"), revokeIx);

  const setAuthorityIx = splToken.createSetAuthorityInstruction(
    mint,
    mintAuthority,
    splToken.AuthorityType.MintTokens,
    mintAuthority,
    [],
    tokenProgram,
  );
  assertInstructionProgram(instructionByName(plan, "set_mint_authority"), setAuthorityIx);

  if (plan.standard === "spl-token-2022" &&
      (plan.solana.extensions ?? []).some((extension) => extension.extension === "transfer_fee_config")) {
    const feeReceiver = keypairFromByte(7).publicKey;
    const feeReceiverAta = splToken.getAssociatedTokenAddressSync(
      mint,
      feeReceiver,
      false,
      tokenProgram,
      associatedTokenProgram,
    );
    const transferWithFeeIx = splToken.createTransferCheckedWithFeeInstruction(
      ownerAta,
      mint,
      recipientAta,
      owner,
      10n,
      decimals,
      1n,
      [],
      tokenProgram,
    );
    assertInstructionProgram(instructionByName(plan, "transfer_checked_with_fee"), transferWithFeeIx);

    const withdrawFromAccountsIx = splToken.createWithdrawWithheldTokensFromAccountsInstruction(
      mint,
      feeReceiverAta,
      mintAuthority,
      [],
      [recipientAta],
      tokenProgram,
    );
    assertInstructionProgram(instructionByName(plan, "withdraw_withheld_tokens_from_accounts"), withdrawFromAccountsIx);

    const harvestToMintIx = splToken.createHarvestWithheldTokensToMintInstruction(
      mint,
      [recipientAta],
      tokenProgram,
    );
    assertInstructionProgram(instructionByName(plan, "harvest_withheld_tokens_to_mint"), harvestToMintIx);

    const withdrawFromMintIx = splToken.createWithdrawWithheldTokensFromMintInstruction(
      mint,
      feeReceiverAta,
      mintAuthority,
      [],
      tokenProgram,
    );
    assertInstructionProgram(instructionByName(plan, "withdraw_withheld_tokens_from_mint"), withdrawFromMintIx);
  }
}

function main() {
  const planPath = process.argv[2];
  if (!planPath) {
    throw new Error("usage: node token_plan_web3_smoke.mjs <token-plan.json>");
  }
  const plan = readJson(planPath);
  validatePlanShape(plan);
  validateInstructionBuilders(plan);
  console.log(JSON.stringify({
    plan: planPath,
    standard: plan.standard,
    tokenProgram: plan.solana.programs.token,
    instructions: plan.solana.instructions.map((instruction) => instruction.name),
    extensions: plan.solana.extensions.map((extension) => extension.extension),
  }));
}

try {
  main();
} catch (err) {
  console.error(err);
  process.exit(1);
}

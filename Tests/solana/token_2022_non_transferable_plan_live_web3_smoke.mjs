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
  createBurnInstruction,
  createInitializeMintInstruction,
  createInitializeNonTransferableMintInstruction,
  createTransferCheckedInstruction,
  getAccount,
  getExtensionData,
  getMint,
  getMintLen,
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

function extensionByName(plan, name) {
  const extension = (plan.solana.extensions ?? []).find((item) => item.extension === name);
  require(extension, `missing Solana token extension plan: ${name}`);
  return extension;
}

function hasTlvExtension(state, extensionType) {
  return getExtensionData(extensionType, state.tlvData) !== null;
}

function validatePlan(plan) {
  require(plan.format === "proof-forge-token-plan-v0", "unexpected token plan format");
  require(plan.targetFamily === "solana", "token plan is not a Solana plan");
  require(plan.standard === "spl-token-2022", "live non-transferable smoke expects a Token-2022 plan");
  require(
    plan.operations.includes("token-2022.extension.non_transferable"),
    "plan is missing non-transferable operation",
  );
  require(
    plan.solana?.programs?.token === TOKEN_2022_PROGRAM_ID.toBase58(),
    "Token-2022 program id mismatch",
  );
  require(
    plan.solana?.programs?.associatedToken === ASSOCIATED_TOKEN_PROGRAM_ID.toBase58(),
    "Associated Token program id mismatch",
  );
  require(plan.solana?.programs?.system === SystemProgram.programId.toBase58(), "System program id mismatch");

  extensionByName(plan, "non_transferable");
  const initializeNonTransferable = instructionByName(plan, "initialize_non_transferable_mint");
  const initializeMint = instructionByName(plan, "initialize_mint");
  instructionByName(plan, "create_mint_account");
  instructionByName(plan, "create_owner_ata");
  instructionByName(plan, "create_recipient_ata");
  instructionByName(plan, "mint_to_initial_supply");
  instructionByName(plan, "transfer_checked");
  instructionByName(plan, "burn");
  require(
    initializeNonTransferable.order < initializeMint.order,
    "non-transferable mint must be initialized before initialize_mint",
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendAndPollTransaction(connection, transaction, signers, options = {}) {
  const latest = await connection.getLatestBlockhash("confirmed");
  transaction.recentBlockhash = latest.blockhash;
  transaction.feePayer = signers[0].publicKey;
  transaction.sign(...signers);
  let signature;
  try {
    signature = await connection.sendRawTransaction(transaction.serialize(), {
      skipPreflight: options.skipPreflight ?? false,
    });
  } catch (error) {
    if (options.expectFailure) {
      return {
        signature: error.signature ?? "",
        err: error.transactionMessage ?? error.message ?? error,
      };
    }
    throw error;
  }
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const statuses = await connection.getSignatureStatuses([signature], {
      searchTransactionHistory: true,
    });
    const status = statuses.value[0];
    if (status?.err) {
      if (options.expectFailure) {
        return { signature, err: status.err };
      }
      throw new Error(`transaction ${signature} failed: ${JSON.stringify(status.err)}`);
    }
    if (status?.confirmationStatus === "confirmed" || status?.confirmationStatus === "finalized") {
      if (options.expectFailure) {
        throw new Error(`transaction ${signature} unexpectedly succeeded`);
      }
      return { signature, err: null };
    }
    await sleep(500);
  }
  throw new Error(`transaction ${signature} was not confirmed`);
}

async function sendInstruction(connection, payer, instruction) {
  return sendAndPollTransaction(connection, new Transaction().add(instruction), [payer]);
}

async function sendInstructionExpectingFailure(connection, payer, instruction) {
  return sendAndPollTransaction(
    connection,
    new Transaction().add(instruction),
    [payer],
    { skipPreflight: true, expectFailure: true },
  );
}

function assertAmount(label, actual, expected) {
  if (actual !== expected) {
    throw new Error(`${label} amount mismatch: expected ${expected}, got ${actual}`);
  }
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
  const decimals = Number(plan.token.decimals);
  const initialSupply = BigInt(plan.token.initialSupply ?? 0);
  const burnAmount = BigInt(process.env.PROOF_FORGE_SOLANA_TOKEN_PLAN_BURN_AMOUNT ?? "1");
  if (initialSupply < burnAmount || burnAmount <= 0n) {
    throw new Error(`initial supply ${initialSupply} is too small for burn ${burnAmount}`);
  }

  const mint = Keypair.generate();
  const mintLen = getMintLen([ExtensionType.NonTransferable]);
  const mintRent = await connection.getMinimumBalanceForRentExemption(mintLen);
  const createMintResult = await sendAndPollTransaction(
    connection,
    new Transaction().add(
      SystemProgram.createAccount({
        fromPubkey: payer.publicKey,
        newAccountPubkey: mint.publicKey,
        lamports: mintRent,
        space: mintLen,
        programId: TOKEN_2022_PROGRAM_ID,
      }),
      createInitializeNonTransferableMintInstruction(
        mint.publicKey,
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
  require(
    hasTlvExtension(mintAccount, ExtensionType.NonTransferable),
    "mint missing NonTransferable extension",
  );

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
  mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  require(
    hasTlvExtension(ownerAccount, ExtensionType.NonTransferableAccount),
    "owner account missing NonTransferableAccount extension",
  );
  require(
    hasTlvExtension(ownerAccount, ExtensionType.ImmutableOwner),
    "owner account missing ImmutableOwner extension",
  );
  require(
    hasTlvExtension(recipientAccount, ExtensionType.NonTransferableAccount),
    "recipient account missing NonTransferableAccount extension",
  );
  require(
    hasTlvExtension(recipientAccount, ExtensionType.ImmutableOwner),
    "recipient account missing ImmutableOwner extension",
  );
  assertAmount("owner after initial mint", ownerAccount.amount, initialSupply);
  assertAmount("recipient initial", recipientAccount.amount, 0n);
  assertAmount("supply after initial mint", mintAccount.supply, initialSupply);

  const failedTransfer = await sendInstructionExpectingFailure(
    connection,
    payer,
    createTransferCheckedInstruction(
      ownerAta.address,
      mint.publicKey,
      recipientAta.address,
      owner.publicKey,
      1n,
      decimals,
      [],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  recipientAccount = await getAccount(connection, recipientAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  assertAmount("owner after rejected transfer", ownerAccount.amount, initialSupply);
  assertAmount("recipient after rejected transfer", recipientAccount.amount, 0n);

  const burnResult = await sendInstruction(
    connection,
    payer,
    createBurnInstruction(
      ownerAta.address,
      mint.publicKey,
      owner.publicKey,
      burnAmount,
      [],
      TOKEN_2022_PROGRAM_ID,
    ),
  );
  ownerAccount = await getAccount(connection, ownerAta.address, "confirmed", TOKEN_2022_PROGRAM_ID);
  mintAccount = await getMint(connection, mint.publicKey, "confirmed", TOKEN_2022_PROGRAM_ID);
  assertAmount("owner after burn", ownerAccount.amount, initialSupply - burnAmount);
  assertAmount("supply after burn", mintAccount.supply, initialSupply - burnAmount);

  console.log(JSON.stringify({
    standard: plan.standard,
    token: plan.token.id,
    mint: mint.publicKey.toBase58(),
    owner: owner.publicKey.toBase58(),
    ownerAta: ownerAta.address.toBase58(),
    recipient: recipient.publicKey.toBase58(),
    recipientAta: recipientAta.address.toBase58(),
    tokenProgram: TOKEN_2022_PROGRAM_ID.toBase58(),
    decimals,
    initialSupply: initialSupply.toString(),
    burnAmount: burnAmount.toString(),
    ownerFinal: ownerAccount.amount.toString(),
    recipientFinal: recipientAccount.amount.toString(),
    supplyFinal: mintAccount.supply.toString(),
    rejectedTransferErr: failedTransfer.err,
    signatures: {
      createMint: createMintResult.signature,
      mintTo: mintToSignature,
      rejectedTransfer: failedTransfer.signature,
      burn: burnResult.signature,
    },
  }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

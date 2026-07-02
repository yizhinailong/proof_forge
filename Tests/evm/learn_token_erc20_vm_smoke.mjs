import fs from "node:fs";

import { Common, Hardfork, Mainnet } from "@ethereumjs/common";
import {
  createAccount,
  createAddressFromString,
  bytesToHex,
  hexToBytes,
} from "@ethereumjs/util";
import { createVM } from "@ethereumjs/vm";

function fail(message) {
  throw new Error(message);
}

function require(condition, message) {
  if (!condition) {
    fail(message);
  }
}

function normalizeHex(hex) {
  const trimmed = String(hex).trim();
  return trimmed.startsWith("0x") ? trimmed : `0x${trimmed}`;
}

function word(value) {
  return BigInt(value).toString(16).padStart(64, "0");
}

function addressWord(address) {
  return address.toString().slice(2).padStart(64, "0");
}

function bytesWord(bytes) {
  const hex = bytesToHex(bytes).slice(2);
  return BigInt(`0x${hex || "0"}`);
}

function selectorMap(artifact) {
  return Object.fromEntries(artifact.abi.entrypoints.map((entry) => [entry.name, entry.selector]));
}

function eventMap(artifact) {
  return Object.fromEntries(artifact.abi.events.map((event) => [event.name, event.topic0.toLowerCase()]));
}

function topicHex(log, index) {
  return bytesToHex(log[1][index]).toLowerCase();
}

function topicAddress(log, index) {
  return `0x${topicHex(log, index).slice(-40)}`.toLowerCase();
}

function logDataWord(log) {
  return bytesWord(log[2]);
}

function addressHex(address) {
  return address.toString().toLowerCase();
}

function hasOperation(artifact, operation) {
  return artifact.operations.includes(operation);
}

const [binPath, artifactPath] = process.argv.slice(2);

if (!binPath || !artifactPath) {
  fail("usage: node learn_token_erc20_vm_smoke.mjs <creation-bin> <artifact-json>");
}

const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
require(artifact.format === "proof-forge-token-artifact-v0", "unexpected token artifact format");
require(artifact.target === "evm", "expected EVM token artifact");
require(artifact.standard === "erc20", "expected ERC-20 token artifact");

const selectors = selectorMap(artifact);
const events = eventMap(artifact);
const creationBytecode = hexToBytes(normalizeHex(fs.readFileSync(binPath, "utf8")));
const common = new Common({ chain: Mainnet, hardfork: Hardfork.Shanghai });
const vm = await createVM({ common });

const deployer = createAddressFromString("0x1000000000000000000000000000000000000000");
const bob = createAddressFromString("0x2000000000000000000000000000000000000000");
const spender = createAddressFromString("0x3000000000000000000000000000000000000000");
const carol = createAddressFromString("0x4000000000000000000000000000000000000000");
const zeroAddress = "0x0000000000000000000000000000000000000000";

for (const address of [deployer, bob, spender, carol]) {
  await vm.stateManager.putAccount(
    address,
    createAccount({ nonce: 0n, balance: 1_000_000_000_000_000_000n }),
  );
}

const deploy = await vm.evm.runCall({
  caller: deployer,
  gasLimit: 10_000_000n,
  data: creationBytecode,
  value: 0n,
});

require(!deploy.execResult.exceptionError, `deploy reverted: ${deploy.execResult.exceptionError?.error}`);
require(deploy.createdAddress, "deployment did not create a contract address");

const contract = deploy.createdAddress;
const runtimeCode = await vm.stateManager.getCode(contract);
require(runtimeCode.length > 0, "deployment did not persist runtime code");

async function call(caller, name, args = [], options = {}) {
  const selector = selectors[name];
  require(selector, `artifact missing selector for ${name}`);
  const data = hexToBytes(`0x${selector}${args.join("")}`);
  const result = await vm.evm.runCall({
    caller,
    to: contract,
    gasLimit: 5_000_000n,
    data,
    value: 0n,
  });

  const error = result.execResult.exceptionError;
  if (options.expectRevert) {
    require(error, `${name} did not revert`);
    return result;
  }

  require(!error, `${name} reverted: ${error?.error}`);
  return result;
}

async function readUint(name, args = []) {
  const result = await call(deployer, name, args);
  require(result.execResult.returnValue.length === 32, `${name} did not return one word`);
  return bytesWord(result.execResult.returnValue);
}

async function balanceOf(owner) {
  return readUint("balanceOf", [addressWord(owner)]);
}

function requireBoolReturn(result, label) {
  require(result.execResult.returnValue.length === 32, `${label} did not return one word`);
  require(bytesWord(result.execResult.returnValue) === 1n, `${label} did not return true`);
}

function requireTransferLog(log, from, to, amount, label) {
  require(topicHex(log, 0) === events.Transfer, `${label} Transfer topic mismatch`);
  require(topicAddress(log, 1) === from.toLowerCase(), `${label} from topic mismatch`);
  require(topicAddress(log, 2) === to.toLowerCase(), `${label} to topic mismatch`);
  require(logDataWord(log) === BigInt(amount), `${label} amount log mismatch`);
}

function requireApprovalLog(log, owner, approvedSpender, amount) {
  require(topicHex(log, 0) === events.Approval, "Approval topic mismatch");
  require(topicAddress(log, 1) === owner.toLowerCase(), "Approval owner topic mismatch");
  require(topicAddress(log, 2) === approvedSpender.toLowerCase(), "Approval spender topic mismatch");
  require(logDataWord(log) === BigInt(amount), "Approval amount log mismatch");
}

const initialSupply = BigInt(artifact.token.initialSupply);
let expectedTotalSupply = initialSupply;
let expectedBobBalance = 0n;
let expectedCarolBalance = 0n;

require(await readUint("totalSupply") === initialSupply, "initial total supply mismatch");
require(await balanceOf(deployer) === initialSupply, "deployer initial balance mismatch");
require(await balanceOf(bob) === 0n, "recipient should start with zero balance");
require(await readUint("decimals") === BigInt(artifact.token.decimals), "decimals mismatch");

let result = await call(deployer, "transfer", [addressWord(bob), word(300_000n)]);
requireBoolReturn(result, "transfer");
require(result.execResult.logs.length === 1, "transfer should emit one event");
requireTransferLog(result.execResult.logs[0], addressHex(deployer), addressHex(bob), 300_000n, "transfer");
expectedBobBalance += 300_000n;
require(await balanceOf(deployer) === 700_000n, "deployer balance after transfer mismatch");
require(await balanceOf(bob) === expectedBobBalance, "recipient balance after transfer mismatch");
require(await readUint("totalSupply") === expectedTotalSupply, "transfer changed total supply");

result = await call(deployer, "approve", [addressWord(spender), word(12_345n)]);
requireBoolReturn(result, "approve");
require(result.execResult.logs.length === 1, "approve should emit one event");
requireApprovalLog(result.execResult.logs[0], addressHex(deployer), addressHex(spender), 12_345n);
require(
  await readUint("allowance", [addressWord(deployer), addressWord(spender)]) === 12_345n,
  "allowance after approve mismatch",
);

result = await call(spender, "transferFrom", [addressWord(deployer), addressWord(carol), word(10_000n)]);
requireBoolReturn(result, "transferFrom");
require(result.execResult.logs.length === 1, "transferFrom should emit one event");
requireTransferLog(result.execResult.logs[0], addressHex(deployer), addressHex(carol), 10_000n, "transferFrom");
require(
  await readUint("allowance", [addressWord(deployer), addressWord(spender)]) === 2_345n,
  "allowance after transferFrom mismatch",
);
expectedCarolBalance += 10_000n;
require(await balanceOf(deployer) === 690_000n, "deployer balance after transferFrom mismatch");
require(await balanceOf(carol) === expectedCarolBalance, "transferFrom recipient balance mismatch");

if (hasOperation(artifact, "erc20.burn")) {
  result = await call(carol, "burn", [word(5_000n)]);
  requireBoolReturn(result, "burn");
  require(result.execResult.logs.length === 1, "burn should emit one event");
  requireTransferLog(result.execResult.logs[0], addressHex(carol), zeroAddress, 5_000n, "burn");
  expectedTotalSupply -= 5_000n;
  expectedCarolBalance -= 5_000n;
  require(await readUint("totalSupply") === expectedTotalSupply, "total supply after burn mismatch");
  require(await balanceOf(carol) === expectedCarolBalance, "burner balance after burn mismatch");
}

if (hasOperation(artifact, "erc20.mint")) {
  result = await call(deployer, "mint", [addressWord(bob), word(7_000n)]);
  requireBoolReturn(result, "mint");
  require(result.execResult.logs.length === 1, "mint should emit one event");
  requireTransferLog(result.execResult.logs[0], zeroAddress, addressHex(bob), 7_000n, "mint");
  expectedTotalSupply += 7_000n;
  expectedBobBalance += 7_000n;
  require(await readUint("totalSupply") === expectedTotalSupply, "total supply after mint mismatch");
  require(await balanceOf(bob) === expectedBobBalance, "mint recipient balance mismatch");
}

await call(carol, "transfer", [addressWord(bob), word(999_999n)], { expectRevert: true });
require(await balanceOf(carol) === expectedCarolBalance, "reverted transfer changed sender balance");

console.log(`learn-token-erc20-vm: ok (${contract.toString()})`);

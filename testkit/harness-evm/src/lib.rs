use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, ensure, Context as _, Result};
use proof_forge_testkit_core::{CallOutcome, ChainHarness, ScenarioCase};
use revm::{
    bytecode::Bytecode,
    context::TxEnv,
    database::{CacheDB, EmptyDB},
    primitives::{Address, Bytes, TxKind, U256},
    state::AccountInfo,
    Context, ExecuteCommitEvm, MainBuilder, MainContext,
};
use serde::Deserialize;

const CONTRACT_ADDRESS: Address = Address::with_last_byte(0xC0);
const CALLER_ADDRESS: Address = Address::with_last_byte(0xA1);
const CALL_GAS_LIMIT: u64 = 1_000_000;

pub struct EvmHarness;

impl EvmHarness {
    pub fn new() -> Self {
        Self
    }
}

impl Default for EvmHarness {
    fn default() -> Self {
        Self::new()
    }
}

impl ChainHarness for EvmHarness {
    fn target_id(&self) -> &'static str {
        "evm"
    }

    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<Vec<CallOutcome>> {
        let artifact = build_fixture(case, repo_root)?;
        let selectors = load_selectors(&artifact.metadata_path)?;
        let bytecode = read_bytecode(&artifact.bytecode_path)?;

        let mut db = CacheDB::new(EmptyDB::new());
        db.insert_account_info(
            CONTRACT_ADDRESS,
            AccountInfo::from_bytecode(Bytecode::new_raw(Bytes::from(bytecode))),
        );
        db.insert_account_info(CALLER_ADDRESS, AccountInfo::default());

        let mut evm = Context::mainnet().with_db(db).build_mainnet();
        let mut outcomes = Vec::new();
        let mut sequence = 1u32;
        let mut nonce = 0u64;

        for step in &case.manifest.steps {
            let selector = selectors
                .get(&step.call)
                .with_context(|| {
                    format!(
                        "EVM metadata for fixture `{}` does not contain call `{}`",
                        case.manifest.scenario.fixture, step.call
                    )
                })?
                .clone();
            for _ in 0..step.repeat.unwrap_or(1) {
                let calldata = calldata_for_step(&selector, step.input_hex.as_deref())?;
                let tx = TxEnv::builder()
                    .caller(CALLER_ADDRESS)
                    .gas_limit(CALL_GAS_LIMIT)
                    .gas_price(0)
                    .kind(TxKind::Call(CONTRACT_ADDRESS))
                    .value(U256::ZERO)
                    .data(Bytes::from(calldata))
                    .nonce(nonce)
                    .build()
                    .context("failed to build EVM transaction")?;
                nonce += 1;

                let result = evm
                    .transact_commit(tx)
                    .with_context(|| format!("EVM call `{}` failed before execution", step.call))?;
                ensure!(
                    result.is_success(),
                    "EVM call `{}` did not succeed: {result:?}",
                    step.call
                );
                let output = result.into_output().ok_or_else(|| {
                    anyhow::anyhow!("EVM call `{}` halted without output", step.call)
                })?;
                outcomes.push(outcome_from_output(sequence, &step.call, output.as_ref()));
                sequence += 1;
            }
        }

        Ok(outcomes)
    }
}

struct EvmFixtureArtifact {
    bytecode_path: PathBuf,
    metadata_path: PathBuf,
}

fn build_fixture(case: &ScenarioCase, repo_root: &Path) -> Result<EvmFixtureArtifact> {
    match case.manifest.scenario.fixture.as_str() {
        "counter" => build_counter_fixture(repo_root),
        fixture => bail!("EVM testkit harness does not support fixture `{fixture}` yet"),
    }
}

fn build_counter_fixture(repo_root: &Path) -> Result<EvmFixtureArtifact> {
    let out_dir = repo_root.join("build/testkit/evm");
    fs::create_dir_all(&out_dir)
        .with_context(|| format!("failed to create `{}`", out_dir.display()))?;

    let build = Command::new("lake")
        .current_dir(repo_root)
        .args(["build", "proof-forge"])
        .output()
        .context("failed to build proof-forge executable")?;
    if !build.status.success() {
        bail!(
            "lake build proof-forge failed\nstdout:\n{}\nstderr:\n{}",
            String::from_utf8_lossy(&build.stdout),
            String::from_utf8_lossy(&build.stderr)
        );
    }

    let bytecode_path = out_dir.join("Counter.bin");
    let yul_path = out_dir.join("Counter.yul");
    let metadata_path = out_dir.join("Counter.proof-forge-artifact.json");
    let proof_forge = repo_root.join(".lake/build/bin/proof-forge");
    let output = Command::new(&proof_forge)
        .current_dir(repo_root)
        .args([
            "--emit-counter-ir-bytecode",
            "--yul-output",
            yul_path
                .to_str()
                .ok_or_else(|| anyhow::anyhow!("non-UTF-8 Yul path"))?,
            "--artifact-output",
            metadata_path
                .to_str()
                .ok_or_else(|| anyhow::anyhow!("non-UTF-8 metadata path"))?,
            "-o",
            bytecode_path
                .to_str()
                .ok_or_else(|| anyhow::anyhow!("non-UTF-8 bytecode path"))?,
        ])
        .output()
        .with_context(|| format!("failed to run `{}`", proof_forge.display()))?;
    if !output.status.success() {
        bail!(
            "Counter EVM bytecode emission failed\nstdout:\n{}\nstderr:\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }
    ensure!(
        bytecode_path.exists(),
        "Counter EVM bytecode emission did not create `{}`",
        bytecode_path.display()
    );
    ensure!(
        metadata_path.exists(),
        "Counter EVM bytecode emission did not create `{}`",
        metadata_path.display()
    );

    Ok(EvmFixtureArtifact {
        bytecode_path,
        metadata_path,
    })
}

fn read_bytecode(path: &Path) -> Result<Vec<u8>> {
    let text =
        fs::read_to_string(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    decode_hex(text.trim()).with_context(|| format!("failed to decode `{}`", path.display()))
}

fn calldata_for_step(selector: &[u8; 4], input_hex: Option<&str>) -> Result<Vec<u8>> {
    let mut calldata = selector.to_vec();
    if let Some(input_hex) = input_hex {
        calldata.extend(decode_hex(input_hex).context("failed to decode EVM input_hex")?);
    }
    Ok(calldata)
}

fn decode_hex(value: &str) -> Result<Vec<u8>> {
    let normalized = value.strip_prefix("0x").unwrap_or(value);
    ensure!(
        normalized.len() % 2 == 0,
        "hex value must contain an even number of digits"
    );
    hex::decode(normalized).context("invalid hex")
}

fn outcome_from_output(sequence: u32, call: &str, output: &[u8]) -> CallOutcome {
    let return_hex = if output.is_empty() {
        None
    } else {
        Some(hex::encode(output))
    };
    let word = if output.len() == 32 {
        Some(output)
    } else {
        None
    };
    let return_u64 = word.and_then(word_to_u64);
    let return_u32 = return_u64.and_then(|value| u32::try_from(value).ok());
    let return_bool = word.and_then(word_to_bool);
    let raw_line = match &return_hex {
        Some(hex) => format!("evm call {sequence}:{call}: return_hex={hex}"),
        None => format!("evm call {sequence}:{call}: return_hex="),
    };

    CallOutcome {
        sequence,
        call: call.to_string(),
        return_hex,
        return_u64,
        return_u32,
        return_bool,
        raw_line,
    }
}

fn word_to_u64(word: &[u8]) -> Option<u64> {
    if word.len() != 32 || word[..24].iter().any(|byte| *byte != 0) {
        return None;
    }
    Some(u64::from_be_bytes(word[24..32].try_into().ok()?))
}

fn word_to_bool(word: &[u8]) -> Option<bool> {
    match word_to_u64(word)? {
        0 => Some(false),
        1 => Some(true),
        _ => None,
    }
}

fn load_selectors(path: &Path) -> Result<HashMap<String, [u8; 4]>> {
    let text =
        fs::read_to_string(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    let artifact: ArtifactMetadata = serde_json::from_str(&text)
        .with_context(|| format!("failed to parse `{}`", path.display()))?;
    ensure!(
        artifact.target == "evm",
        "EVM artifact `{}` has target `{}`",
        path.display(),
        artifact.target
    );
    ensure!(
        artifact.source_kind == "portable-ir",
        "EVM artifact `{}` has sourceKind `{}`",
        path.display(),
        artifact.source_kind
    );

    let mut selectors = HashMap::new();
    for entrypoint in artifact.abi.entrypoints {
        selectors.insert(entrypoint.name, selector_bytes(&entrypoint.selector)?);
    }
    for method in artifact.abi.methods {
        let name = method
            .signature
            .as_deref()
            .and_then(|signature| signature.split_once('(').map(|(name, _)| name.to_string()))
            .unwrap_or(method.fn_name);
        selectors.insert(name, selector_bytes(&method.selector)?);
    }
    Ok(selectors)
}

fn selector_bytes(selector: &str) -> Result<[u8; 4]> {
    let bytes = decode_hex(selector).with_context(|| format!("invalid selector `{selector}`"))?;
    ensure!(
        bytes.len() == 4,
        "selector `{selector}` decoded to {} bytes, expected 4",
        bytes.len()
    );
    Ok(bytes.try_into().expect("selector length checked"))
}

#[derive(Debug, Deserialize)]
struct ArtifactMetadata {
    target: String,
    #[serde(rename = "sourceKind")]
    source_kind: String,
    abi: ArtifactAbi,
}

#[derive(Debug, Deserialize)]
struct ArtifactAbi {
    #[serde(default)]
    entrypoints: Vec<ArtifactEntrypoint>,
    #[serde(default)]
    methods: Vec<ArtifactMethod>,
}

#[derive(Debug, Deserialize)]
struct ArtifactEntrypoint {
    name: String,
    selector: String,
}

#[derive(Debug, Deserialize)]
struct ArtifactMethod {
    selector: String,
    #[serde(default)]
    signature: Option<String>,
    #[serde(rename = "fnName")]
    fn_name: String,
}

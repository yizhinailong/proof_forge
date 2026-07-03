use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};

use anyhow::{bail, ensure, Context, Result};
use mollusk_svm::Mollusk;
use proof_forge_testkit_core::{CallOutcome, ChainHarness, HarnessRun, ScenarioCase};
use serde::Deserialize;
use solana_account::Account;
use solana_address::Address;
use solana_instruction::{AccountMeta, Instruction};

const PROJECT_NAME: &str = "proofforge-counter";
const COUNTER_DATA_LEN: usize = 8;

pub struct SolanaHarness;

impl SolanaHarness {
    pub fn new() -> Self {
        Self
    }
}

impl Default for SolanaHarness {
    fn default() -> Self {
        Self::new()
    }
}

impl ChainHarness for SolanaHarness {
    fn target_id(&self) -> &'static str {
        "solana-sbpf-asm"
    }

    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<HarnessRun> {
        let sbpf = tool("SBPF", "sbpf");
        if !command_available(&sbpf) {
            return Ok(HarnessRun::skipped(format!(
                "sbpf not on PATH (set SBPF or install blueshift-gg/sbpf)"
            )));
        }

        let keygen = tool("SOLANA_KEYGEN", "solana-keygen");
        if !command_available(&keygen) {
            return Ok(HarnessRun::skipped(
                "solana-keygen not on PATH (set SOLANA_KEYGEN)",
            ));
        }

        match case.manifest.scenario.fixture.as_str() {
            "counter" => run_counter_scenario(case, repo_root, &sbpf, &keygen),
            fixture => {
                bail!("solana-sbpf-asm testkit harness does not support fixture `{fixture}` yet")
            }
        }
    }
}

fn run_counter_scenario(
    case: &ScenarioCase,
    repo_root: &Path,
    sbpf: &str,
    keygen: &str,
) -> Result<HarnessRun> {
    let artifact = build_counter_fixture(repo_root, sbpf, keygen)?;
    let tags = load_instruction_tags(&artifact.manifest_path)?;
    let pid = program_id(&artifact.keypair_path)?;
    let mollusk = mollusk(pid, &artifact.program_path)?;
    let counter = Address::new_unique();
    let mut counter_account = Account::new(0, COUNTER_DATA_LEN, &pid);

    let mut outcomes = Vec::new();
    let mut sequence = 1u32;
    for step in &case.manifest.steps {
        if step.input_hex.is_some() {
            bail!("solana-sbpf-asm testkit harness does not yet support per-step input_hex");
        }
        let tag = tags
            .get(&step.call)
            .with_context(|| format!("Solana manifest does not contain call `{}`", step.call))?;
        for _ in 0..step.repeat.unwrap_or(1) {
            let result = mollusk.process_instruction(
                &ix(pid, *tag, counter),
                &[(counter, counter_account.clone())],
            );
            ensure!(
                result.raw_result.is_ok(),
                "Solana call `{}` did not succeed: {:?}",
                step.call,
                result.raw_result
            );
            counter_account = result
                .get_account(&counter)
                .with_context(|| {
                    format!("Solana call `{}` did not return counter account", step.call)
                })?
                .clone();
            outcomes.push(outcome_from_return_data(
                sequence,
                &step.call,
                &result.return_data,
            ));
            sequence += 1;
        }
    }

    Ok(HarnessRun::passed(outcomes))
}

struct SolanaFixtureArtifact {
    manifest_path: PathBuf,
    keypair_path: PathBuf,
    program_path: PathBuf,
}

fn build_counter_fixture(
    repo_root: &Path,
    sbpf: &str,
    keygen: &str,
) -> Result<SolanaFixtureArtifact> {
    let out_dir = repo_root.join("build/testkit/solana/counter");
    fs::create_dir_all(&out_dir)
        .with_context(|| format!("failed to create `{}`", out_dir.display()))?;

    let mut build = Command::new("lake");
    build.current_dir(repo_root).args(["build", "proof-forge"]);
    run_required(&mut build, "lake build proof-forge")?;

    let asm_path = out_dir.join("Counter.s");
    let artifact_path = out_dir.join("proof-forge-artifact.json");
    let proof_forge = repo_root.join(".lake/build/bin/proof-forge");
    let mut emit = Command::new(&proof_forge);
    emit.current_dir(repo_root).args([
        "--emit-counter-ir-sbpf",
        "-o",
        path_str(&asm_path)?,
        "--artifact-output",
        path_str(&artifact_path)?,
    ]);
    run_required(&mut emit, "proof-forge --emit-counter-ir-sbpf")?;

    ensure!(
        asm_path.exists(),
        "Counter Solana emission did not create `{}`",
        asm_path.display()
    );
    ensure!(
        artifact_path.exists(),
        "Counter Solana emission did not create `{}`",
        artifact_path.display()
    );
    let manifest_path = out_dir.join("manifest.toml");
    ensure!(
        manifest_path.exists(),
        "Counter Solana emission did not create `{}`",
        manifest_path.display()
    );
    assert_golden_asm(repo_root, &asm_path)?;
    validate_artifact_metadata(&artifact_path)?;
    validate_manifest(&manifest_path)?;

    let project_dir = out_dir.join("sbpf-project");
    let keypair_path = project_dir
        .join("deploy")
        .join(format!("{PROJECT_NAME}-keypair.json"));
    let program_path = project_dir.join("deploy").join(PROJECT_NAME);
    scaffold_sbpf_project(&project_dir, &asm_path, keygen)?;

    let mut sbpf_build = Command::new(sbpf);
    sbpf_build.current_dir(&project_dir).arg("build");
    run_required(&mut sbpf_build, "sbpf build")?;

    let elf_path = program_path.with_extension("so");
    ensure!(
        elf_path.exists(),
        "Solana sbpf build did not create `{}`",
        elf_path.display()
    );

    Ok(SolanaFixtureArtifact {
        manifest_path,
        keypair_path,
        program_path,
    })
}

fn scaffold_sbpf_project(project_dir: &Path, asm_path: &Path, keygen: &str) -> Result<()> {
    match fs::remove_dir_all(project_dir) {
        Ok(()) => {}
        Err(error) if error.kind() == ErrorKind::NotFound => {}
        Err(error) => {
            return Err(error)
                .with_context(|| format!("failed to remove `{}`", project_dir.display()));
        }
    }

    let src_dir = project_dir.join("src").join(PROJECT_NAME);
    let deploy_dir = project_dir.join("deploy");
    fs::create_dir_all(&src_dir)
        .with_context(|| format!("failed to create `{}`", src_dir.display()))?;
    fs::create_dir_all(&deploy_dir)
        .with_context(|| format!("failed to create `{}`", deploy_dir.display()))?;
    fs::copy(asm_path, src_dir.join(format!("{PROJECT_NAME}.s"))).with_context(|| {
        format!(
            "failed to copy `{}` into `{}`",
            asm_path.display(),
            src_dir.display()
        )
    })?;
    fs::write(
        project_dir.join("Cargo.toml"),
        format!("[package]\nname = \"{PROJECT_NAME}\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"),
    )
    .with_context(|| {
        format!(
            "failed to write `{}`",
            project_dir.join("Cargo.toml").display()
        )
    })?;

    let keypair_path = deploy_dir.join(format!("{PROJECT_NAME}-keypair.json"));
    let mut keygen_cmd = Command::new(keygen);
    keygen_cmd.args([
        "new",
        "--no-bip39-passphrase",
        "--silent",
        "-o",
        path_str(&keypair_path)?,
        "--force",
    ]);
    run_required(&mut keygen_cmd, "solana-keygen new")?;
    Ok(())
}

fn mollusk(pid: Address, program_path: &Path) -> Result<Mollusk> {
    let program_path = path_str(program_path)?;
    let restore_log_env = env::var_os("RUST_LOG").is_none();
    if restore_log_env {
        env::set_var("RUST_LOG", "error");
    }
    let mut mollusk = Mollusk::new(&pid, program_path);
    if restore_log_env {
        env::remove_var("RUST_LOG");
    }
    // Match the checked-in Mollusk templates for the current Phase 1 ABI.
    mollusk.feature_set.account_data_direct_mapping = false;
    mollusk.feature_set.direct_account_pointers_in_program_input = false;
    mollusk.feature_set.virtual_address_space_adjustments = false;
    Ok(mollusk)
}

fn ix(pid: Address, tag: u8, counter: Address) -> Instruction {
    Instruction::new_with_bytes(pid, &[tag], vec![AccountMeta::new(counter, false)])
}

fn outcome_from_return_data(sequence: u32, call: &str, return_data: &[u8]) -> CallOutcome {
    let return_hex = if return_data.is_empty() {
        None
    } else {
        Some(hex::encode(return_data))
    };
    let return_u64 = if return_data.len() == 8 {
        Some(u64::from_le_bytes(
            return_data.try_into().expect("return_data length checked"),
        ))
    } else {
        None
    };
    let return_u32 = return_u64.and_then(|value| u32::try_from(value).ok());
    let return_bool = match return_u64 {
        Some(0) => Some(false),
        Some(1) => Some(true),
        _ => None,
    };
    let raw_line = match &return_hex {
        Some(hex) => format!("solana-sbpf-asm call {sequence}:{call}: return_hex={hex}"),
        None => format!("solana-sbpf-asm call {sequence}:{call}: return_hex="),
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

fn assert_golden_asm(repo_root: &Path, asm_path: &Path) -> Result<()> {
    let golden_path = repo_root.join("Examples/Solana/Counter.golden.s");
    let expected = fs::read(&golden_path)
        .with_context(|| format!("failed to read `{}`", golden_path.display()))?;
    let actual =
        fs::read(asm_path).with_context(|| format!("failed to read `{}`", asm_path.display()))?;
    ensure!(
        expected == actual,
        "emitted Solana Counter assembly differs from `{}`",
        golden_path.display()
    );
    Ok(())
}

fn validate_artifact_metadata(path: &Path) -> Result<()> {
    let text =
        fs::read_to_string(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    let artifact: ArtifactMetadata = serde_json::from_str(&text)
        .with_context(|| format!("failed to parse `{}`", path.display()))?;
    ensure!(
        artifact.target == "solana-sbpf-asm",
        "Solana artifact `{}` has target `{}`",
        path.display(),
        artifact.target
    );
    ensure!(
        artifact.target_family == "solana",
        "Solana artifact `{}` has targetFamily `{}`",
        path.display(),
        artifact.target_family
    );
    ensure!(
        artifact.artifact_kind == "solana-elf",
        "Solana artifact `{}` has artifactKind `{}`",
        path.display(),
        artifact.artifact_kind
    );
    ensure!(
        artifact.fixture == "counter-ir-sbpf",
        "Solana artifact `{}` has fixture `{}`",
        path.display(),
        artifact.fixture
    );
    ensure!(
        artifact.source_kind == "portable-ir",
        "Solana artifact `{}` has sourceKind `{}`",
        path.display(),
        artifact.source_kind
    );
    for capability in ["storage.scalar", "account.explicit", "control.conditional"] {
        ensure!(
            artifact
                .capabilities
                .iter()
                .any(|candidate| candidate == capability),
            "Solana artifact `{}` missing capability `{capability}`",
            path.display()
        );
    }
    ensure!(
        artifact.validation.manifest_generation == "passed",
        "Solana artifact `{}` has manifestGeneration `{}`",
        path.display(),
        artifact.validation.manifest_generation
    );
    Ok(())
}

fn validate_manifest(path: &Path) -> Result<()> {
    let text =
        fs::read_to_string(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    let manifest: SolanaManifest =
        toml::from_str(&text).with_context(|| format!("failed to parse `{}`", path.display()))?;
    ensure!(
        manifest.target == "solana-sbpf-asm",
        "Solana manifest `{}` has target `{}`",
        path.display(),
        manifest.target
    );
    ensure!(
        manifest.program.name == "counter",
        "Solana manifest `{}` has program name `{}`",
        path.display(),
        manifest.program.name
    );
    let tags = load_instruction_tags(path)?;
    for (name, tag) in [("initialize", 0), ("increment", 1), ("get", 2)] {
        ensure!(
            tags.get(name) == Some(&tag),
            "Solana manifest `{}` missing instruction `{name}` tag {tag}",
            path.display()
        );
    }
    Ok(())
}

fn load_instruction_tags(path: &Path) -> Result<HashMap<String, u8>> {
    let text =
        fs::read_to_string(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    let manifest: SolanaManifest =
        toml::from_str(&text).with_context(|| format!("failed to parse `{}`", path.display()))?;
    let mut tags = HashMap::new();
    for instruction in manifest.instruction {
        tags.insert(instruction.name, instruction.tag);
    }
    Ok(tags)
}

fn program_id(keypair_path: &Path) -> Result<Address> {
    let keypair_bytes = fs::read(keypair_path)
        .with_context(|| format!("failed to read `{}`", keypair_path.display()))?;
    ensure!(
        keypair_bytes.len() >= 32,
        "Solana keypair `{}` is shorter than 32 bytes",
        keypair_path.display()
    );
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&keypair_bytes[..32]);
    Ok(Address::new_from_array(arr))
}

fn run_required(command: &mut Command, description: &str) -> Result<Output> {
    let output = command
        .output()
        .with_context(|| format!("failed to run {description}"))?;
    if !output.status.success() {
        bail!(
            "{description} failed\nstdout:\n{}\nstderr:\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }
    Ok(output)
}

fn command_available(command: &str) -> bool {
    Command::new(command)
        .arg("--version")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn tool(env_key: &str, default: &str) -> String {
    env::var(env_key).unwrap_or_else(|_| default.to_string())
}

fn path_str(path: &Path) -> Result<&str> {
    path.to_str()
        .ok_or_else(|| anyhow::anyhow!("non-UTF-8 path `{}`", path.display()))
}

#[derive(Debug, Deserialize)]
struct ArtifactMetadata {
    target: String,
    #[serde(rename = "targetFamily")]
    target_family: String,
    #[serde(rename = "artifactKind")]
    artifact_kind: String,
    fixture: String,
    #[serde(rename = "sourceKind")]
    source_kind: String,
    capabilities: Vec<String>,
    validation: ArtifactValidation,
}

#[derive(Debug, Deserialize)]
struct ArtifactValidation {
    #[serde(rename = "manifestGeneration")]
    manifest_generation: String,
}

#[derive(Debug, Deserialize)]
struct SolanaManifest {
    target: String,
    program: ManifestProgram,
    instruction: Vec<ManifestInstruction>,
}

#[derive(Debug, Deserialize)]
struct ManifestProgram {
    name: String,
}

#[derive(Debug, Deserialize)]
struct ManifestInstruction {
    name: String,
    tag: u8,
}

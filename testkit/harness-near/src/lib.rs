use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, ensure, Context, Result};
use proof_forge_testkit_core::{
    parse_offline_host_outcomes, ChainHarness, HarnessRun, ScenarioCase,
};

pub struct NearHarness;

impl NearHarness {
    pub fn new() -> Self {
        Self
    }
}

impl Default for NearHarness {
    fn default() -> Self {
        Self::new()
    }
}

impl ChainHarness for NearHarness {
    fn target_id(&self) -> &'static str {
        "wasm-near"
    }

    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<HarnessRun> {
        let artifact = build_fixture(case, repo_root)?;
        let mut args = vec!["run".to_string(), artifact.display().to_string()];
        let mut inputs = Vec::new();
        let mut has_inputs = false;
        for step in &case.manifest.steps {
            let input = step.portable_input_bytes_le().with_context(|| {
                format!("failed to encode wasm-near input for call `{}`", step.call)
            })?;
            has_inputs |= !input.is_empty() || step.input_hex.is_some() || !step.args.is_empty();
            for _ in 0..step.repeat.unwrap_or(1) {
                args.push(step.call.clone());
                inputs.push(hex::encode(&input));
            }
        }
        if has_inputs {
            args.push("--inputs-hex".to_string());
            args.push(inputs.join(","));
        }

        let output = Command::new("cargo")
            .current_dir(repo_root)
            .args([
                "run",
                "--quiet",
                "--manifest-path",
                "runtime/offline-host/Cargo.toml",
                "--",
            ])
            .args(&args)
            .output()
            .context("failed to run runtime/offline-host")?;

        if !output.status.success() {
            bail!(
                "runtime/offline-host failed for scenario `{}`\nstdout:\n{}\nstderr:\n{}",
                case.manifest.scenario.name,
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
        }

        parse_offline_host_outcomes(&String::from_utf8_lossy(&output.stdout))
            .map(HarnessRun::passed)
    }
}

fn build_fixture(case: &ScenarioCase, repo_root: &Path) -> Result<PathBuf> {
    match case.manifest.scenario.fixture.as_str() {
        "counter" => emit_wat_fixture(
            repo_root,
            "Tests/EmitWatSmoke.lean",
            "Counter",
            "build/wasm-near/emitwat-counter.wat",
        ),
        "value-vault" => emit_wat_fixture(
            repo_root,
            "Tests/EmitWatValueVault.lean",
            "ValueVault",
            "build/wasm-near/emitwat-value-vault.wat",
        ),
        fixture => bail!("wasm-near testkit harness does not support fixture `{fixture}` yet"),
    }
}

fn emit_wat_fixture(
    repo_root: &Path,
    emitter: &str,
    fixture_name: &str,
    artifact_path: &str,
) -> Result<PathBuf> {
    let output = Command::new("lake")
        .current_dir(repo_root)
        .args(["env", "lean", "--run", emitter])
        .output()
        .with_context(|| format!("failed to emit {fixture_name} WAT through Lean"))?;
    if !output.status.success() {
        bail!(
            "{fixture_name} WAT emission failed\nstdout:\n{}\nstderr:\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }
    let artifact = repo_root.join(artifact_path);
    ensure!(
        artifact.exists(),
        "{fixture_name} WAT emission did not create `{}`",
        artifact.display()
    );
    Ok(artifact)
}

use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, ensure, Context, Result};
use proof_forge_testkit_core::{
    parse_offline_host_outcomes, CallOutcome, ChainHarness, ScenarioCase,
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

    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<Vec<CallOutcome>> {
        let artifact = build_fixture(case, repo_root)?;
        let mut args = vec!["run".to_string(), artifact.display().to_string()];
        for step in &case.manifest.steps {
            if step.input_hex.is_some() {
                bail!("wasm-near testkit harness does not yet support per-step input_hex");
            }
            for _ in 0..step.repeat.unwrap_or(1) {
                args.push(step.call.clone());
            }
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
    }
}

fn build_fixture(case: &ScenarioCase, repo_root: &Path) -> Result<PathBuf> {
    match case.manifest.scenario.fixture.as_str() {
        "counter" => {
            let output = Command::new("lake")
                .current_dir(repo_root)
                .args(["env", "lean", "--run", "Tests/EmitWatSmoke.lean"])
                .output()
                .context("failed to emit Counter WAT through Lean")?;
            if !output.status.success() {
                bail!(
                    "Counter WAT emission failed\nstdout:\n{}\nstderr:\n{}",
                    String::from_utf8_lossy(&output.stdout),
                    String::from_utf8_lossy(&output.stderr)
                );
            }
            let artifact = repo_root.join("build/wasm-near/emitwat-counter.wat");
            ensure!(
                artifact.exists(),
                "Counter WAT emission did not create `{}`",
                artifact.display()
            );
            Ok(artifact)
        }
        fixture => bail!("wasm-near testkit harness does not support fixture `{fixture}` yet"),
    }
}

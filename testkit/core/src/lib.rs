use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, ensure, Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone)]
pub struct ScenarioCase {
    pub path: PathBuf,
    pub manifest: ScenarioManifest,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ScenarioManifest {
    pub scenario: Scenario,
    #[serde(default, rename = "step")]
    pub steps: Vec<Step>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Scenario {
    pub name: String,
    pub fixture: String,
    #[serde(default)]
    pub targets: Vec<String>,
    #[serde(default)]
    pub capabilities: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Step {
    pub call: String,
    #[serde(default)]
    pub repeat: Option<u32>,
    #[serde(default)]
    pub input_hex: Option<String>,
    #[serde(default)]
    pub expect: Option<Expectation>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Expectation {
    #[serde(default)]
    pub return_value: Option<ReturnExpectation>,
    #[serde(default, rename = "return")]
    pub return_: Option<ReturnExpectation>,
}

impl Expectation {
    fn expected_return(&self) -> Option<&ReturnExpectation> {
        self.return_value.as_ref().or(self.return_.as_ref())
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ReturnExpectation {
    #[serde(default)]
    pub hex: Option<String>,
    #[serde(default)]
    pub u64: Option<u64>,
    #[serde(default)]
    pub u32: Option<u32>,
    #[serde(default)]
    pub bool: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CallOutcome {
    pub sequence: u32,
    pub call: String,
    pub return_hex: Option<String>,
    pub return_u64: Option<u64>,
    pub return_u32: Option<u32>,
    pub return_bool: Option<bool>,
    pub raw_line: String,
}

pub trait ChainHarness {
    fn target_id(&self) -> &'static str;
    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<Vec<CallOutcome>>;
}

pub fn discover_scenarios(dir: &Path) -> Result<Vec<ScenarioCase>> {
    let mut paths = Vec::new();
    for entry in fs::read_dir(dir)
        .with_context(|| format!("failed to read scenario directory `{}`", dir.display()))?
    {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) == Some("toml") {
            paths.push(path);
        }
    }
    paths.sort();

    let mut scenarios = Vec::with_capacity(paths.len());
    for path in paths {
        let text = fs::read_to_string(&path)
            .with_context(|| format!("failed to read scenario `{}`", path.display()))?;
        let manifest: ScenarioManifest = toml::from_str(&text)
            .with_context(|| format!("failed to parse scenario `{}`", path.display()))?;
        ensure!(
            !manifest.scenario.name.trim().is_empty(),
            "scenario `{}` has an empty name",
            path.display()
        );
        ensure!(
            !manifest.scenario.fixture.trim().is_empty(),
            "scenario `{}` has an empty fixture",
            path.display()
        );
        ensure!(
            !manifest.scenario.targets.is_empty(),
            "scenario `{}` has no targets",
            path.display()
        );
        ensure!(
            !manifest.steps.is_empty(),
            "scenario `{}` has no steps",
            path.display()
        );
        for step in &manifest.steps {
            ensure!(
                step.repeat.unwrap_or(1) > 0,
                "scenario `{}` step `{}` has repeat=0",
                manifest.scenario.name,
                step.call
            );
        }
        scenarios.push(ScenarioCase { path, manifest });
    }
    Ok(scenarios)
}

pub fn assert_expectations(case: &ScenarioCase, outcomes: &[CallOutcome]) -> Result<()> {
    let expected_len: usize = case
        .manifest
        .steps
        .iter()
        .map(|step| step.repeat.unwrap_or(1) as usize)
        .sum();
    ensure!(
        outcomes.len() == expected_len,
        "scenario `{}` expected {expected_len} call outcomes, got {}",
        case.manifest.scenario.name,
        outcomes.len()
    );

    let mut index = 0;
    for step in &case.manifest.steps {
        for _ in 0..step.repeat.unwrap_or(1) {
            let outcome = &outcomes[index];
            ensure!(
                outcome.call == step.call,
                "scenario `{}` expected call `{}` at outcome {}, got `{}`",
                case.manifest.scenario.name,
                step.call,
                index + 1,
                outcome.call
            );
            if let Some(expect) = &step.expect {
                if let Some(expected_return) = expect.expected_return() {
                    assert_return(
                        &case.manifest.scenario.name,
                        &step.call,
                        expected_return,
                        outcome,
                    )?;
                }
            }
            index += 1;
        }
    }

    Ok(())
}

fn assert_return(
    scenario: &str,
    call: &str,
    expected: &ReturnExpectation,
    outcome: &CallOutcome,
) -> Result<()> {
    if let Some(hex) = &expected.hex {
        let expected_hex = normalize_hex(hex);
        ensure!(
            outcome.return_hex.as_deref() == Some(expected_hex.as_str()),
            "scenario `{scenario}` call `{call}` expected return hex `{expected_hex}`, got {:?}",
            outcome.return_hex
        );
    }
    if let Some(value) = expected.u64 {
        ensure!(
            outcome.return_u64 == Some(value),
            "scenario `{scenario}` call `{call}` expected u64 `{value}`, got {:?}",
            outcome.return_u64
        );
    }
    if let Some(value) = expected.u32 {
        ensure!(
            outcome.return_u32 == Some(value),
            "scenario `{scenario}` call `{call}` expected u32 `{value}`, got {:?}",
            outcome.return_u32
        );
    }
    if let Some(value) = expected.bool {
        ensure!(
            outcome.return_bool == Some(value),
            "scenario `{scenario}` call `{call}` expected bool `{value}`, got {:?}",
            outcome.return_bool
        );
    }
    Ok(())
}

pub fn parse_offline_host_outcomes(stdout: &str) -> Result<Vec<CallOutcome>> {
    let mut outcomes = Vec::new();
    for line in stdout.lines() {
        let Some(rest) = line.strip_prefix("call ") else {
            continue;
        };
        let Some((sequence_and_call, details)) = rest.split_once(": ") else {
            bail!("malformed offline-host call line: `{line}`");
        };
        let Some((sequence, call)) = sequence_and_call.split_once(':') else {
            bail!("malformed offline-host call header: `{line}`");
        };
        let sequence = sequence
            .parse::<u32>()
            .with_context(|| format!("malformed offline-host sequence in `{line}`"))?;
        let mut outcome = CallOutcome {
            sequence,
            call: call.to_string(),
            return_hex: None,
            return_u64: None,
            return_u32: None,
            return_bool: None,
            raw_line: line.to_string(),
        };
        for token in details.split_whitespace() {
            let Some((key, value)) = token.split_once('=') else {
                continue;
            };
            match key {
                "return_hex" => outcome.return_hex = Some(normalize_hex(value)),
                "return_u64" => outcome.return_u64 = Some(value.parse()?),
                "return_u32" => outcome.return_u32 = Some(value.parse()?),
                "return_bool" => outcome.return_bool = Some(value.parse()?),
                _ => {}
            }
        }
        outcomes.push(outcome);
    }
    Ok(outcomes)
}

fn normalize_hex(value: &str) -> String {
    value
        .strip_prefix("0x")
        .unwrap_or(value)
        .to_ascii_lowercase()
}

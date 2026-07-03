use std::collections::HashSet;
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, ensure, Context, Result};
use serde::Deserialize;
use serde_json::Value as JsonValue;
use sha2::{Digest, Sha256};
use toml::Value as TomlValue;

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
    #[serde(default, rename = "artifact")]
    pub artifacts: Vec<ArtifactExpectation>,
    #[serde(default, rename = "diagnostic")]
    pub diagnostics: Vec<DiagnosticExpectation>,
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
pub struct ArtifactExpectation {
    pub target: String,
    pub name: String,
    #[serde(default)]
    pub matches_file: Option<PathBuf>,
    #[serde(default)]
    pub contains: Vec<String>,
    #[serde(default, rename = "json")]
    pub json_checks: Vec<StructuredArtifactCheck>,
    #[serde(default, rename = "toml")]
    pub toml_checks: Vec<StructuredArtifactCheck>,
    #[serde(default, rename = "file")]
    pub file_checks: Vec<FileArtifactCheck>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct StructuredArtifactCheck {
    pub path: String,
    #[serde(default)]
    pub equals: Option<TomlValue>,
    #[serde(default)]
    pub contains: Option<TomlValue>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct FileArtifactCheck {
    pub path: String,
    pub artifact: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DiagnosticExpectation {
    pub target: String,
    pub name: String,
    #[serde(default)]
    pub contains: Vec<String>,
}

#[derive(Debug, Clone, Copy)]
pub struct ArtifactOutput<'a> {
    pub name: &'a str,
    pub path: &'a Path,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Step {
    pub call: String,
    #[serde(default)]
    pub repeat: Option<u32>,
    #[serde(default)]
    pub input_hex: Option<String>,
    #[serde(default, rename = "arg")]
    pub args: Vec<StepArg>,
    #[serde(default)]
    pub expect: Option<Expectation>,
}

impl Step {
    pub fn portable_input_bytes_le(&self) -> Result<Vec<u8>> {
        if let Some(input_hex) = &self.input_hex {
            ensure!(
                self.args.is_empty(),
                "step `{}` cannot combine input_hex with typed args",
                self.call
            );
            return decode_hex_bytes(input_hex);
        }

        let mut bytes = Vec::new();
        for arg in &self.args {
            bytes.extend(arg.encode_le()?);
        }
        Ok(bytes)
    }

    pub fn evm_abi_input_bytes(&self) -> Result<Vec<u8>> {
        if let Some(input_hex) = &self.input_hex {
            ensure!(
                self.args.is_empty(),
                "step `{}` cannot combine input_hex with typed args",
                self.call
            );
            return decode_hex_bytes(input_hex);
        }

        let mut bytes = Vec::new();
        for arg in &self.args {
            bytes.extend(arg.encode_evm_word()?);
        }
        Ok(bytes)
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct StepArg {
    #[serde(default, rename = "u64")]
    pub u64_value: Option<u64>,
    #[serde(default, rename = "u32")]
    pub u32_value: Option<u32>,
    #[serde(default)]
    pub bool: Option<bool>,
}

impl StepArg {
    fn validate(&self) -> Result<()> {
        let count = usize::from(self.u64_value.is_some())
            + usize::from(self.u32_value.is_some())
            + usize::from(self.bool.is_some());
        ensure!(
            count == 1,
            "typed step args must specify exactly one of `u64`, `u32`, or `bool`"
        );
        Ok(())
    }

    fn encode_le(&self) -> Result<Vec<u8>> {
        self.validate()?;
        if let Some(value) = self.u64_value {
            return Ok(value.to_le_bytes().to_vec());
        }
        if let Some(value) = self.u32_value {
            return Ok(value.to_le_bytes().to_vec());
        }
        if let Some(value) = self.bool {
            return Ok(vec![u8::from(value)]);
        }
        unreachable!("StepArg::validate checked exactly one value")
    }

    fn encode_evm_word(&self) -> Result<Vec<u8>> {
        self.validate()?;
        let mut word = vec![0u8; 32];
        if let Some(value) = self.u64_value {
            word[24..32].copy_from_slice(&value.to_be_bytes());
            return Ok(word);
        }
        if let Some(value) = self.u32_value {
            word[28..32].copy_from_slice(&value.to_be_bytes());
            return Ok(word);
        }
        if let Some(value) = self.bool {
            word[31] = u8::from(value);
            return Ok(word);
        }
        unreachable!("StepArg::validate checked exactly one value")
    }
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
    fn run_scenario(&self, case: &ScenarioCase, repo_root: &Path) -> Result<HarnessRun>;
    fn run_diagnostic(
        &self,
        case: &ScenarioCase,
        diagnostic: &DiagnosticExpectation,
        _repo_root: &Path,
    ) -> Result<DiagnosticRun> {
        bail!(
            "target `{}` does not support diagnostic `{}` for scenario `{}`",
            self.target_id(),
            diagnostic.name,
            case.manifest.scenario.name
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HarnessRun {
    Passed(Vec<CallOutcome>),
    Skipped { reason: String },
}

impl HarnessRun {
    pub fn passed(outcomes: Vec<CallOutcome>) -> Self {
        Self::Passed(outcomes)
    }

    pub fn skipped(reason: impl Into<String>) -> Self {
        Self::Skipped {
            reason: reason.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DiagnosticRun {
    Passed,
    Skipped { reason: String },
}

impl DiagnosticRun {
    pub fn passed() -> Self {
        Self::Passed
    }

    pub fn skipped(reason: impl Into<String>) -> Self {
        Self::Skipped {
            reason: reason.into(),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct TargetTrace<'a> {
    pub target_id: &'a str,
    pub outcomes: &'a [CallOutcome],
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
        let mut targets = HashSet::with_capacity(manifest.scenario.targets.len());
        for target in &manifest.scenario.targets {
            ensure!(
                !target.trim().is_empty(),
                "scenario `{}` has an empty target id",
                manifest.scenario.name
            );
            ensure!(
                targets.insert(target.as_str()),
                "scenario `{}` lists target `{target}` more than once",
                manifest.scenario.name
            );
        }
        ensure!(
            !manifest.steps.is_empty() || !manifest.diagnostics.is_empty(),
            "scenario `{}` has no steps or diagnostics",
            path.display()
        );
        for step in &manifest.steps {
            ensure!(
                step.repeat.unwrap_or(1) > 0,
                "scenario `{}` step `{}` has repeat=0",
                manifest.scenario.name,
                step.call
            );
            ensure!(
                !(step.input_hex.is_some() && !step.args.is_empty()),
                "scenario `{}` step `{}` cannot combine input_hex with typed [[step.arg]] entries",
                manifest.scenario.name,
                step.call
            );
            for arg in &step.args {
                arg.validate().with_context(|| {
                    format!(
                        "scenario `{}` step `{}` has an invalid typed arg",
                        manifest.scenario.name, step.call
                    )
                })?;
            }
        }
        for artifact in &manifest.artifacts {
            ensure!(
                !artifact.target.trim().is_empty(),
                "scenario `{}` has an artifact expectation with an empty target",
                manifest.scenario.name
            );
            ensure!(
                targets.contains(artifact.target.as_str()),
                "scenario `{}` artifact expectation `{}` references target `{}`, but scenario targets are [{}]",
                manifest.scenario.name,
                artifact.name,
                artifact.target,
                manifest.scenario.targets.join(", ")
            );
            ensure!(
                !artifact.name.trim().is_empty(),
                "scenario `{}` has an artifact expectation with an empty name",
                manifest.scenario.name
            );
            ensure!(
                artifact.matches_file.is_some()
                    || !artifact.contains.is_empty()
                    || !artifact.json_checks.is_empty()
                    || !artifact.toml_checks.is_empty()
                    || !artifact.file_checks.is_empty(),
                "scenario `{}` artifact expectation `{}` for target `{}` has no checks",
                manifest.scenario.name,
                artifact.name,
                artifact.target
            );
            for check in &artifact.json_checks {
                validate_structured_artifact_check(
                    &manifest.scenario.name,
                    &artifact.target,
                    &artifact.name,
                    "json",
                    check,
                )?;
            }
            for check in &artifact.toml_checks {
                validate_structured_artifact_check(
                    &manifest.scenario.name,
                    &artifact.target,
                    &artifact.name,
                    "toml",
                    check,
                )?;
            }
            for check in &artifact.file_checks {
                validate_file_artifact_check(
                    &manifest.scenario.name,
                    &artifact.target,
                    &artifact.name,
                    check,
                )?;
            }
        }
        for diagnostic in &manifest.diagnostics {
            ensure!(
                !diagnostic.target.trim().is_empty(),
                "scenario `{}` has a diagnostic expectation with an empty target",
                manifest.scenario.name
            );
            ensure!(
                targets.contains(diagnostic.target.as_str()),
                "scenario `{}` diagnostic expectation `{}` references target `{}`, but scenario targets are [{}]",
                manifest.scenario.name,
                diagnostic.name,
                diagnostic.target,
                manifest.scenario.targets.join(", ")
            );
            ensure!(
                !diagnostic.name.trim().is_empty(),
                "scenario `{}` has a diagnostic expectation with an empty name",
                manifest.scenario.name
            );
            ensure!(
                !diagnostic.contains.is_empty(),
                "scenario `{}` diagnostic expectation `{}` for target `{}` has no contains checks",
                manifest.scenario.name,
                diagnostic.name,
                diagnostic.target
            );
            for needle in &diagnostic.contains {
                ensure!(
                    !needle.is_empty(),
                    "scenario `{}` diagnostic expectation `{}` for target `{}` has an empty contains check",
                    manifest.scenario.name,
                    diagnostic.name,
                    diagnostic.target
                );
            }
        }
        scenarios.push(ScenarioCase { path, manifest });
    }
    Ok(scenarios)
}

pub fn assert_artifact_expectations(
    case: &ScenarioCase,
    target_id: &str,
    repo_root: &Path,
    artifacts: &[ArtifactOutput<'_>],
) -> Result<()> {
    for expectation in case
        .manifest
        .artifacts
        .iter()
        .filter(|artifact| artifact.target == target_id)
    {
        let artifact = artifacts
            .iter()
            .find(|artifact| artifact.name == expectation.name)
            .with_context(|| {
                let names = artifacts
                    .iter()
                    .map(|artifact| artifact.name)
                    .collect::<Vec<_>>()
                    .join(", ");
                format!(
                    "scenario `{}` target `{target_id}` expected artifact `{}`, available artifacts: [{names}]",
                    case.manifest.scenario.name, expectation.name
                )
            })?;
        ensure!(
            artifact.path.exists(),
            "scenario `{}` target `{target_id}` artifact `{}` does not exist at `{}`",
            case.manifest.scenario.name,
            expectation.name,
            artifact.path.display()
        );

        if let Some(expected_path) = &expectation.matches_file {
            let expected_path = repo_root.join(expected_path);
            let expected = fs::read(&expected_path).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` failed to read expected artifact `{}`",
                    case.manifest.scenario.name,
                    expected_path.display()
                )
            })?;
            let actual = fs::read(artifact.path).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` failed to read artifact `{}`",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            ensure!(
                expected == actual,
                "scenario `{}` target `{target_id}` artifact `{}` differs from `{}`",
                case.manifest.scenario.name,
                expectation.name,
                expected_path.display()
            );
        }

        if !expectation.contains.is_empty() {
            let text = fs::read_to_string(artifact.path).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` artifact `{}` is not UTF-8 text",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            for needle in &expectation.contains {
                ensure!(
                    text.contains(needle),
                    "scenario `{}` target `{target_id}` artifact `{}` missing `{needle}` in `{}`",
                    case.manifest.scenario.name,
                    expectation.name,
                    artifact.path.display()
                );
            }
        }

        if !expectation.json_checks.is_empty() || !expectation.file_checks.is_empty() {
            let text = fs::read_to_string(artifact.path).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` failed to read JSON artifact `{}`",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            let json: JsonValue = serde_json::from_str(&text).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` artifact `{}` is not valid JSON",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            for check in &expectation.json_checks {
                assert_json_artifact_check(
                    &case.manifest.scenario.name,
                    target_id,
                    expectation.name.as_str(),
                    artifact.path,
                    &json,
                    check,
                )?;
            }
            for check in &expectation.file_checks {
                assert_json_file_artifact_check(
                    &case.manifest.scenario.name,
                    target_id,
                    expectation.name.as_str(),
                    artifact.path,
                    repo_root,
                    artifacts,
                    &json,
                    check,
                )?;
            }
        }

        if !expectation.toml_checks.is_empty() {
            let text = fs::read_to_string(artifact.path).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` failed to read TOML artifact `{}`",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            let toml: TomlValue = toml::from_str(&text).with_context(|| {
                format!(
                    "scenario `{}` target `{target_id}` artifact `{}` is not valid TOML",
                    case.manifest.scenario.name,
                    artifact.path.display()
                )
            })?;
            for check in &expectation.toml_checks {
                assert_toml_artifact_check(
                    &case.manifest.scenario.name,
                    target_id,
                    expectation.name.as_str(),
                    artifact.path,
                    &toml,
                    check,
                )?;
            }
        }
    }

    Ok(())
}

fn validate_structured_artifact_check(
    scenario: &str,
    target: &str,
    artifact: &str,
    format: &str,
    check: &StructuredArtifactCheck,
) -> Result<()> {
    ensure!(
        !check.path.trim().is_empty(),
        "scenario `{scenario}` {format} artifact check for target `{target}` artifact `{artifact}` has an empty path"
    );
    ensure!(
        check.equals.is_some() || check.contains.is_some(),
        "scenario `{scenario}` {format} artifact check for target `{target}` artifact `{artifact}` path `{}` has no assertion",
        check.path
    );
    Ok(())
}

fn validate_file_artifact_check(
    scenario: &str,
    target: &str,
    artifact: &str,
    check: &FileArtifactCheck,
) -> Result<()> {
    ensure!(
        !check.path.trim().is_empty(),
        "scenario `{scenario}` file artifact check for target `{target}` artifact `{artifact}` has an empty metadata path"
    );
    ensure!(
        !check.artifact.trim().is_empty(),
        "scenario `{scenario}` file artifact check for target `{target}` artifact `{artifact}` path `{}` has an empty artifact name",
        check.path
    );
    Ok(())
}

fn assert_json_artifact_check(
    scenario: &str,
    target_id: &str,
    artifact_name: &str,
    artifact_path: &Path,
    json: &JsonValue,
    check: &StructuredArtifactCheck,
) -> Result<()> {
    let actual = json_path(json, &check.path).with_context(|| {
        format!(
            "scenario `{scenario}` target `{target_id}` JSON artifact `{artifact_name}` missing path `{}` in `{}`",
            check.path,
            artifact_path.display()
        )
    })?;
    if let Some(expected) = &check.equals {
        ensure!(
            json_equals_toml(actual, expected),
            "scenario `{scenario}` target `{target_id}` JSON artifact `{artifact_name}` path `{}` expected {}, got {} in `{}`",
            check.path,
            display_toml_value(expected),
            actual,
            artifact_path.display()
        );
    }
    if let Some(expected) = &check.contains {
        ensure!(
            json_contains_toml(actual, expected),
            "scenario `{scenario}` target `{target_id}` JSON artifact `{artifact_name}` path `{}` expected to contain {}, got {} in `{}`",
            check.path,
            display_toml_value(expected),
            actual,
            artifact_path.display()
        );
    }
    Ok(())
}

fn assert_json_file_artifact_check(
    scenario: &str,
    target_id: &str,
    metadata_artifact_name: &str,
    metadata_artifact_path: &Path,
    repo_root: &Path,
    artifacts: &[ArtifactOutput<'_>],
    json: &JsonValue,
    check: &FileArtifactCheck,
) -> Result<()> {
    let entry = json_path(json, &check.path).with_context(|| {
        format!(
            "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` missing file entry `{}` in `{}`",
            check.path,
            metadata_artifact_path.display()
        )
    })?;
    let entry = entry.as_object().with_context(|| {
        format!(
            "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` is not an object in `{}`",
            check.path,
            metadata_artifact_path.display()
        )
    })?;
    let expected_artifact = artifacts
        .iter()
        .find(|artifact| artifact.name == check.artifact)
        .with_context(|| {
            let names = artifacts
                .iter()
                .map(|artifact| artifact.name)
                .collect::<Vec<_>>()
                .join(", ");
            format!(
                "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` references artifact `{}`, available artifacts: [{names}]",
                check.path, check.artifact
            )
        })?;
    ensure!(
        expected_artifact.path.exists(),
        "scenario `{scenario}` target `{target_id}` artifact `{}` referenced by metadata file entry `{}` does not exist at `{}`",
        check.artifact,
        check.path,
        expected_artifact.path.display()
    );

    let declared_path = entry
        .get("path")
        .and_then(JsonValue::as_str)
        .with_context(|| {
            format!(
                "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` is missing string field `path`",
                check.path
            )
        })?;
    let declared_path = resolve_artifact_path(repo_root, declared_path);
    ensure!(
        same_existing_path(&declared_path, expected_artifact.path)?,
        "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` path `{}` does not match artifact `{}` at `{}`",
        check.path,
        declared_path.display(),
        check.artifact,
        expected_artifact.path.display()
    );

    let declared_bytes = entry
        .get("bytes")
        .and_then(JsonValue::as_u64)
        .with_context(|| {
            format!(
                "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` is missing integer field `bytes`",
                check.path
            )
        })?;
    let actual_bytes = expected_artifact
        .path
        .metadata()
        .with_context(|| {
            format!(
                "failed to stat scenario `{scenario}` target `{target_id}` artifact `{}` at `{}`",
                check.artifact,
                expected_artifact.path.display()
            )
        })?
        .len();
    ensure!(
        declared_bytes == actual_bytes,
        "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` bytes expected {actual_bytes}, got {declared_bytes}",
        check.path
    );

    let declared_sha256 = entry
        .get("sha256")
        .and_then(JsonValue::as_str)
        .with_context(|| {
            format!(
                "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` is missing string field `sha256`",
                check.path
            )
        })?;
    let actual_sha256 = sha256_hex(expected_artifact.path)?;
    ensure!(
        declared_sha256 == actual_sha256,
        "scenario `{scenario}` target `{target_id}` JSON artifact `{metadata_artifact_name}` file entry `{}` sha256 expected {actual_sha256}, got {declared_sha256}",
        check.path
    );
    Ok(())
}

fn assert_toml_artifact_check(
    scenario: &str,
    target_id: &str,
    artifact_name: &str,
    artifact_path: &Path,
    toml: &TomlValue,
    check: &StructuredArtifactCheck,
) -> Result<()> {
    let actual = toml_path(toml, &check.path).with_context(|| {
        format!(
            "scenario `{scenario}` target `{target_id}` TOML artifact `{artifact_name}` missing path `{}` in `{}`",
            check.path,
            artifact_path.display()
        )
    })?;
    if let Some(expected) = &check.equals {
        ensure!(
            actual == expected,
            "scenario `{scenario}` target `{target_id}` TOML artifact `{artifact_name}` path `{}` expected {}, got {} in `{}`",
            check.path,
            display_toml_value(expected),
            display_toml_value(actual),
            artifact_path.display()
        );
    }
    if let Some(expected) = &check.contains {
        ensure!(
            toml_contains_toml(actual, expected),
            "scenario `{scenario}` target `{target_id}` TOML artifact `{artifact_name}` path `{}` expected to contain {}, got {} in `{}`",
            check.path,
            display_toml_value(expected),
            display_toml_value(actual),
            artifact_path.display()
        );
    }
    Ok(())
}

fn resolve_artifact_path(repo_root: &Path, path: &str) -> PathBuf {
    let path = PathBuf::from(path);
    if path.is_absolute() {
        path
    } else {
        repo_root.join(path)
    }
}

fn same_existing_path(left: &Path, right: &Path) -> Result<bool> {
    let left = fs::canonicalize(left)
        .with_context(|| format!("failed to canonicalize `{}`", left.display()))?;
    let right = fs::canonicalize(right)
        .with_context(|| format!("failed to canonicalize `{}`", right.display()))?;
    Ok(left == right)
}

fn sha256_hex(path: &Path) -> Result<String> {
    let data = fs::read(path).with_context(|| format!("failed to read `{}`", path.display()))?;
    Ok(format!("{:x}", Sha256::digest(data)))
}

fn json_path<'a>(root: &'a JsonValue, path: &str) -> Result<&'a JsonValue> {
    let mut current = root;
    for segment in path.split('.') {
        let (key, index) = parse_path_segment(segment)?;
        current = current
            .as_object()
            .and_then(|object| object.get(key))
            .with_context(|| format!("missing JSON object key `{key}`"))?;
        if let Some(index) = index {
            current = current
                .as_array()
                .and_then(|array| array.get(index))
                .with_context(|| format!("missing JSON array index `{index}` at `{key}`"))?;
        }
    }
    Ok(current)
}

fn toml_path<'a>(root: &'a TomlValue, path: &str) -> Result<&'a TomlValue> {
    let mut current = root;
    for segment in path.split('.') {
        let (key, index) = parse_path_segment(segment)?;
        current = current
            .get(key)
            .with_context(|| format!("missing TOML table key `{key}`"))?;
        if let Some(index) = index {
            current = current
                .as_array()
                .and_then(|array| array.get(index))
                .with_context(|| format!("missing TOML array index `{index}` at `{key}`"))?;
        }
    }
    Ok(current)
}

fn parse_path_segment(segment: &str) -> Result<(&str, Option<usize>)> {
    ensure!(
        !segment.is_empty(),
        "artifact check path contains an empty segment"
    );
    let Some(open) = segment.find('[') else {
        return Ok((segment, None));
    };
    ensure!(
        segment.ends_with(']'),
        "artifact check path segment `{segment}` has an unterminated array index"
    );
    ensure!(
        segment[open + 1..segment.len() - 1].find('[').is_none(),
        "artifact check path segment `{segment}` has more than one array index"
    );
    let key = &segment[..open];
    ensure!(
        !key.is_empty(),
        "artifact check path segment `{segment}` has an empty key before array index"
    );
    let index_text = &segment[open + 1..segment.len() - 1];
    let index = index_text.parse::<usize>().with_context(|| {
        format!("artifact check path segment `{segment}` has invalid array index")
    })?;
    Ok((key, Some(index)))
}

fn json_equals_toml(actual: &JsonValue, expected: &TomlValue) -> bool {
    match expected {
        TomlValue::String(value) => actual.as_str() == Some(value.as_str()),
        TomlValue::Integer(value) => {
            actual.as_i64() == Some(*value)
                || (*value >= 0 && actual.as_u64() == Some(*value as u64))
        }
        TomlValue::Float(value) => actual.as_f64() == Some(*value),
        TomlValue::Boolean(value) => actual.as_bool() == Some(*value),
        TomlValue::Array(values) => {
            let Some(actual_values) = actual.as_array() else {
                return false;
            };
            actual_values.len() == values.len()
                && actual_values
                    .iter()
                    .zip(values)
                    .all(|(actual, expected)| json_equals_toml(actual, expected))
        }
        TomlValue::Table(values) => {
            let Some(actual_values) = actual.as_object() else {
                return false;
            };
            values.iter().all(|(key, expected)| {
                actual_values
                    .get(key)
                    .is_some_and(|actual| json_equals_toml(actual, expected))
            })
        }
        TomlValue::Datetime(value) => actual.as_str() == Some(value.to_string().as_str()),
    }
}

fn json_contains_toml(actual: &JsonValue, expected: &TomlValue) -> bool {
    if let (Some(actual), Some(expected)) = (actual.as_str(), expected.as_str()) {
        return actual.contains(expected);
    }
    if let Some(array) = actual.as_array() {
        return array.iter().any(|value| json_equals_toml(value, expected));
    }
    false
}

fn toml_contains_toml(actual: &TomlValue, expected: &TomlValue) -> bool {
    if let (Some(actual), Some(expected)) = (actual.as_str(), expected.as_str()) {
        return actual.contains(expected);
    }
    if let Some(array) = actual.as_array() {
        return array.iter().any(|value| value == expected);
    }
    false
}

fn display_toml_value(value: &TomlValue) -> String {
    match value {
        TomlValue::String(value) => format!("{value:?}"),
        TomlValue::Integer(value) => value.to_string(),
        TomlValue::Float(value) => value.to_string(),
        TomlValue::Boolean(value) => value.to_string(),
        TomlValue::Datetime(value) => value.to_string(),
        TomlValue::Array(_) | TomlValue::Table(_) => value.to_string(),
    }
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

pub fn assert_trace_equivalence(case: &ScenarioCase, traces: &[TargetTrace<'_>]) -> Result<()> {
    if traces.len() <= 1 {
        return Ok(());
    }

    let baseline = &traces[0];
    let baseline_trace = normalize_trace(case, baseline)?;
    for trace in &traces[1..] {
        let current_trace = normalize_trace(case, trace)?;
        ensure!(
            current_trace.len() == baseline_trace.len(),
            "scenario `{}` target `{}` produced {} observable outcomes, target `{}` produced {}",
            case.manifest.scenario.name,
            trace.target_id,
            current_trace.len(),
            baseline.target_id,
            baseline_trace.len()
        );
        for (index, (expected, got)) in baseline_trace.iter().zip(current_trace.iter()).enumerate()
        {
            ensure!(
                expected == got,
                "scenario `{}` target `{}` observable trace differs from `{}` at outcome {}: expected {}, got {}",
                case.manifest.scenario.name,
                trace.target_id,
                baseline.target_id,
                index + 1,
                expected,
                got
            );
        }
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ObservableOutcome {
    sequence: u32,
    call: String,
    return_value: ObservableReturn,
}

impl fmt::Display for ObservableOutcome {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "call {}:{} return={}",
            self.sequence, self.call, self.return_value
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum ObservableReturn {
    None,
    U64(u64),
    U32(u32),
    Bool(bool),
    Hex(String),
}

impl fmt::Display for ObservableReturn {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::None => write!(f, "<none>"),
            Self::U64(value) => write!(f, "u64:{value}"),
            Self::U32(value) => write!(f, "u32:{value}"),
            Self::Bool(value) => write!(f, "bool:{value}"),
            Self::Hex(value) => write!(f, "hex:{value}"),
        }
    }
}

fn normalize_trace(case: &ScenarioCase, trace: &TargetTrace<'_>) -> Result<Vec<ObservableOutcome>> {
    let expected_len = expected_outcome_count(case);
    ensure!(
        trace.outcomes.len() == expected_len,
        "scenario `{}` target `{}` expected {expected_len} call outcomes, got {}",
        case.manifest.scenario.name,
        trace.target_id,
        trace.outcomes.len()
    );

    let mut normalized = Vec::with_capacity(trace.outcomes.len());
    let mut index = 0usize;
    for step in &case.manifest.steps {
        for _ in 0..step.repeat.unwrap_or(1) {
            let expected_sequence = (index + 1) as u32;
            let outcome = &trace.outcomes[index];
            ensure!(
                outcome.call == step.call,
                "scenario `{}` target `{}` expected call `{}` at outcome {}, got `{}`",
                case.manifest.scenario.name,
                trace.target_id,
                step.call,
                index + 1,
                outcome.call
            );
            normalized.push(ObservableOutcome {
                sequence: expected_sequence,
                call: step.call.clone(),
                return_value: observable_return_for_step(case, trace.target_id, step, outcome)?,
            });
            index += 1;
        }
    }

    Ok(normalized)
}

fn expected_outcome_count(case: &ScenarioCase) -> usize {
    case.manifest
        .steps
        .iter()
        .map(|step| step.repeat.unwrap_or(1) as usize)
        .sum()
}

fn observable_return_for_step(
    case: &ScenarioCase,
    target_id: &str,
    step: &Step,
    outcome: &CallOutcome,
) -> Result<ObservableReturn> {
    let Some(expected_return) = step.expect.as_ref().and_then(Expectation::expected_return) else {
        return Ok(inferred_observable_return(outcome));
    };

    assert_return(
        &case.manifest.scenario.name,
        &step.call,
        expected_return,
        outcome,
    )?;

    if expected_return.u64.is_some() {
        return outcome
            .return_u64
            .map(ObservableReturn::U64)
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "scenario `{}` target `{target_id}` call `{}` did not expose a u64 return",
                    case.manifest.scenario.name,
                    step.call
                )
            });
    }
    if expected_return.u32.is_some() {
        return outcome
            .return_u32
            .map(ObservableReturn::U32)
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "scenario `{}` target `{target_id}` call `{}` did not expose a u32 return",
                    case.manifest.scenario.name,
                    step.call
                )
            });
    }
    if expected_return.bool.is_some() {
        return outcome
            .return_bool
            .map(ObservableReturn::Bool)
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "scenario `{}` target `{target_id}` call `{}` did not expose a bool return",
                    case.manifest.scenario.name,
                    step.call
                )
            });
    }
    if expected_return.hex.is_some() {
        let hex = outcome
            .return_hex
            .as_deref()
            .map(normalize_hex)
            .unwrap_or_default();
        return Ok(ObservableReturn::Hex(hex));
    }

    Ok(inferred_observable_return(outcome))
}

fn inferred_observable_return(outcome: &CallOutcome) -> ObservableReturn {
    if let Some(value) = outcome.return_u64 {
        return ObservableReturn::U64(value);
    }
    if let Some(value) = outcome.return_u32 {
        return ObservableReturn::U32(value);
    }
    if let Some(value) = outcome.return_bool {
        return ObservableReturn::Bool(value);
    }
    if let Some(hex) = outcome
        .return_hex
        .as_deref()
        .map(normalize_hex)
        .filter(|hex| !hex.is_empty())
    {
        return ObservableReturn::Hex(hex);
    }
    ObservableReturn::None
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
                "return_hex" => {
                    let hex = normalize_hex(value);
                    if !hex.is_empty() {
                        outcome.return_hex = Some(hex);
                    }
                }
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

pub fn normalize_hex(value: &str) -> String {
    value
        .strip_prefix("0x")
        .unwrap_or(value)
        .to_ascii_lowercase()
}

pub fn decode_hex_bytes(value: &str) -> Result<Vec<u8>> {
    let normalized = normalize_hex(value);
    ensure!(
        normalized.len() % 2 == 0,
        "hex value must contain an even number of digits"
    );
    let mut out = Vec::with_capacity(normalized.len() / 2);
    for chunk in normalized.as_bytes().chunks_exact(2) {
        let byte = std::str::from_utf8(chunk).context("hex input was not valid UTF-8")?;
        out.push(
            u8::from_str_radix(byte, 16)
                .with_context(|| format!("invalid hex byte `{byte}` in value `{value}`"))?,
        );
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scenario(steps: Vec<Step>) -> ScenarioCase {
        ScenarioCase {
            path: PathBuf::from("counter.toml"),
            manifest: ScenarioManifest {
                scenario: Scenario {
                    name: "counter".to_string(),
                    fixture: "counter".to_string(),
                    targets: vec!["wasm-near".to_string(), "evm".to_string()],
                    capabilities: vec!["storage.scalar".to_string()],
                },
                steps,
                artifacts: Vec::new(),
                diagnostics: Vec::new(),
            },
        }
    }

    fn step(call: &str, expected_u64: Option<u64>) -> Step {
        Step {
            call: call.to_string(),
            repeat: None,
            input_hex: None,
            args: Vec::new(),
            expect: expected_u64.map(|value| Expectation {
                return_value: None,
                return_: Some(ReturnExpectation {
                    hex: None,
                    u64: Some(value),
                    u32: None,
                    bool: None,
                }),
            }),
        }
    }

    fn outcome(sequence: u32, call: &str, return_u64: Option<u64>) -> CallOutcome {
        CallOutcome {
            sequence,
            call: call.to_string(),
            return_hex: return_u64
                .map(|value| format!("{value:064x}"))
                .filter(|hex| !hex.is_empty()),
            return_u64,
            return_u32: return_u64.and_then(|value| u32::try_from(value).ok()),
            return_bool: return_u64.and_then(|value| match value {
                0 => Some(false),
                1 => Some(true),
                _ => None,
            }),
            raw_line: String::new(),
        }
    }

    #[test]
    fn artifact_expectations_support_structured_json_and_toml() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root =
            std::env::temp_dir().join(format!("proof-forge-testkit-structured-artifacts-{nonce}"));
        fs::create_dir_all(&root).unwrap();
        let json_path = root.join("artifact.json");
        let toml_path = root.join("manifest.toml");
        let source_path = root.join("source.wat");
        fs::write(&source_path, "(module)\n").unwrap();
        let source_sha256 = sha256_hex(&source_path).unwrap();
        fs::write(
            &json_path,
            format!(
                r#"{{"target":"solana-sbpf-asm","capabilities":["storage.scalar"],"validation":{{"manifestGeneration":"passed"}},"artifacts":{{"source":{{"path":{},"sha256":{},"bytes":{}}}}}}}"#,
                serde_json::to_string(source_path.to_str().unwrap()).unwrap(),
                serde_json::to_string(&source_sha256).unwrap(),
                fs::metadata(&source_path).unwrap().len()
            ),
        )
        .unwrap();
        fs::write(
            &toml_path,
            "target = \"solana-sbpf-asm\"\n\n[[instruction]]\nname = \"initialize\"\ntag = 0\n",
        )
        .unwrap();

        let mut case = scenario(vec![step("initialize", None)]);
        case.manifest.artifacts = vec![
            ArtifactExpectation {
                target: "solana-sbpf-asm".to_string(),
                name: "metadata".to_string(),
                matches_file: None,
                contains: Vec::new(),
                json_checks: vec![
                    StructuredArtifactCheck {
                        path: "target".to_string(),
                        equals: Some(TomlValue::String("solana-sbpf-asm".to_string())),
                        contains: None,
                    },
                    StructuredArtifactCheck {
                        path: "capabilities".to_string(),
                        equals: None,
                        contains: Some(TomlValue::String("storage.scalar".to_string())),
                    },
                    StructuredArtifactCheck {
                        path: "validation.manifestGeneration".to_string(),
                        equals: Some(TomlValue::String("passed".to_string())),
                        contains: None,
                    },
                ],
                file_checks: vec![FileArtifactCheck {
                    path: "artifacts.source".to_string(),
                    artifact: "source".to_string(),
                }],
                toml_checks: Vec::new(),
            },
            ArtifactExpectation {
                target: "solana-sbpf-asm".to_string(),
                name: "manifest".to_string(),
                matches_file: None,
                contains: Vec::new(),
                json_checks: Vec::new(),
                file_checks: Vec::new(),
                toml_checks: vec![
                    StructuredArtifactCheck {
                        path: "target".to_string(),
                        equals: Some(TomlValue::String("solana-sbpf-asm".to_string())),
                        contains: None,
                    },
                    StructuredArtifactCheck {
                        path: "instruction[0].name".to_string(),
                        equals: Some(TomlValue::String("initialize".to_string())),
                        contains: None,
                    },
                    StructuredArtifactCheck {
                        path: "instruction[0].tag".to_string(),
                        equals: Some(TomlValue::Integer(0)),
                        contains: None,
                    },
                ],
            },
        ];

        assert_artifact_expectations(
            &case,
            "solana-sbpf-asm",
            &root,
            &[
                ArtifactOutput {
                    name: "metadata",
                    path: &json_path,
                },
                ArtifactOutput {
                    name: "source",
                    path: &source_path,
                },
                ArtifactOutput {
                    name: "manifest",
                    path: &toml_path,
                },
            ],
        )
        .unwrap();

        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn discover_scenarios_rejects_artifact_target_outside_scenario_targets() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = std::env::temp_dir().join(format!(
            "proof-forge-testkit-artifact-target-validation-{nonce}"
        ));
        fs::create_dir_all(&root).unwrap();
        fs::write(
            root.join("bad.toml"),
            r#"[scenario]
name = "bad"
fixture = "counter"
targets = ["wasm-near"]

[[artifact]]
target = "rogue-target"
name = "wat"
contains = ["module"]

[[step]]
call = "initialize"
"#,
        )
        .unwrap();

        let err = discover_scenarios(&root).unwrap_err();

        assert!(err.to_string().contains("references target `rogue-target`"));
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn discover_scenarios_accepts_diagnostic_only_scenarios() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root =
            std::env::temp_dir().join(format!("proof-forge-testkit-diagnostic-only-{nonce}"));
        fs::create_dir_all(&root).unwrap();
        fs::write(
            root.join("diagnostic.toml"),
            r#"[scenario]
name = "unsupported-crosscall"
fixture = "unsupported-crosscall"
targets = ["solana-sbpf-asm"]

[[diagnostic]]
target = "solana-sbpf-asm"
name = "crosscall.invoke unsupported"
contains = ["target `solana-sbpf-asm` does not support capability `crosscall.invoke`"]
"#,
        )
        .unwrap();

        let scenarios = discover_scenarios(&root).unwrap();

        assert_eq!(scenarios.len(), 1);
        assert!(scenarios[0].manifest.steps.is_empty());
        assert_eq!(scenarios[0].manifest.diagnostics.len(), 1);
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn discover_scenarios_rejects_empty_diagnostic_checks() {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root =
            std::env::temp_dir().join(format!("proof-forge-testkit-empty-diagnostic-{nonce}"));
        fs::create_dir_all(&root).unwrap();
        fs::write(
            root.join("bad.toml"),
            r#"[scenario]
name = "bad"
fixture = "unsupported-crosscall"
targets = ["solana-sbpf-asm"]

[[diagnostic]]
target = "solana-sbpf-asm"
name = "crosscall.invoke unsupported"
"#,
        )
        .unwrap();

        let err = discover_scenarios(&root).unwrap_err();

        assert!(err.to_string().contains("has no contains checks"));
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn trace_equivalence_uses_expected_portable_return_type() {
        let case = scenario(vec![step("initialize", None), step("get", Some(1))]);
        let near = vec![
            CallOutcome {
                return_hex: None,
                ..outcome(1, "initialize", None)
            },
            CallOutcome {
                return_hex: None,
                ..outcome(2, "get", Some(1))
            },
        ];
        let evm = vec![outcome(1, "initialize", None), outcome(2, "get", Some(1))];

        assert_trace_equivalence(
            &case,
            &[
                TargetTrace {
                    target_id: "wasm-near",
                    outcomes: &near,
                },
                TargetTrace {
                    target_id: "evm",
                    outcomes: &evm,
                },
            ],
        )
        .unwrap();
    }

    #[test]
    fn trace_equivalence_rejects_observable_return_mismatch() {
        let case = scenario(vec![step("get", None)]);
        let baseline = vec![outcome(1, "get", Some(1))];
        let mismatch = vec![outcome(1, "get", Some(2))];

        let err = assert_trace_equivalence(
            &case,
            &[
                TargetTrace {
                    target_id: "wasm-near",
                    outcomes: &baseline,
                },
                TargetTrace {
                    target_id: "evm",
                    outcomes: &mismatch,
                },
            ],
        )
        .unwrap_err();

        assert!(err.to_string().contains("observable trace differs"));
    }

    #[test]
    fn offline_host_empty_return_hex_is_no_return() {
        let outcomes = parse_offline_host_outcomes("call 1:initialize: return_hex=\n").unwrap();

        assert_eq!(outcomes.len(), 1);
        assert_eq!(outcomes[0].return_hex, None);
    }
}

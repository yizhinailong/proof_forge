#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT}/build/aleo"
LEO_FILE="${BUILD_DIR}/Counter.leo"
GOLDEN_FILE="${ROOT}/Examples/Backend/Aleo/Counter.golden.leo"
PROJECT_DIR="${BUILD_DIR}/counter"
SOURCE_FILE="${PROJECT_DIR}/src/main.leo"
METADATA_FILE="${PROJECT_DIR}/proof-forge-artifact.json"
LEO_BIN="${LEO_BIN:-leo}"

info() {
    echo "[aleo-smoke] $*"
}

die() {
    echo "[aleo-smoke] ERROR: $*" >&2
    exit 1
}

info "building proof-forge"
cd "${ROOT}"
lake build proof-forge

info "generating Aleo Counter Leo source via ProofForge CLI"
mkdir -p "${BUILD_DIR}"
lake exe proof-forge emit --target aleo-leo --fixture counter --format leo -o "${LEO_FILE}"

if [ ! -s "${LEO_FILE}" ]; then
    die "generated Leo source is empty"
fi

info "diffing generated source against golden fixture"
diff -u "${GOLDEN_FILE}" "${LEO_FILE}"

if ! command -v "${LEO_BIN}" >/dev/null 2>&1; then
    echo "aleo-counter-smoke: leo not found. Install the Aleo CLI." >&2
    echo "aleo-counter-smoke: generated ${LEO_FILE} for inspection." >&2
    exit 127
fi

info "writing Leo package layout"
python3 "${ROOT}/scripts/aleo/write-leo-package.py" \
    --project-dir "${PROJECT_DIR}" \
    --source "${LEO_FILE}" \
    --program-name counter

info "running 'leo build'"
cd "${PROJECT_DIR}"
"${LEO_BIN}" build

info "running 'leo test'"
"${LEO_BIN}" test

info "writing artifact metadata"
python3 "${ROOT}/scripts/aleo/write-artifact-metadata.py" \
    --root "${ROOT}" \
    --fixture counter \
    --source "${SOURCE_FILE}" \
    --leo-project "${PROJECT_DIR}" \
    --out "${METADATA_FILE}" \
    --leo "${LEO_BIN}"

info "validating artifact metadata"
python3 "${ROOT}/scripts/aleo/validate-artifact-metadata.py" \
    --root "${ROOT}" \
    "${METADATA_FILE}"

info "Aleo counter smoke completed successfully"
echo ""
echo "Artifacts:"
ls -lh "${PROJECT_DIR}/build/"
echo ""
echo "Metadata: ${METADATA_FILE}"

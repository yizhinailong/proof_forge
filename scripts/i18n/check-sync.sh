#!/bin/sh
# Check whether Chinese translations are in sync with English docs.
# Exits non-zero if any translated doc is stale (English source changed
# since the last translation run).
#
# Usage: scripts/i18n/check-sync.sh
# Requires: python3, scripts/translate-docs.py
#
# This is a read-only check. It does not translate anything. Use it in CI
# or pre-commit to catch drift between English and Chinese docs.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 "$REPO_ROOT/scripts/translate-docs.py" --check

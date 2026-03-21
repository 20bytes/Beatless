#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$ROOT/scripts/rawcli/receipt_schema_gate.sh"
FIX="$ROOT/scripts/ci/fixtures"

pass_case() {
  local task_id="$1"
  local file="$2"
  "$GATE" "$task_id" "$file" >/dev/null
}

fail_case() {
  local task_id="$1"
  local file="$2"
  if "$GATE" "$task_id" "$file" >/dev/null 2>&1; then
    echo "expected failure but passed: task_id=$task_id file=$file" >&2
    exit 1
  fi
}

pass_case "CI-RECEIPT-OK-001" "$FIX/receipt-valid.md"
fail_case "CI-RECEIPT-BAD-DEBUG-001" "$FIX/receipt-invalid-debug.md"
fail_case "CI-RECEIPT-BAD-EVIDENCE-001" "$FIX/receipt-invalid-missing-evidence.md"

echo "[PASS] receipt schema gate fixtures"

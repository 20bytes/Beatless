#!/usr/bin/env bash
set -euo pipefail

# Validate receipt_schema_gate.sh behavior against generated fixtures.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${RECEIPT_GATE_PATH:-$ROOT/scripts/rawcli/receipt_schema_gate.sh}"
errors=0

echo "=== Receipt Contract Validation ==="
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/valid.md" <<'F'
task_id: CI-TEST-VALID-001
VERDICT: PASS
summary: test passes all gates
evidence_path: Report/test.md
DONE:
F

cat > "$TMPDIR/bad-debug.md" <<'F'
task_id: CI-TEST-DEBUG-001
VERDICT: PASS
summary: 我需要先执行这个任务
evidence_path: Report/test.md
DONE:
F

cat > "$TMPDIR/bad-trace.md" <<'F'
task_id: CI-TEST-TRACE-001
VERDICT: FAIL
summary: error occurred
evidence_path: Report/test.md
DONE:
Traceback (most recent call last)
F

cat > "$TMPDIR/bad-path.md" <<'F'
task_id: CI-TEST-PATH-001
VERDICT: PASS
summary: done
evidence_path: /home/yarizakurahime/.openclaw/beatless/dispatch-results/test.json
DONE:
F

cat > "$TMPDIR/bad-verdict.md" <<'F'
task_id: CI-TEST-VERDICT-001
summary: no verdict
evidence_path: Report/test.md
DONE:
F

cat > "$TMPDIR/bad-fence.md" <<'F'
task_id: CI-TEST-FENCE-001
VERDICT: PASS
summary: has code
evidence_path: Report/test.md
```python
print("hello")
```
DONE:
F

cat > "$TMPDIR/bad-crossrun.md" <<'F'
task_id: RUN-A-001
VERDICT: PASS
summary: refs other run
evidence_path: Report/test.md
DONE:
task_id: OTHER-RUN-999
F

run_test() {
  local name="$1" file="$2" task_id="$3" expect_pass="$4" run_id="${5:-}"
  local args=("$task_id" "$file")
  [[ -n "$run_id" ]] && args+=("$run_id")
  if bash "$GATE" "${args[@]}" >/dev/null 2>&1; then
    if [[ "$expect_pass" == "true" ]]; then
      echo "PASS: $name"
    else
      echo "FAIL: $name should reject"
      errors=$((errors+1))
    fi
  else
    if [[ "$expect_pass" == "false" ]]; then
      echo "PASS: $name"
    else
      echo "FAIL: $name should pass"
      errors=$((errors+1))
    fi
  fi
}

run_test "valid_receipt"       "$TMPDIR/valid.md"       "CI-TEST-VALID-001"   "true"
run_test "debug_text_blocked"  "$TMPDIR/bad-debug.md"   "CI-TEST-DEBUG-001"   "false"
run_test "traceback_blocked"   "$TMPDIR/bad-trace.md"   "CI-TEST-TRACE-001"   "false"
run_test "internal_path_block" "$TMPDIR/bad-path.md"    "CI-TEST-PATH-001"    "false"
run_test "missing_verdict"     "$TMPDIR/bad-verdict.md" "CI-TEST-VERDICT-001" "false"
run_test "code_fence_blocked"  "$TMPDIR/bad-fence.md"   "CI-TEST-FENCE-001"   "false"
run_test "cross_run_blocked"   "$TMPDIR/bad-crossrun.md" "RUN-A-001"          "false" "RUN-A"

echo "=== Done: $errors error(s) ==="
exit "$errors"

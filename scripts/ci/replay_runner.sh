#!/usr/bin/env bash
set -euo pipefail

# replay_runner.sh — replay JSONL fixture against live dispatch + receipt gate.
# Usage: replay_runner.sh <fixture.jsonl>

BEATLESS="${HOME}/.openclaw/beatless"
SCRIPTS="$BEATLESS/scripts"
RESULTS="$BEATLESS/dispatch-results"
FIXTURE="${1:?Usage: replay_runner.sh <fixture.jsonl>}"

errors=0

while IFS= read -r line; do
  [[ -z "$line" || "$line" == "#"* ]] && continue
  action=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['action'])")
  case "$action" in
    submit)
      task_id=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['task_id'])")
      owner=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['owner_agent'])")
      tool=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['executor_tool'])")
      prompt=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['prompt'])")
      phase=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('phase',''))")
      echo "REPLAY submit: $task_id -> $tool"
      bash "$SCRIPTS/dispatch_submit.sh" "$task_id" "$owner" "$tool" "$prompt" "" "" "" "" "" "$phase" || true
      ;;
    expect_result)
      task_id=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['task_id'])")
      expect=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['expect_status'])")
      for _ in $(seq 1 24); do
        if [[ -f "$RESULTS/$task_id.json" ]]; then
          status=$(python3 -c "import json; print(json.load(open('$RESULTS/$task_id.json')).get('status','missing'))" 2>/dev/null || echo missing)
          [[ "$status" != "running" ]] && break
        fi
        sleep 5
      done
      actual=$(python3 -c "import json; print(json.load(open('$RESULTS/$task_id.json')).get('status','missing'))" 2>/dev/null || echo missing)
      if [[ "$actual" == "$expect" ]]; then
        echo "PASS: $task_id status=$actual"
      else
        echo "FAIL: $task_id expected=$expect actual=$actual"
        errors=$((errors+1))
      fi
      ;;
    submit_receipt)
      :
      ;;
    expect_gate)
      task_id=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['task_id'])")
      expect_pass=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('expect_pass', True)).lower())")
      receipt=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('receipt_file',''))")
      if bash "$SCRIPTS/receipt_schema_gate.sh" "$task_id" "$receipt" >/dev/null 2>&1; then
        if [[ "$expect_pass" == "true" ]]; then
          echo "PASS: gate $task_id"
        else
          echo "FAIL: gate $task_id should reject"
          errors=$((errors+1))
        fi
      else
        if [[ "$expect_pass" == "false" ]]; then
          echo "PASS: gate $task_id rejected"
        else
          echo "FAIL: gate $task_id should pass"
          errors=$((errors+1))
        fi
      fi
      ;;
  esac
done < "$FIXTURE"

echo "=== Replay done: $errors error(s) ==="
exit "$errors"

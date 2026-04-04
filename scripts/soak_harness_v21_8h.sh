#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DURATION_SECONDS="${SOAK_DURATION_SECONDS:-28800}"    # default 8h
INTERVAL_SECONDS="${SOAK_INTERVAL_SECONDS:-300}"      # default 5min
MAX_FAILURES="${SOAK_MAX_FAILURES:-3}"

START_TS="$(date +%s)"
END_TS="$((START_TS + DURATION_SECONDS))"
RUN_ID="soak-$(date +%Y%m%d-%H%M%S)"
SOAK_DIR="$ROOT/runtime/soak"
LOG_DIR="$SOAK_DIR/logs/$RUN_ID"
JSONL="$SOAK_DIR/${RUN_ID}.jsonl"
SUMMARY="$SOAK_DIR/${RUN_ID}-summary.md"

mkdir -p "$LOG_DIR" "$SOAK_DIR"

cleanup_experiment_artifacts() {
  find "$ROOT/runtime/jobs" -maxdepth 1 -mindepth 1 -type d \
    \( -name 'smoke-*' -o -name 'closedloop-*' -o -name 'expnm-*' \) -exec rm -rf {} + || true
  find "$ROOT/runtime/state" -maxdepth 1 -type f -name 'experiment_nonmock_*' -delete || true
  rm -f "$ROOT/runtime/scheduler/.scheduler.lock" || true
}

append_jsonl() {
  local cycle="$1"
  local phase="$2"
  local rc="$3"
  local msg="$4"
  python3 - <<PY >> "$JSONL"
import json, time
print(json.dumps({
  "ts": int(time.time()),
  "cycle": int($cycle),
  "phase": "$phase",
  "rc": int($rc),
  "message": "$msg"
}, ensure_ascii=False))
PY
}

run_with_retry_lock() {
  local out_file="$1"
  local cmd="$2"
  local attempts=0
  while true; do
    attempts=$((attempts+1))
    set +e
    bash -lc "$cmd" >"$out_file" 2>&1
    local rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      echo "$rc"
      return 0
    fi
    if grep -q "scheduler lock busy" "$out_file"; then
      if [[ $attempts -ge 30 ]]; then
        echo "$rc"
        return 0
      fi
      sleep 1
      continue
    fi
    echo "$rc"
    return 0
  done
}

# Preflight
python3 scripts/init_task_os.py >/dev/null
python3 scripts/validate_baseline.py >/dev/null
bash scripts/smoke_trigger_v21.sh >/dev/null

success=0
failure=0
cycle=0

append_jsonl 0 "start" 0 "run_id=$RUN_ID duration=$DURATION_SECONDS interval=$INTERVAL_SECONDS max_failures=$MAX_FAILURES"

echo "[soak] run_id=$RUN_ID"
echo "[soak] jsonl=$JSONL"
echo "[soak] summary=$SUMMARY"

while [[ "$(date +%s)" -lt "$END_TS" ]]; do
  cycle=$((cycle+1))
  cycle_log="$LOG_DIR/cycle-${cycle}.log"

  rc=$(run_with_retry_lock "$cycle_log" "cd '$ROOT' && bash scripts/experiment_harness_nonmock_v21.sh")

  if [[ "$rc" -eq 0 ]]; then
    success=$((success+1))
    append_jsonl "$cycle" "experiment" 0 "ok"
  else
    failure=$((failure+1))
    append_jsonl "$cycle" "experiment" "$rc" "failed"
  fi

  drain_log="$LOG_DIR/cycle-${cycle}-drain.log"
  rc2=$(run_with_retry_lock "$drain_log" "cd '$ROOT' && ORCHESTRATION_MODE=harness python3 scripts/task_os_scheduler.py --drain")
  append_jsonl "$cycle" "drain" "$rc2" "post-cycle drain"

  cleanup_experiment_artifacts

  if [[ "$failure" -ge "$MAX_FAILURES" ]]; then
    append_jsonl "$cycle" "abort" 1 "max failures reached"
    break
  fi

  now="$(date +%s)"
  if [[ "$now" -ge "$END_TS" ]]; then
    break
  fi
  sleep "$INTERVAL_SECONDS"
done

# Final snapshot
ORCHESTRATION_MODE=harness python3 scripts/task_os_scheduler.py --drain > "$LOG_DIR/final-drain.log" 2>&1 || true
rm -f "$ROOT/runtime/scheduler/.scheduler.lock" || true

cat > "$SUMMARY" <<EOF
# Harness Soak Summary

- run_id: $RUN_ID
- started_at_unix: $START_TS
- ended_at_unix: $(date +%s)
- duration_seconds_target: $DURATION_SECONDS
- interval_seconds: $INTERVAL_SECONDS
- cycles_total: $cycle
- success_cycles: $success
- failure_cycles: $failure
- jsonl: $JSONL
- logs_dir: $LOG_DIR
EOF

if [[ "$failure" -ge "$MAX_FAILURES" ]]; then
  echo "[soak] FAIL (failure=$failure >= max=$MAX_FAILURES)"
  exit 1
fi

echo "[soak] PASS (success=$success failure=$failure cycles=$cycle)"

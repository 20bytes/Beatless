#!/usr/bin/env bash
set -euo pipefail

# mode_switch_gate.sh — Evaluate and set runtime execution mode.
# Called by rawcli_supervisor.sh every cycle (~20s).
# Reads metrics JSON, writes /tmp/beatless_exec_mode.

BEATLESS="${HOME}/.openclaw/beatless"
MODE_FILE="/tmp/beatless_exec_mode"
METRICS_JSON="$BEATLESS/metrics/rawcli-metrics-latest.json"
MODE_EVENTS="$BEATLESS/metrics/mode-switch-events.jsonl"
LOG="$BEATLESS/logs/mode-switch.log"

# Degrade triggers (ANY)
DEGRADE_FAIL_RATE="0.40"
DEGRADE_QUEUE_DEPTH=15
DEGRADE_CONSEC_FAILURES=3
DEGRADE_RECEIPT_PASS="0.95"

# Stressed triggers (intermediate)
STRESSED_FAIL_RATE="0.20"
STRESSED_QUEUE_DEPTH=10

# Restore triggers (ALL, held for N cycles)
RESTORE_FAIL_RATE="0.10"
RESTORE_QUEUE_DEPTH=8
RESTORE_RECEIPT_PASS="1.00"
RESTORE_HOLD_CYCLES=6
HOLD_FILE="$BEATLESS/metrics/mode-restore-hold-count.txt"

mkdir -p "$BEATLESS/logs" "$BEATLESS/metrics"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

cmp_float_gt() {
  python3 - "$1" "$2" <<'PY'
import sys
print('1' if float(sys.argv[1]) > float(sys.argv[2]) else '0')
PY
}

cmp_float_lt() {
  python3 - "$1" "$2" <<'PY'
import sys
print('1' if float(sys.argv[1]) < float(sys.argv[2]) else '0')
PY
}

current_mode=$(cat "$MODE_FILE" 2>/dev/null || echo "daily")

metrics_json=$(python3 - "$METRICS_JSON" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
out = {"fail_rate": 0.0, "queue_depth": 0, "consec_fail": 0, "receipt_pass": 1.0}
if p.exists():
    try:
        d = json.loads(p.read_text(encoding='utf-8'))
        out["fail_rate"] = float((d.get("window") or {}).get("fail_rate", 0.0) or 0.0)
        out["queue_depth"] = int(d.get("queue_depth", 0) or 0)
        out["consec_fail"] = int((d.get("window") or {}).get("consecutive_failures", 0) or 0)
        out["receipt_pass"] = float(d.get("receipt_pass_rate", 1.0) or 1.0)
    except Exception:
        pass
print(json.dumps(out))
PY
)

fail_rate=$(echo "$metrics_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['fail_rate'])")
queue_depth=$(echo "$metrics_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['queue_depth'])")
consec_fail=$(echo "$metrics_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['consec_fail'])")
receipt_pass=$(echo "$metrics_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['receipt_pass'])")

new_mode="$current_mode"

if [[ "$(cmp_float_gt "$fail_rate" "$DEGRADE_FAIL_RATE")" == "1" ]] || \
   [[ "$queue_depth" -gt "$DEGRADE_QUEUE_DEPTH" ]] || \
   [[ "$consec_fail" -ge "$DEGRADE_CONSEC_FAILURES" ]] || \
   [[ "$(cmp_float_lt "$receipt_pass" "$DEGRADE_RECEIPT_PASS")" == "1" ]]; then
  new_mode="degraded"
elif [[ "$(cmp_float_gt "$fail_rate" "$STRESSED_FAIL_RATE")" == "1" ]] || \
     [[ "$queue_depth" -gt "$STRESSED_QUEUE_DEPTH" ]]; then
  if [[ "$current_mode" == "daily" || "$current_mode" == "intense" || "$current_mode" == "stressed" ]]; then
    new_mode="stressed"
  fi
elif [[ "$current_mode" == "degraded" || "$current_mode" == "stressed" ]]; then
  if [[ "$(cmp_float_lt "$fail_rate" "$RESTORE_FAIL_RATE")" == "1" ]] && \
     [[ "$queue_depth" -le "$RESTORE_QUEUE_DEPTH" ]] && \
     [[ "$consec_fail" -eq 0 ]] && \
     [[ "$(cmp_float_lt "$receipt_pass" "$RESTORE_RECEIPT_PASS")" == "0" ]]; then
    hold_count=$(cat "$HOLD_FILE" 2>/dev/null || echo 0)
    hold_count=$((hold_count + 1))
    echo "$hold_count" > "$HOLD_FILE"
    if [[ "$hold_count" -ge "$RESTORE_HOLD_CYCLES" ]]; then
      new_mode="daily"
      echo 0 > "$HOLD_FILE"
    fi
  else
    echo 0 > "$HOLD_FILE"
  fi
fi

if [[ "$new_mode" != "$current_mode" ]]; then
  echo "$new_mode" > "$MODE_FILE"
  log "MODE_SWITCH: $current_mode -> $new_mode (fr=$fail_rate qd=$queue_depth cf=$consec_fail rp=$receipt_pass)"
  printf '{"ts":"%s","from":"%s","to":"%s","fail_rate":%s,"queue_depth":%s,"consec_fail":%s,"receipt_pass":%s}\n' \
    "$(date -Iseconds)" "$current_mode" "$new_mode" "$fail_rate" "$queue_depth" "$consec_fail" "$receipt_pass" >> "$MODE_EVENTS"
fi

case "$new_mode" in
  degraded) max_p=1 ;;
  stressed) max_p=2 ;;
  *) max_p=4 ;;
esac

echo "mode=$new_mode max_parallel=$max_p fr=$fail_rate qd=$queue_depth cf=$consec_fail rp=$receipt_pass"

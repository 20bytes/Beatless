#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-beatless-v2}"
BEATLESS="${HOME}/.openclaw/beatless"
OPENCLAW_HOME="${HOME}/.openclaw"
REPORT_DIR="/home/yarizakurahime/claw/Report"
REPORT_FILE="$REPORT_DIR/beatless-system-check-latest.md"
LAST_CHAT_ID_FILE="$BEATLESS/metrics/last-feishu-chat-id.txt"
EVENT_SIGNALS_FILE="$BEATLESS/metrics/event-signals.jsonl"
METRICS_FILE="$BEATLESS/metrics/rawcli-metrics-latest.json"

mkdir -p "$REPORT_DIR"

pass=0
warn=0
fail=0
rows=()

add_row() {
  local status="$1"
  local item="$2"
  local detail="$3"
  rows+=("$status|$item|$detail")
  case "$status" in
    PASS) pass=$((pass + 1)) ;;
    WARN) warn=$((warn + 1)) ;;
    FAIL) fail=$((fail + 1)) ;;
  esac
}

if [[ -f "$BEATLESS/MEMORY.md" ]]; then
  add_row "PASS" "memory.global" "found: $BEATLESS/MEMORY.md"
else
  add_row "FAIL" "memory.global" "missing: $BEATLESS/MEMORY.md"
fi

workspace_count=0
workspace_memory_count=0
while IFS= read -r ws; do
  [[ -d "$ws" ]] || continue
  workspace_count=$((workspace_count + 1))
  if [[ -f "$ws/MEMORY.md" ]]; then
    workspace_memory_count=$((workspace_memory_count + 1))
  fi
done < <(find "$OPENCLAW_HOME" -mindepth 1 -maxdepth 1 -type d -name 'workspace-*' | sort)
if [[ "$workspace_memory_count" -gt 0 ]]; then
  add_row "PASS" "memory.workspace" "workspace_MEMORY=$workspace_memory_count/$workspace_count"
else
  add_row "WARN" "memory.workspace" "workspace_MEMORY=0/$workspace_count (current design uses global MEMORY + workspace USER)"
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  windows="$(tmux list-windows -t "$SESSION" -F '#W' | tr '\n' ' ')"
  missing=()
  for w in control gateway dispatch hooks monitor; do
    if ! tmux list-windows -t "$SESSION" -F '#W' | rg -q "^${w}$"; then
      missing+=("$w")
    fi
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    add_row "PASS" "tmux.session" "session=$SESSION windows=control,gateway,dispatch,hooks,monitor"
  else
    add_row "FAIL" "tmux.session" "session=$SESSION missing_windows=${missing[*]} current=[$windows]"
  fi
else
  add_row "FAIL" "tmux.session" "session_missing=$SESSION"
fi

for cli in codex claude gemini; do
  if command -v "$cli" >/dev/null 2>&1; then
    add_row "PASS" "rawcli.$cli" "path=$(command -v "$cli")"
  else
    add_row "FAIL" "rawcli.$cli" "command_not_found"
  fi
done

if [[ -f "$LAST_CHAT_ID_FILE" ]]; then
  last_chat_id="$(tr -d '\r\n' < "$LAST_CHAT_ID_FILE" 2>/dev/null || true)"
  if [[ -n "$last_chat_id" ]]; then
    add_row "PASS" "heartbeat.chat_id" "cached_chat_id=$last_chat_id"
  else
    add_row "WARN" "heartbeat.chat_id" "file_exists_but_empty=$LAST_CHAT_ID_FILE"
  fi
else
  add_row "WARN" "heartbeat.chat_id" "missing_cache_file=$LAST_CHAT_ID_FILE"
fi

if [[ -f "$EVENT_SIGNALS_FILE" ]]; then
  hb_info="$(python3 - "$EVENT_SIGNALS_FILE" <<'PY'
import datetime as dt
import json
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
now = dt.datetime.now(dt.timezone.utc)
cutoff = now - dt.timedelta(hours=24)

hb_total = 0
hb_sent = 0
latest = None

for raw in p.read_text(encoding='utf-8', errors='ignore').splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except Exception:
        continue
    if str(obj.get('event_type', '')) != 'heartbeat_status':
        continue
    ts_raw = str(obj.get('ts', '')).strip()
    try:
        ts = dt.datetime.fromisoformat(ts_raw)
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=dt.timezone.utc)
        ts_utc = ts.astimezone(dt.timezone.utc)
    except Exception:
        ts_utc = None
    if ts_utc and ts_utc >= cutoff:
        hb_total += 1
        if bool(obj.get('sent', False)):
            hb_sent += 1
    latest = obj

latest_ts = '' if latest is None else str(latest.get('ts', ''))
latest_sent = '' if latest is None else str(bool(latest.get('sent', False))).lower()
latest_target = '' if latest is None else str(latest.get('target_chat_id', '') or '')

print(f"hb_total_24h={hb_total}")
print(f"hb_sent_24h={hb_sent}")
print(f"hb_latest_ts={latest_ts}")
print(f"hb_latest_sent={latest_sent}")
print(f"hb_latest_target={latest_target}")
PY
)"
  hb_total_24h="$(printf '%s\n' "$hb_info" | awk -F= '/^hb_total_24h=/{print $2}')"
  hb_sent_24h="$(printf '%s\n' "$hb_info" | awk -F= '/^hb_sent_24h=/{print $2}')"
  hb_latest_ts="$(printf '%s\n' "$hb_info" | awk -F= '/^hb_latest_ts=/{print $2}')"
  hb_latest_sent="$(printf '%s\n' "$hb_info" | awk -F= '/^hb_latest_sent=/{print $2}')"
  hb_latest_target="$(printf '%s\n' "$hb_info" | awk -F= '/^hb_latest_target=/{print $2}')"

  if [[ "${hb_total_24h:-0}" -eq 0 ]]; then
    add_row "FAIL" "heartbeat.events" "no_heartbeat_in_last_24h"
  elif [[ "${hb_sent_24h:-0}" -eq 0 ]]; then
    add_row "WARN" "heartbeat.events" "heartbeat_seen=$hb_total_24h sent=0 latest_ts=$hb_latest_ts latest_target=$hb_latest_target"
  else
    add_row "PASS" "heartbeat.events" "heartbeat_seen=$hb_total_24h sent=$hb_sent_24h latest_sent=$hb_latest_sent latest_ts=$hb_latest_ts"
  fi
else
  add_row "FAIL" "heartbeat.events" "missing_file=$EVENT_SIGNALS_FILE"
fi

if [[ -f "$METRICS_FILE" ]]; then
  metrics_brief="$(python3 - "$METRICS_FILE" <<'PY'
import json
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
try:
    d = json.loads(p.read_text(encoding='utf-8'))
except Exception:
    d = {}
ack_p95 = float(d.get('ack_latency_ms_p95', 0.0) or 0.0)
fail_rate = float(d.get('fail_rate_last_50', 0.0) or 0.0)
queue_depth = int(d.get('queue_depth', 0) or 0)
print(f"ack_p95={ack_p95:.1f}")
print(f"fail_rate={fail_rate:.3f}")
print(f"queue_depth={queue_depth}")
PY
)"
  add_row "PASS" "metrics.snapshot" "$(printf '%s' "$metrics_brief" | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
else
  add_row "WARN" "metrics.snapshot" "missing_file=$METRICS_FILE"
fi

{
  echo "# Beatless System Check"
  echo
  echo "- generated_at: $(date -Iseconds)"
  echo "- session: $SESSION"
  echo "- summary: PASS=$pass WARN=$warn FAIL=$fail"
  echo
  echo "## Results"
  for row in "${rows[@]}"; do
    status="${row%%|*}"
    rest="${row#*|}"
    item="${rest%%|*}"
    detail="${rest#*|}"
    echo "- [$status] $item :: $detail"
  done
  echo
  echo "## Verdict"
  if [[ "$fail" -gt 0 ]]; then
    echo "- status: FAIL"
  elif [[ "$warn" -gt 0 ]]; then
    echo "- status: PARTIAL"
  else
    echo "- status: PASS"
  fi
} > "$REPORT_FILE"

echo "$REPORT_FILE"

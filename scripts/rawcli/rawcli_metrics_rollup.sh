#!/usr/bin/env bash
set -euo pipefail

BEATLESS="${HOME}/.openclaw/beatless"
QUEUE="$BEATLESS/dispatch-queue.jsonl"
RESULTS_DIR="$BEATLESS/dispatch-results"
EVENTS_FILE="$BEATLESS/metrics/dispatch-events.jsonl"
GATE_EVENTS_FILE="$BEATLESS/metrics/receipt-gate-events.jsonl"
METRICS_DIR="$BEATLESS/metrics"
REPORT_DIR="/home/yarizakurahime/claw/Report"
OUT_JSON="$METRICS_DIR/rawcli-metrics-latest.json"
OUT_PROM="$METRICS_DIR/rawcli.prom"
OUT_MD="$REPORT_DIR/rawcli-metrics-latest.md"
WINDOW_MINUTES="${1:-15}"

mkdir -p "$METRICS_DIR" "$REPORT_DIR" "$RESULTS_DIR"
touch "$QUEUE"

python3 - "$QUEUE" "$RESULTS_DIR" "$EVENTS_FILE" "$GATE_EVENTS_FILE" "$OUT_JSON" "$OUT_PROM" "$WINDOW_MINUTES" <<'PY'
import json
import pathlib
import sys
from collections import Counter
from datetime import datetime, timezone

queue_path = pathlib.Path(sys.argv[1])
results_dir = pathlib.Path(sys.argv[2])
events_path = pathlib.Path(sys.argv[3])
gate_events_path = pathlib.Path(sys.argv[4])
out_json = pathlib.Path(sys.argv[5])
out_prom = pathlib.Path(sys.argv[6])
window_minutes = max(int(sys.argv[7]), 1)


def parse_iso_ts(value: str | None) -> float | None:
    if not value:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(text).timestamp()
    except Exception:
        return None


now = datetime.now(timezone.utc)
cutoff = now.timestamp() - window_minutes * 60

queue_depth = 0
if queue_path.exists():
    for raw in queue_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            queue_depth += 1

events = []
all_events = []
status_window = Counter()
status_total = Counter()
failure_total = Counter()
failure_window = Counter()

if events_path.exists():
    for raw in events_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        all_events.append(obj)
        status = str(obj.get("status", "unknown"))
        status_total[status] += 1
        ftype = obj.get("failure_type")
        if ftype:
            failure_total[str(ftype)] += 1
        ts = parse_iso_ts(obj.get("ts"))
        if ts is None:
            continue
        if ts >= cutoff:
            events.append(obj)
            status_window[status] += 1
            if ftype:
                failure_window[str(ftype)] += 1

# Consecutive failure streak (from newest events, regardless of window)
consecutive_failures = 0
for ev in reversed(all_events):
    status = str(ev.get("status", "unknown"))
    if status in {"failed", "timeout"}:
        consecutive_failures += 1
        continue
    break

result_status = Counter()
running_count = 0
for file in sorted(results_dir.glob("*.json")):
    try:
        data = json.loads(file.read_text(encoding="utf-8"))
    except Exception:
        continue
    status = str(data.get("status", "unknown"))
    result_status[status] += 1
    if status == "running":
        running_count += 1

window_success = status_window.get("success", 0)
window_failed = status_window.get("failed", 0)
window_timeout = status_window.get("timeout", 0)
window_done = window_success + window_failed + window_timeout
window_fail_rate = (window_failed + window_timeout) / window_done if window_done > 0 else 0.0

# Receipt pass rate (last 15 gate events)
receipt_pass_rate = 1.0
if gate_events_path.exists():
    recent = [ln for ln in gate_events_path.read_text(encoding="utf-8", errors="ignore").splitlines() if ln.strip()]
    recent = recent[-15:]
    if recent:
        pass_count = 0
        for ln in recent:
            try:
                obj = json.loads(ln)
            except Exception:
                continue
            if str(obj.get("status", "")) == "pass":
                pass_count += 1
        receipt_pass_rate = pass_count / len(recent)

# Queue saturation
max_backlog = 12
tasks_path = queue_path.parent / "TASKS.yaml"
if tasks_path.exists():
    for raw in tasks_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if line.startswith("max_backlog:"):
            val = line.split(":", 1)[1].strip()
            if val.isdigit():
                max_backlog = int(val)
            break
queue_saturation_pct = (queue_depth / max_backlog * 100.0) if max_backlog > 0 else 0.0

# Current mode
mode_path = pathlib.Path("/tmp/beatless_exec_mode")
current_mode = mode_path.read_text(encoding="utf-8", errors="ignore").strip() if mode_path.exists() else "daily"
if not current_mode:
    current_mode = "daily"

# Anthropic daily usage from dispatch events
today = now.date().isoformat()
opus_today = 0
sonnet_today = 0
for ev in all_events:
    ts_val = str(ev.get("ts", ""))
    tool = str(ev.get("tool", ""))
    if not ts_val.startswith(today):
        continue
    if tool in {"claude_architect_opus_cli", "claude_opus_cli"}:
        opus_today += 1
    elif tool in {"claude_architect_sonnet_cli", "claude_sonnet_cli"}:
        sonnet_today += 1

# Placeholder for future per-task token counting integration
context_tokens_per_task = 0

payload = {
    "generated_at": now.isoformat(),
    "window_minutes": window_minutes,
    "queue_depth": queue_depth,
    "running_count": running_count,
    "window": {
        "events_total": int(sum(status_window.values())),
        "status": dict(status_window),
        "failure_type": dict(failure_window),
        "success_count": int(window_success),
        "failed_count": int(window_failed),
        "timeout_count": int(window_timeout),
        "fail_rate": window_fail_rate,
        "consecutive_failures": consecutive_failures,
    },
    "receipt_pass_rate": receipt_pass_rate,
    "queue_saturation_pct": queue_saturation_pct,
    "mode": current_mode,
    "context_tokens_per_task": context_tokens_per_task,
    "anthropic_calls_today": {
        "opus": opus_today,
        "sonnet": sonnet_today,
        "opus_limit": 3,
        "sonnet_limit": 6,
    },
    "total": {
        "events_by_status": dict(status_total),
        "failures_by_type": dict(failure_total),
        "results_by_status": dict(result_status),
    },
}
out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

prom_lines = [
    "# HELP rawcli_queue_depth Number of queued dispatch requests.",
    "# TYPE rawcli_queue_depth gauge",
    f"rawcli_queue_depth {queue_depth}",
    "# HELP rawcli_running_results Number of running dispatch result entries.",
    "# TYPE rawcli_running_results gauge",
    f"rawcli_running_results {running_count}",
    "# HELP rawcli_window_events_total Dispatch events in rolling window by status.",
    "# TYPE rawcli_window_events_total gauge",
]
for key in sorted(status_window):
    prom_lines.append(f'rawcli_window_events_total{{status="{key}"}} {status_window[key]}')
prom_lines += [
    "# HELP rawcli_window_fail_rate Failure+timeout ratio in rolling window.",
    "# TYPE rawcli_window_fail_rate gauge",
    f"rawcli_window_fail_rate {window_fail_rate:.6f}",
    "# HELP rawcli_receipt_pass_rate Receipt schema gate pass rate (recent window).",
    "# TYPE rawcli_receipt_pass_rate gauge",
    f"rawcli_receipt_pass_rate {receipt_pass_rate:.6f}",
    "# HELP rawcli_queue_saturation_pct Queue saturation percentage against max_backlog.",
    "# TYPE rawcli_queue_saturation_pct gauge",
    f"rawcli_queue_saturation_pct {queue_saturation_pct:.1f}",
    "# HELP rawcli_anthropic_calls_today Anthropic tool calls today.",
    "# TYPE rawcli_anthropic_calls_today gauge",
    f'rawcli_anthropic_calls_today{{model="opus"}} {opus_today}',
    f'rawcli_anthropic_calls_today{{model="sonnet"}} {sonnet_today}',
    "# HELP rawcli_context_tokens_per_task Estimated context tokens per task.",
    "# TYPE rawcli_context_tokens_per_task gauge",
    f"rawcli_context_tokens_per_task {context_tokens_per_task}",
    "# HELP rawcli_window_failure_type_total Dispatch failures in rolling window by failure_type.",
    "# TYPE rawcli_window_failure_type_total gauge",
]
for key in sorted(failure_window):
    prom_lines.append(f'rawcli_window_failure_type_total{{failure_type="{key}"}} {failure_window[key]}')
prom_lines += [
    "# HELP rawcli_results_total Result files by current status.",
    "# TYPE rawcli_results_total gauge",
]
for key in sorted(result_status):
    prom_lines.append(f'rawcli_results_total{{status="{key}"}} {result_status[key]}')
out_prom.write_text("\n".join(prom_lines) + "\n", encoding="utf-8")
PY

python3 - "$OUT_JSON" "$OUT_MD" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
d = json.loads(src.read_text(encoding='utf-8'))
window = d['window']
out.write_text(
    "\n".join([
        "# RawCli Metrics",
        "",
        f"- generated_at: {d['generated_at']}",
        f"- window_minutes: {d['window_minutes']}",
        f"- queue_depth: {d['queue_depth']}",
        f"- running_count: {d['running_count']}",
        f"- window_events_total: {window['events_total']}",
        f"- window_fail_rate: {window['fail_rate']:.3f}",
        f"- window_consecutive_failures: {window.get('consecutive_failures', 0)}",
        f"- receipt_pass_rate: {d.get('receipt_pass_rate', 1.0):.3f}",
        f"- queue_saturation_pct: {d.get('queue_saturation_pct', 0.0):.1f}",
        f"- mode: {d.get('mode', 'daily')}",
        f"- anthropic_calls_today.opus: {((d.get('anthropic_calls_today') or {}).get('opus', 0))}",
        f"- anthropic_calls_today.sonnet: {((d.get('anthropic_calls_today') or {}).get('sonnet', 0))}",
        f"- context_tokens_per_task: {d.get('context_tokens_per_task', 0)}",
        "",
        "## Window Status",
        *(f"- {k}: {v}" for k, v in sorted(window['status'].items())),
        "",
        "## Window Failure Types",
        *(f"- {k}: {v}" for k, v in sorted(window['failure_type'].items())),
    ]) + "\n",
    encoding='utf-8'
)
PY

printf '%s\n' "$OUT_JSON"

#!/usr/bin/env bash
set -euo pipefail

# postmortem_template.sh — generate postmortem report from events.
# Usage: postmortem_template.sh [RUN_ID]

BEATLESS="${HOME}/.openclaw/beatless"
EVENTS="$BEATLESS/metrics/dispatch-events.jsonl"
MODE_EVENTS="$BEATLESS/metrics/mode-switch-events.jsonl"
REPORT_DIR="/home/yarizakurahime/claw/Report/postmortems"
RUN_ID="${1:-SHIFT-$(date +%Y%m%d)}"
OUT="$REPORT_DIR/${RUN_ID}-postmortem.md"

mkdir -p "$REPORT_DIR"

python3 - "$EVENTS" "$MODE_EVENTS" "$RUN_ID" "$OUT" <<'PY'
import json, sys
from pathlib import Path
from collections import Counter
from datetime import datetime

events_path = Path(sys.argv[1])
mode_path = Path(sys.argv[2])
run_id = sys.argv[3]
out_path = Path(sys.argv[4])

events = []
if events_path.exists():
    for line in events_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        try:
            events.append(json.loads(line))
        except Exception:
            pass

mode_events = []
if mode_path.exists():
    for line in mode_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        try:
            mode_events.append(json.loads(line))
        except Exception:
            pass

status_counts = Counter(e.get('status', 'unknown') for e in events)
failure_types = Counter(e.get('failure_type', '') for e in events if e.get('failure_type'))
tool_counts = Counter(e.get('tool', '') for e in events)

lines = [
    f"# Postmortem: {run_id}",
    f"Generated: {datetime.now().isoformat()}",
    "",
    "## Summary",
    f"- Total events: {len(events)}",
    f"- Status distribution: {dict(status_counts)}",
    f"- Failure types: {dict(failure_types)}",
    f"- Tool usage: {dict(tool_counts)}",
    "",
    "## Mode Switches",
]
for me in mode_events:
    lines.append(f"- {me.get('ts','?')}: {me.get('from','?')} -> {me.get('to','?')} (fr={me.get('fail_rate','?')} qd={me.get('queue_depth','?')})")
lines += [
    "",
    "## Counterfactual Analysis",
    "<!-- Fill: what if routing/timeout/parallelism changed? -->",
    "",
    "## Action Items",
    "<!-- Fill: retry matrix, routing thresholds, guardrails -->",
    "",
    "## Replay Fixtures",
    f"<!-- Export to scripts/ci/fixtures/replay/{run_id}.jsonl -->",
]
out_path.write_text("\n".join(lines) + "\n", encoding='utf-8')
print(f"Postmortem written to {out_path}")
PY

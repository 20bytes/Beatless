#!/usr/bin/env bash
set -euo pipefail

# budget_gate.sh — Check whether an Anthropic tool call is within daily budget.
# Usage: budget_gate.sh <executor_tool>
# Exit 0 = allowed, Exit 1 = over budget (caller should downgrade).
# Always prints a chosen tool id to stdout.

BEATLESS="${HOME}/.openclaw/beatless"
METRICS_JSON="$BEATLESS/metrics/rawcli-metrics-latest.json"

TOOL="${1:?Usage: budget_gate.sh <executor_tool>}"

OPUS_LIMIT="${OPUS_DAILY_LIMIT:-3}"
SONNET_LIMIT="${SONNET_DAILY_LIMIT:-6}"

case "$TOOL" in
  codex_cli|gemini_cli)
    echo "$TOOL"
    exit 0
    ;;
esac

read_counts() {
  python3 - "$METRICS_JSON" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.exists():
    print('0 0')
    raise SystemExit(0)
try:
    d = json.loads(p.read_text(encoding='utf-8'))
    ac = d.get('anthropic_calls_today', {})
    print(f"{int(ac.get('opus', 0))} {int(ac.get('sonnet', 0))}")
except Exception:
    print('0 0')
PY
}

read -r opus_used sonnet_used <<< "$(read_counts)"

case "$TOOL" in
  claude_architect_opus_cli|claude_opus_cli)
    if [[ "$opus_used" -ge "$OPUS_LIMIT" ]]; then
      if [[ "$sonnet_used" -ge "$SONNET_LIMIT" ]]; then
        echo "claude_generalist_cli"
        exit 1
      fi
      echo "claude_architect_sonnet_cli"
      exit 1
    fi
    echo "$TOOL"
    exit 0
    ;;
  claude_architect_sonnet_cli|claude_sonnet_cli)
    if [[ "$sonnet_used" -ge "$SONNET_LIMIT" ]]; then
      echo "claude_generalist_cli"
      exit 1
    fi
    echo "$TOOL"
    exit 0
    ;;
  claude_generalist_cli)
    echo "$TOOL"
    exit 0
    ;;
  *)
    echo "$TOOL"
    exit 0
    ;;
esac

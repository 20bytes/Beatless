#!/usr/bin/env bash
set -euo pipefail

# dispatch_submit.sh
# Usage:
#   dispatch_submit.sh TASK_ID OWNER_AGENT EXECUTOR_TOOL PROMPT [TIMEOUT_OVERRIDE] [EXPECT_REGEX] [EXPECT_EXACT_LINE] [MODEL_OVERRIDE] [RUN_ID] [PHASE]
# Env:
#   RUN_ID=<run_id>   # optional; used when arg9 is omitted

BEATLESS="${HOME}/.openclaw/beatless"
QUEUE="$BEATLESS/dispatch-queue.jsonl"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 TASK_ID OWNER_AGENT EXECUTOR_TOOL PROMPT [TIMEOUT_OVERRIDE] [EXPECT_REGEX] [EXPECT_EXACT_LINE] [MODEL_OVERRIDE] [RUN_ID] [PHASE]" >&2
  exit 2
fi

TASK_ID="$1"
OWNER_AGENT="$2"
EXECUTOR_TOOL="$3"
PROMPT="$4"
TIMEOUT_OVERRIDE="${5:-}"
EXPECT_REGEX="${6:-}"
EXPECT_EXACT_LINE="${7:-}"
MODEL_OVERRIDE="${8:-}"
RUN_ID="${9:-${RUN_ID:-}}"
PHASE="${10:-}"

case "$OWNER_AGENT" in
  lacia|kouka|methode|satonus|snowdrop) ;;
  *) echo "invalid owner_agent: $OWNER_AGENT" >&2; exit 2 ;;
esac

case "$EXECUTOR_TOOL" in
  codex_cli|claude_generalist_cli|claude_architect_opus_cli|claude_architect_sonnet_cli|claude_opus_cli|claude_sonnet_cli|gemini_cli) ;;
  *) echo "invalid executor_tool: $EXECUTOR_TOOL" >&2; exit 2 ;;
esac

if [[ -n "$RUN_ID" ]]; then
  if ! [[ "$RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{1,127}$ ]]; then
    echo "invalid run_id: $RUN_ID" >&2
    exit 2
  fi
  if [[ "$TASK_ID" != "$RUN_ID" && "$TASK_ID" != "$RUN_ID"-* ]]; then
    echo "task_id must equal run_id or start with run_id- (task_id=$TASK_ID run_id=$RUN_ID)" >&2
    exit 2
  fi
fi

if [[ -n "$PHASE" ]] && ! [[ "$PHASE" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$ ]]; then
  echo "invalid phase: $PHASE" >&2
  exit 2
fi

mkdir -p "$BEATLESS/dispatch-results" "$BEATLESS/logs"
touch "$QUEUE"

python3 - "$TASK_ID" "$OWNER_AGENT" "$EXECUTOR_TOOL" "$PROMPT" "$TIMEOUT_OVERRIDE" "$EXPECT_REGEX" "$EXPECT_EXACT_LINE" "$MODEL_OVERRIDE" "$RUN_ID" "$PHASE" >> "$QUEUE" <<'PY'
import json,sys
obj = {
  "task_id": sys.argv[1],
  "owner_agent": sys.argv[2],
  "executor_tool": sys.argv[3],
  "prompt": sys.argv[4],
  "timeout_override": int(sys.argv[5]) if sys.argv[5].isdigit() else None,
}
if sys.argv[6]:
  obj["expect_regex"] = sys.argv[6]
if sys.argv[7]:
  obj["expect_exact_line"] = sys.argv[7]
if sys.argv[8]:
  obj["model_override"] = sys.argv[8]
if sys.argv[9]:
  obj["run_id"] = sys.argv[9]
if sys.argv[10]:
  obj["phase"] = sys.argv[10]
print(json.dumps(obj, ensure_ascii=False))
PY

if [[ -n "$RUN_ID" ]]; then
  echo "queued: $TASK_ID -> $EXECUTOR_TOOL (run_id=$RUN_ID)"
else
  echo "queued: $TASK_ID -> $EXECUTOR_TOOL"
fi

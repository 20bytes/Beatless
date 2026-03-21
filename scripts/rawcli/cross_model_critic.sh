#!/usr/bin/env bash
set -euo pipefail

# cross_model_critic.sh — dispatch gemini critique for evidence.
# Usage: cross_model_critic.sh <task_id> <evidence_file>

BEATLESS="${HOME}/.openclaw/beatless"
SCRIPTS="$BEATLESS/scripts"
CRITIC_COUNT_FILE="$BEATLESS/metrics/critic-daily-count.txt"
CRITIC_DAILY_LIMIT="${CRITIC_DAILY_LIMIT:-2}"
CROSS_MODEL_CRITIC_ENABLED="${CROSS_MODEL_CRITIC_ENABLED:-false}"

TASK_ID="${1:?Usage: cross_model_critic.sh <task_id> <evidence_file>}"
EVIDENCE="${2:?Usage: cross_model_critic.sh <task_id> <evidence_file>}"

if [[ "$CROSS_MODEL_CRITIC_ENABLED" != "true" ]]; then
  echo "CRITIC_SKIP: feature disabled"
  exit 0
fi

today=$(date +%Y%m%d)
current_count=0
if [[ -f "$CRITIC_COUNT_FILE" ]]; then
  stored_date=$(head -1 "$CRITIC_COUNT_FILE" 2>/dev/null | cut -d: -f1)
  if [[ "$stored_date" == "$today" ]]; then
    current_count=$(head -1 "$CRITIC_COUNT_FILE" | cut -d: -f2)
  fi
fi

if [[ "$current_count" -ge "$CRITIC_DAILY_LIMIT" ]]; then
  echo "CRITIC_SKIP: daily limit reached ($current_count/$CRITIC_DAILY_LIMIT)"
  exit 0
fi

CRITIC_PROMPT="You are a technical reviewer. Read the evidence and assess:\n1) Does output match task requirements?\n2) Any factual errors?\n3) Is evidence sufficient for PASS?\nRespond one line: CRITIC_VERDICT: PASS|NEEDS_REVISION + brief reason.\n\nEvidence file: $EVIDENCE\n$(head -200 "$EVIDENCE" 2>/dev/null || echo '[file not readable]')"

CRITIC_TASK_ID="${TASK_ID}-critic"
bash "$SCRIPTS/dispatch_submit.sh" \
  "$CRITIC_TASK_ID" "satonus" "gemini_cli" \
  "$CRITIC_PROMPT" "300" "" "CRITIC_VERDICT:" "" "" "critic"

echo "$today:$((current_count + 1))" > "$CRITIC_COUNT_FILE"
echo "CRITIC_DISPATCHED: $CRITIC_TASK_ID"

#!/usr/bin/env bash
# test-run.sh — Shell-orchestrated github-hunt pipeline
#
# Architecture: Shell is the orchestrator, not Claude.
# This script runs claude in interactive mode (not --print) so it can
# use Agent tool to spawn codex:codex-rescue and gemini:gemini-consult
# subagents that actually execute.
#
# Usage: bash test-run.sh
# Monitor: tmux attach -t github-hunt
# Logs: ~/.hermes/shared/logs/github-hunt-<timestamp>.log

set -euo pipefail

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOG_DIR="$HOME/.hermes/shared/logs"
LOG_FILE="${LOG_DIR}/github-hunt-${TIMESTAMP}.log"
RESULT_FILE="${LOG_DIR}/github-hunt-${TIMESTAMP}.result"
SESSION_NAME="github-hunt"

mkdir -p "$LOG_DIR"

# Kill any existing session with same name
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

echo "[$TIMESTAMP] Starting github-hunt pipeline"
echo "  Log: $LOG_FILE"
echo "  Monitor: tmux attach -t $SESSION_NAME"
echo "  Result: $RESULT_FILE"

# Run claude in interactive mode with --dangerously-skip-permissions
# so it can use Agent tool to spawn Codex/Gemini subagents.
# The /github-hunt skill will be auto-triggered by the prompt.
tmux new-session -d -s "$SESSION_NAME" bash -c "
  echo '=== github-hunt pipeline started at $(date -u) ===' | tee '$LOG_FILE'

  timeout 3600 claude \
    --dangerously-skip-permissions \
    --verbose \
    --add-dir $HOME/workspace \
    -p 'Execute the github-hunt skill: discover 2 repos (1K-10K stars, agent/LLM topic), clone them, run build verification, then perform triple independent review using Codex (codex:codex-rescue agent), Gemini (gemini:gemini-consult agent), and your own analysis IN PARALLEL. Cross-validate findings (>=2/3 must agree). File GitHub issues only for confirmed P0/P1 bugs. Write summary to ~/workspace/pr-stage/. Both Codex and Gemini must actually run — check that you received results from both before merging.' \
    2>&1 | tee -a '$LOG_FILE'

  EXIT_CODE=\$?
  END_TS=\$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  echo '' | tee -a '$LOG_FILE'
  echo \"=== Pipeline finished at \$END_TS (exit=\$EXIT_CODE) ===\" | tee -a '$LOG_FILE'

  cat > '$RESULT_FILE' <<EOF
{
  \"pipeline\": \"github-hunt\",
  \"status\": \"\$([ \$EXIT_CODE -eq 0 ] && echo 'DONE' || echo 'FAILED')\",
  \"exit_code\": \$EXIT_CODE,
  \"started_at\": \"$TIMESTAMP\",
  \"finished_at\": \"\$END_TS\",
  \"log_file\": \"$LOG_FILE\"
}
EOF

  echo 'Result written to $RESULT_FILE'
"

echo ""
echo "tmux session '$SESSION_NAME' launched."
echo "  Attach:  tmux attach -t $SESSION_NAME"
echo "  Tail:    tail -f $LOG_FILE"
echo "  Check:   cat $RESULT_FILE"

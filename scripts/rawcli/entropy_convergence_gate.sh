#!/usr/bin/env bash
set -euo pipefail

# entropy_convergence_gate.sh
# Check convergence ratio and enforce explore limits.
# Writes gate state to /tmp/beatless_convergence_state.json.

BEATLESS="${HOME}/.openclaw/beatless"
POLICIES="${BEATLESS}/entropy-policies.yaml"
TASKS="${BEATLESS}/TASKS.yaml"
EVENTS="${BEATLESS}/metrics/dispatch-events.jsonl"
STATE_FILE="/tmp/beatless_convergence_state.json"
LOG="${BEATLESS}/logs/convergence-gate.log"

mkdir -p "${BEATLESS}/logs"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

python3 - "$POLICIES" "$TASKS" "$EVENTS" "$STATE_FILE" <<'PYEOF'
import json
import pathlib
import sys
from datetime import datetime, timezone, timedelta

try:
    import yaml
except ImportError:
    print("pyyaml required", file=sys.stderr)
    raise SystemExit(1)

policies_path = pathlib.Path(sys.argv[1])
tasks_path = pathlib.Path(sys.argv[2])
events_path = pathlib.Path(sys.argv[3])
state_path = pathlib.Path(sys.argv[4])

mode_path = pathlib.Path("/tmp/beatless_exec_mode")
current_mode = mode_path.read_text(encoding="utf-8").strip() if mode_path.exists() else "daily"
if current_mode not in ("daily", "intense"):
    current_mode = "daily"

policies = {}
if policies_path.exists():
    policies = yaml.safe_load(policies_path.read_text(encoding="utf-8")) or {}
mode_policy = (policies.get("modes") or {}).get(current_mode, {})
conv_policy = mode_policy.get("convergence", {})

min_ratio = float(conv_policy.get("min_ratio", 0.6))
cooldown_min = int(conv_policy.get("cooldown_minutes", 30))
hysteresis = float(conv_policy.get("hysteresis_band", 0.1))
max_ideas = int(conv_policy.get("max_ideas_in_flight", 3))

tasks_data = {}
if tasks_path.exists():
    tasks_data = yaml.safe_load(tasks_path.read_text(encoding="utf-8")) or {}

idea_count = 0
decision_count = 0

for task in (tasks_data.get("tasks") or []):
    if not isinstance(task, dict):
        continue
    status = str(task.get("status", ""))
    mode = str(task.get("mode", ""))
    if mode in ("explore", "brainstorm", "deep-dive") and status in ("backlog", "ready", "in_progress"):
        idea_count += 1
    if status in ("done", "review"):
        decision_count += 1

for q_name in ("backlog", "ready"):
    items = (tasks_data.get("queues") or {}).get(q_name, [])
    if isinstance(items, list):
        for item in items:
            if isinstance(item, dict) and str(item.get("mode", "")) in ("explore", "brainstorm"):
                idea_count += 1

if events_path.exists():
    # Keep hook for future event-level entropy stats; currently TASKS drives gate.
    _ = events_path.stat().st_size

convergence_ratio = decision_count / (idea_count + 1)

prev_state = {}
if state_path.exists():
    try:
        prev_state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception:
        prev_state = {}

now = datetime.now(timezone.utc)
last_gate_ts = prev_state.get("last_gate_enforced_at")
in_cooldown = False
if last_gate_ts:
    try:
        last_dt = datetime.fromisoformat(last_gate_ts)
        if (now - last_dt) < timedelta(minutes=cooldown_min):
            in_cooldown = True
    except Exception:
        pass

explore_blocked = False
reason = "ok"
if idea_count >= max_ideas:
    explore_blocked = True
    reason = f"max_ideas_in_flight={idea_count}>={max_ideas}"
elif convergence_ratio < min_ratio and not in_cooldown:
    explore_blocked = True
    reason = f"convergence_ratio={convergence_ratio:.2f}<{min_ratio}"

if prev_state.get("explore_blocked") and convergence_ratio < (min_ratio + hysteresis):
    explore_blocked = True
    if reason == "ok":
        reason = f"hysteresis: ratio={convergence_ratio:.2f}<{min_ratio + hysteresis:.2f}"

new_state = {
    "ts": now.isoformat(),
    "mode": current_mode,
    "idea_count": idea_count,
    "decision_count": decision_count,
    "convergence_ratio": round(convergence_ratio, 3),
    "explore_blocked": explore_blocked,
    "reason": reason,
    "in_cooldown": in_cooldown,
}
if explore_blocked and not prev_state.get("explore_blocked"):
    new_state["last_gate_enforced_at"] = now.isoformat()
elif prev_state.get("last_gate_enforced_at"):
    new_state["last_gate_enforced_at"] = prev_state["last_gate_enforced_at"]

state_path.write_text(json.dumps(new_state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PYEOF

result="$(cat "$STATE_FILE")"
blocked="$(echo "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("explore_blocked", False))')"
ratio="$(echo "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("convergence_ratio", 0))')"
mode="$(cat /tmp/beatless_exec_mode 2>/dev/null || echo daily)"
log "convergence_gate: blocked=${blocked} ratio=${ratio} mode=${mode}"
echo "$result"

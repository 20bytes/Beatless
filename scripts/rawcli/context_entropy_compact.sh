#!/usr/bin/env bash
set -euo pipefail

# context_entropy_compact.sh
# Compact large task context in TASKS.yaml to control prompt entropy.

BEATLESS="${HOME}/.openclaw/beatless"
TASKS="${1:-$BEATLESS/TASKS.yaml}"
REPORT_DIR="/home/yarizakurahime/claw/Report/compaction"
POLICIES="$BEATLESS/entropy-policies.yaml"
MODE_FILE="/tmp/beatless_exec_mode"
CURRENT_MODE="$(cat "$MODE_FILE" 2>/dev/null || echo "daily")"
[[ "$CURRENT_MODE" == "intense" ]] || CURRENT_MODE="daily"

read_policy() {
  python3 - "$POLICIES" "$CURRENT_MODE" <<'PY'
import sys
try:
    import yaml
except Exception:
    print(3)
    print(900)
    print("true")
    raise SystemExit(0)

policies = sys.argv[1]
mode = sys.argv[2]
try:
    d = yaml.safe_load(open(policies, "r", encoding="utf-8")) or {}
    mc = ((d.get("modes") or {}).get(mode) or {}).get("compaction", {})
    print(mc.get("trigger_iteration", 3))
    print(mc.get("soft_threshold_chars", 900))
    print("true" if mc.get("inplace_truncate", True) else "false")
except Exception:
    print(3)
    print(900)
    print("true")
PY
}

readarray -t POLICY_VALS < <(read_policy)
TRIGGER_ITERATION="${POLICY_VALS[0]:-3}"
MIN_DESC_CHARS="${POLICY_VALS[1]:-900}"
INPLACE_TRUNCATE="${POLICY_VALS[2]:-true}"

mkdir -p "$REPORT_DIR"

python3 - "$TASKS" "$REPORT_DIR" "$TRIGGER_ITERATION" "$MIN_DESC_CHARS" "$INPLACE_TRUNCATE" <<'PY'
import pathlib
import sys
from datetime import datetime

try:
    import yaml
except Exception:
    print("context_compact: pyyaml missing", file=sys.stderr)
    raise SystemExit(1)

tasks_path = pathlib.Path(sys.argv[1])
report_dir = pathlib.Path(sys.argv[2])
trigger_iteration = int(sys.argv[3])
min_desc_chars = int(sys.argv[4])
inplace = sys.argv[5].lower() == 'true'

if not tasks_path.exists():
    print("context_compact: tasks file missing", file=sys.stderr)
    raise SystemExit(1)

data = yaml.safe_load(tasks_path.read_text(encoding='utf-8')) or {}
changed = 0
report_dir.mkdir(parents=True, exist_ok=True)

for task in (data.get('tasks') or []):
    if not isinstance(task, dict):
        continue
    task_id = str(task.get('id') or '')
    if not task_id:
        continue
    iteration = int(task.get('iteration', 0) or 0)
    status = str(task.get('status', '') or '')
    desc = str(task.get('description', '') or '')
    if len(desc) < min_desc_chars:
        continue
    if iteration < trigger_iteration and status not in {'done', 'review'}:
        continue
    if task.get('context_summary_path'):
        continue

    summary_lines = []
    summary_lines.append(f"# Context Compaction: {task_id}")
    summary_lines.append("")
    summary_lines.append(f"- generated_at: {datetime.now().astimezone().isoformat()}")
    summary_lines.append(f"- source_description_chars: {len(desc)}")
    summary_lines.append(f"- iteration: {iteration}")
    summary_lines.append(f"- status: {status}")
    summary_lines.append("")
    summary_lines.append("## Summary")

    first = desc.strip().splitlines()
    for ln in first[:20]:
        ln = ln.strip()
        if not ln:
            continue
        summary_lines.append(f"- {ln[:220]}")

    refs = task.get('required_reports') or []
    if refs:
        summary_lines.append("")
        summary_lines.append("## Evidence Refs")
        for r in refs[:10]:
            summary_lines.append(f"- {r}")

    out = report_dir / f"{task_id}.md"
    out.write_text("\n".join(summary_lines) + "\n", encoding='utf-8')

    task['context_summary_path'] = str(out)
    task['context_compacted'] = True
    if inplace:
        task['description'] = f"[Compacted] See context_summary_path: {out}"

    changed += 1

if changed:
    meta = data.setdefault('meta', {})
    meta['updated_at'] = datetime.now().astimezone().isoformat()
    tasks_path.write_text(yaml.dump(data, allow_unicode=True, sort_keys=False), encoding='utf-8')

print(f"context_compact: changed={changed}")
PY

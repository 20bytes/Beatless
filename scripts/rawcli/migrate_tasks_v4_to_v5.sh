#!/usr/bin/env bash
set -euo pipefail

# Migrate TASKS.yaml schema v4 -> v5 (additive, zero-downtime).
# Adds defaults for exec_mode/phase/run_id/iteration.

TASKS="${1:-${HOME}/.openclaw/beatless/TASKS.yaml}"
BACKUP="${TASKS}.v4.bak.$(date +%Y%m%d%H%M%S)"

cp "$TASKS" "$BACKUP"
echo "Backup: $BACKUP"

python3 - "$TASKS" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml required. pip install pyyaml")
    raise SystemExit(1)

tasks_path = Path(sys.argv[1])
data = yaml.safe_load(tasks_path.read_text(encoding='utf-8')) or {}
meta = data.setdefault('meta', {})
old_ver = int(meta.get('schema_version', 4) or 4)
if old_ver >= 5:
    print(f"Already v{old_ver}, skipping.")
    raise SystemExit(0)

meta['schema_version'] = 5
for task in data.get('tasks', []) or []:
    if isinstance(task, dict):
        task.setdefault('exec_mode', 'daily')
        task.setdefault('phase', None)
        task.setdefault('run_id', None)
        task.setdefault('iteration', 0)

for item in (data.get('queues', {}) or {}).get('backlog', []) or []:
    if isinstance(item, dict):
        item.setdefault('exec_mode', 'daily')
        item.setdefault('phase', None)
        item.setdefault('run_id', None)
        item.setdefault('iteration', 0)

tasks_path.write_text(
    yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False),
    encoding='utf-8'
)
print(f"Migrated v{old_ver} -> v5")
PY

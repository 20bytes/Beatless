#!/usr/bin/env bash
set -euo pipefail

# Validate config/rawcli/ROUTING.yaml contracts.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROUTING="${ROUTING_PATH:-$ROOT/config/rawcli/ROUTING.yaml}"
TOOL_POOL="${TOOL_POOL_PATH:-$ROOT/config/rawcli/TOOL_POOL.yaml}"

VALID_AGENTS="lacia kouka methode satonus snowdrop"
LEGACY_WRAPPERS="codex-builder gemini-researcher claude-generalist claude-architect-opus claude-architect-sonnet"
errors=0

echo "=== Routing Contract Validation ==="

python3 - "$ROUTING" "$VALID_AGENTS" <<'PY' || errors=$((errors+1))
import sys, yaml
r = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
valid = set(sys.argv[2].split())
for rule in r.get('routing_rules', []):
    rid = rule.get('id', '')
    oa = rule.get('owner_agent')
    if not oa:
        print(f"FAIL: rule '{rid}' missing owner_agent"); raise SystemExit(1)
    if oa not in valid:
        print(f"FAIL: rule '{rid}' owner_agent='{oa}' not in {sorted(valid)}"); raise SystemExit(1)
print('PASS: all rules have valid owner_agent')
PY

python3 - "$ROUTING" "$TOOL_POOL" <<'PY' || errors=$((errors+1))
import sys, yaml
r = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
tp = yaml.safe_load(open(sys.argv[2], encoding='utf-8'))
tools = set((tp.get('tools') or {}).keys())
for rule in r.get('routing_rules', []):
    rid = rule.get('id', '')
    et = rule.get('executor_tool')
    if et is not None and et != '' and et not in tools:
        print(f"FAIL: rule '{rid}' executor_tool='{et}' not in TOOL_POOL"); raise SystemExit(1)
print('PASS: all executor_tool refs valid or null')
PY

python3 - "$ROUTING" "$LEGACY_WRAPPERS" <<'PY' || errors=$((errors+1))
import sys, yaml
r = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
legacy = set(sys.argv[2].split())
for rule in r.get('routing_rules', []):
    rid = rule.get('id', '')
    oa = str(rule.get('owner_agent', '')).lower()
    et = str(rule.get('executor_tool', '') or '').lower()
    for name in legacy:
        if name in oa or name in et:
            print(f"FAIL: rule '{rid}' uses legacy wrapper naming: {name}")
            raise SystemExit(1)
print('PASS: no legacy wrapper names in owner/executor')
PY

python3 - "$ROUTING" <<'PY' || errors=$((errors+1))
import sys, yaml
r = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
for rule in r.get('routing_rules', []):
    rid = rule.get('id', '')
    if 'mode' not in rule:
        print(f"FAIL: rule '{rid}' missing mode field")
        raise SystemExit(1)
print('PASS: all rules include mode')
PY

python3 - "$ROUTING" <<'PY' || errors=$((errors+1))
import sys, yaml
r = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
v = int(r.get('version', 0) or 0)
if v < 3:
    print(f"FAIL: ROUTING version {v} < 3")
    raise SystemExit(1)
print(f"PASS: ROUTING version={v}")
PY

echo "=== Done: $errors error(s) ==="
exit "$errors"

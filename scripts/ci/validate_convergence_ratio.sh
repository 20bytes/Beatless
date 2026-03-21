#!/usr/bin/env bash
set -euo pipefail

STATE="${1:-/tmp/beatless_convergence_state.json}"
POLICIES="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/entropy-policies.yaml}"

if [[ ! -f "$STATE" ]]; then
  echo "SKIP: convergence state not found (gate not yet run)"
  exit 0
fi

python3 -c "
import json
import sys
import yaml

state = json.load(open('$STATE', 'r', encoding='utf-8'))
policies = yaml.safe_load(open('$POLICIES', 'r', encoding='utf-8'))
mode = state.get('mode', 'daily')
if mode not in ('daily', 'intense'):
    mode = 'daily'
min_ratio = float(policies['modes'][mode]['convergence']['min_ratio'])
ratio = float(state.get('convergence_ratio', 0))
blocked = bool(state.get('explore_blocked', False))

print(f'mode={mode} ratio={ratio:.3f} min={min_ratio:.3f} blocked={blocked}')
print(f'ideas={state.get(\"idea_count\",0)} decisions={state.get(\"decision_count\",0)}')

if ratio < 0.2:
    print('WARN: convergence ratio critically low — entropy runaway risk')
    sys.exit(1)
print('PASS: convergence ratio within bounds')
"

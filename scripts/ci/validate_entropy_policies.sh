#!/usr/bin/env bash
set -euo pipefail

POLICIES="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/entropy-policies.yaml}"
EXIT_CODE=0

check() {
  local name="$1"
  local expr="$2"
  if eval "$expr"; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}"
    EXIT_CODE=1
  fi
}

check "file exists" "[[ -f '$POLICIES' ]]"

check "schema structure valid" "python3 -c \"
import yaml
d = yaml.safe_load(open('$POLICIES', 'r', encoding='utf-8'))
assert 'policy_version' in d, 'missing policy_version'
assert 'modes' in d, 'missing modes'
for m in ('daily', 'intense'):
    mc = d['modes'][m]
    assert 'context_budget_tokens_per_turn' in mc, f'{m}: missing budget'
    assert 'compaction' in mc, f'{m}: missing compaction'
    assert 'convergence' in mc, f'{m}: missing convergence'
    c = mc['convergence']
    assert 0 < float(c['min_ratio']) <= 1, f'{m}: invalid min_ratio'
    assert int(c['cooldown_minutes']) > 0, f'{m}: invalid cooldown'
    assert int(c['max_ideas_in_flight']) >= 1, f'{m}: invalid max_ideas'
assert 'degradation' in d, 'missing degradation'
assert 'order_agent' in d, 'missing order_agent'
assert d['order_agent']['role'] in ('satonus', 'lacia'), 'invalid order_agent role'
\""

check "daily stricter than intense" "python3 -c \"
import yaml
d = yaml.safe_load(open('$POLICIES', 'r', encoding='utf-8'))
daily = d['modes']['daily']['convergence']
intense = d['modes']['intense']['convergence']
assert float(daily['min_ratio']) >= float(intense['min_ratio']), 'daily ratio should be >= intense'
assert int(daily['max_ideas_in_flight']) <= int(intense['max_ideas_in_flight']), 'daily ideas should be <= intense'
\""

exit "$EXIT_CODE"

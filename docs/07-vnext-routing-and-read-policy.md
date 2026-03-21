# [V2 ALIGNED] Routing And Read Policy

Updated: 2026-03-21

## Read Layers
- START/CLOSE: read `USER_SOUL + MEMORY + TASKS`
- CHECK (normal): read `TASKS` only
- CHECK (review/blocked/escalation): add `MEMORY`
- CHECK (goal/priority conflict): add `USER_SOUL`

## Routing Tree
- casual chat/simple Q&A -> `lacia` direct reply
- quick search/screenshot/quick verify -> `kouka` (quick mode, timeout 300s)
- review queue non-empty -> `satonus`
- ready queue:
  - `mode=explore` -> `snowdrop` phase-A, then force phase-B dual search (`codex_cli` + `gemini_cli`), then phase-C merge
  - `mode=emergency` -> `kouka`, escalate to executor_tool if needed
  - daily engineering -> `owner_agent=methode`, `executor_tool=claude_generalist_cli`
  - complex code/open-source repro -> `owner_agent=methode`, `executor_tool=codex_cli`
  - academic/theorem/math-physics -> `owner_agent=snowdrop`, `executor_tool=gemini_cli`
  - architecture boundary/rollback -> `owner_agent=lacia`, `executor_tool=claude_architect_opus_cli`
  - fallback -> `owner_agent=methode`, `executor_tool=null`

## Rebuttal Chain
- Trigger: hypothesis conflict or `needs_arbitration=true`
- Evidence pair: `codex_cli` (engineering/open-source) + `gemini_cli` (theory/academic)
- Final arbitration: `satonus` with evidence citations

## Guardrails
- Keep user model/version strings exact; if no evidence, mark `UNVERIFIED`
- Research/news tasks must include absolute dates
- TASKS state update by scripts, not direct edit

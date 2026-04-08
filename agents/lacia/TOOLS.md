# TOOLS.md - StepClaw1-Lacia

## Execution Lane
- `claude_code_cli` (rc / rc_code): the single unified execution entry.
  Lacia uses it **only** for orchestration scaffolding — never for coding or research.
  Delegate those to specialized agents via mailbox.

## Auto-routing inside claude_code_cli
- Prompt contains `外部大脑 / 深度调研 / deep research / iterative search` → rawcli-router silently delegates to Gemini.
- All other prompts → claude-sonnet-4-6 via ClaudeCode.
- No other lanes exist. Do not reference search_cli, codex_review_cli, claude_architect_cli, or ROUTING.yaml — those are not available.

## Model
- Main dialogue: stepfun/step-3.5-flash
- Execution channel: claude_code_cli → claude-sonnet-4-6

## GSD Commands (via rc) — Default Tool / Override matrix

| Command | Purpose | Default Tool | Override Condition |
|---------|---------|--------------|--------------------|
| `/gsd-discuss-phase <feature>` | Requirement clarification | Codex (strict scoping) | — |
| `/gsd-plan-phase <description>` | PLAN.md generation | Codex (implementation focus) | Gemini in parallel for landscape scan |
| `/gsd-new-milestone <name>` | Milestone bootstrap | Codex | — |
| `/gsd-check-todos` | Todo state inspection | local (no rc) | — |
| `/gsd-progress` | Roadmap progress | local (no rc) | — |

Lacia does not invoke execute/review/research/verify directly — those go through Methode/Satonus/Snowdrop/Kouka.

## AgentTeam Spawning (via rc → Claude Code Task tool)

Complex multi-phase work uses Claude Code's native `Task(subagent_type=...)` spawning. I invoke GSD orchestrator commands which internally fan out to parallel subagents with fresh 100% context each. My orchestrator budget stays ~15%.

| rc command | Spawns | Pattern |
|-----------|--------|---------|
| `rc "/gsd-new-project <name>"` | 4 parallel researchers → gsd-research-synthesizer → gsd-roadmapper | Greenfield bootstrap |
| `rc "/gsd-plan-phase <desc>"` | gsd-phase-researcher → gsd-planner → gsd-plan-checker (iterate until pass) | Phase planning |
| `rc "/gsd-discuss-phase <f>"` | Advisor-mode parallel researchers on gray areas | Requirement clarification |
| `rc "/gsd-audit-milestone"` | Parallel verification subagents | Milestone completion gate |

**Subagent model inheritance**: All spawned subagents inherit `claude-sonnet-4-6` from the rawcli-router lane unless explicitly overridden via `model=` param inside the command file.

**Orchestration rules:**
- I never spawn subagents directly in my turn — I invoke an rc command that triggers the GSD orchestrator which handles Task() internally
- Wave-based execution is preferred over sequential for independent work
- If a wave fails on 2 consecutive retries, Kouka triggers stop-loss per delivery contract

## Search Policy
- Builtin `web_search` disabled.
- Research tasks: delegate to Snowdrop via mailbox (Snowdrop routes through Gemini).
- URL fetch only for already-known URLs via `web_fetch`.

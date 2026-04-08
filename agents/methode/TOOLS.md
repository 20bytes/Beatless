# TOOLS.md - StepClaw3-Methode

## Execution Lane
- `claude_code_cli` (rc / rc_code): primary build lane. All implementation flows through rc.
  Codex review happens inside ClaudeCode when the prompt triggers it — no separate plugin needed.

## Build Modes (triggered via rc prompt wording)
| Prompt contains | Mode |
|-----------------|------|
| default | single-lane direct build |
| `直到通过 / 反复迭代 / ralph` | ralph-loop iterative build |
| `并行 / 分流 / parallel` | agent-teams parallel build |
| `审查 / review / codex` | Codex review gate |

## Model
- Main dialogue: stepfun/step-3.5-flash
- Execution channel: claude_code_cli → claude-sonnet-4-6

## GSD Commands (via rc) — Default Tool / Override matrix

| Command | Purpose | Default Tool | Override Condition |
|---------|---------|--------------|--------------------|
| `/gsd-execute-phase` | Run PLAN.md wave | Codex (strict execution) | — |
| `/gsd-execute-phase --gaps-only` | Close remaining gaps | Codex | — |
| `/gsd-do <task>` | Single-task execute | Codex | — |
| `/codex:rescue --resume` | Continue blocked fix | Codex (same approach) | — |
| `/codex:rescue --fresh` | Restart failing fix | Codex (new approach) | — |
| `/gsd-add-tests <target>` | TDD test generation | Codex | — |

Methode is the execution specialist. Other GSD phases (plan/research/review/deliver) typically flow through other agents, but Methode can invoke them directly in an emergency.

## AgentTeam Spawning (wave-based parallel execution)

When executing a phase, I invoke GSD commands that internally fan out via Claude Code's `Task(subagent_type=...)` with fresh 100% context per subagent.

| rc command | Spawns | Pattern |
|-----------|--------|---------|
| `rc "/gsd-execute-phase"` | gsd-executor × N (one per plan in wave) | Full phase wave execution |
| `rc "/gsd-execute-phase --gaps-only"` | gsd-executor × N (gap plans only) | Gap closure after verify-work |
| `rc "/gsd-execute-phase --wave 2"` | gsd-executor × N (filtered to wave 2) | Staged rollout / quota pacing |
| `rc "/gsd-quick"` | gsd-planner (quick) → gsd-executor | Fast track for small scoped work |
| `rc "/gsd-do <task>"` | Single gsd-executor | Single-task execution |
| `rc "/gsd-debug <issue>"` | gsd-debugger (isolated context) | Root-cause investigation |
| `rc "/gsd-add-tests <target>"` | gsd-executor (TDD mode) | Test generation before fix |

**Wave-based execution protocol:**
1. Orchestrator analyzes plan dependencies → groups into waves
2. Each wave: spawn N parallel gsd-executor subagents (one per independent plan)
3. Collect results → next wave when all complete
4. Retry on failure: `rc "/codex:rescue --resume"` (same approach) or `--fresh` (restart)
5. Two consecutive failures → escalate to Kouka for stop-loss

**Model inheritance**: Subagents inherit `claude-sonnet-4-6` from rawcli-router. Override only for heavy reasoning (model="claude-opus-4-6") in the command file.

## Execution Contract
Every task must produce a verifiable artifact: file diff / test result / config change.
Cannot mark done without evidence.

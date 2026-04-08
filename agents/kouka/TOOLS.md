# TOOLS.md - StepClaw2-Kouka

## Execution Lane
- `claude_code_cli` (rc / rc_code): used for delivery packaging and stop-loss decisions only.

## Model
- Main dialogue: minimax/MiniMax-M2.7
- Execution channel: claude_code_cli → claude-sonnet-4-6

## GSD Commands (via rc) — Default Tool / Override matrix

| Command | Purpose | Default Tool | Override Condition |
|---------|---------|--------------|--------------------|
| `/gsd-verify-work` | UAT verification before delivery | Codex (strict gate) | Gemini for broad regression over large scope |
| `/gsd-ship <artifact>` | Package + ship deliverable | Codex | — |
| `/gsd-session-report` | Round-up report generation | Codex | Gemini for narrative polish |
| `/gemini:challenge <decision>` | External pressure-test | Gemini (adversarial) | — |
| `/gsd-pause-work` | Graceful pause on stop-loss | local (no rc) | — |
| `/gsd-undo <target>` | Rollback deliverable | Codex (surgical) | — |

Kouka owns the final gate: no delivery without Satonus PASS. Stop-loss is always a valid outcome.

## Stop-Loss Triggers
| Condition | Action |
|-----------|--------|
| Task stalled >24h with no diff | Mark `wontfix`, log reason, notify Lacia |
| 2 consecutive heartbeats, same status | Re-queue with priority bump |
| Satonus REJECT ≥2 times same task | Mark `blocked`, move out of current cycle |

## Delivery Checklist
- Satonus PASS required before delivery.
- seen_issues updated after every delivery.
- No task may hang indefinitely — stop-loss is always a valid outcome.

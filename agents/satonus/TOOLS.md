# TOOLS.md - StepClaw4-Satonus

## Execution Lane
- `claude_code_cli` (rc / rc_code): used for review and audit operations only.
  Include `审查 / review / codex` in the prompt to route Codex review internally.

## Model
- Main dialogue: minimax/MiniMax-M2.7
- Review channel: claude_code_cli → claude-sonnet-4-6 (Codex gate internally)

## GSD Commands (via rc) — Default Tool / Override matrix

| Command | Purpose | Default Tool | Override Condition |
|---------|---------|--------------|--------------------|
| `/codex:review --background` | Async P0-P3 review | Codex (primary gate) | — |
| `/codex:adversarial-review` | Architecture challenge | Codex (strict) | — |
| `/gsd-code-review <phase>` | GSD-native full review | Codex (via gsd-code-reviewer agent) | Gemini if phase scope >200K tokens |
| `/gemini:review <scope>` | Second-opinion review | Gemini (1M context) | Used when Stage 1 PASS but security-sensitive, or Methode disputes P1 |
| `/gsd-validate-phase <p>` | Phase assumption validation | Codex | Gemini for cross-domain pattern check |
| `/gsd-audit-fix <target>` | Audit + targeted fix | Codex | — |
| `/gsd-secure-phase <p>` | Security audit | Codex | Gemini for SOTA vulnerability check |

Dual-source audit protocol: Codex-primary Stage 1 → optional Gemini Stage 2. See `research/get-shit-done/sdk/prompts/shared/audit-protocol.md`.

## AgentTeam Review Spawning

Review commands internally spawn `Task(subagent_type="gsd-code-reviewer")` with the Codex-native P0-P3 literal-genie persona.

| rc command | Spawns | Pattern |
|-----------|--------|---------|
| `rc "/gsd-code-review <phase>"` | gsd-code-reviewer (Codex-native) | Strict P0-P3 review with PASS/HOLD/REJECT verdict |
| `rc "/gsd-audit-uat"` | Verification subagents | UAT gap analysis |
| `rc "/gsd-audit-milestone"` | Parallel audit subagents | Multi-phase milestone audit |
| `rc "/gsd-audit-fix <target>"` | gsd-code-reviewer → gsd-executor (fix loop) | Audit + targeted fix cycle |

Each spawned reviewer gets fresh 100% context, reads only files in scope, returns structured REVIEW.md + verdict. I merge multiple reviewer outputs per audit-protocol.md Stage 1/Stage 2 rules.

## Verdict Protocol
| Verdict | Meaning | Required |
|---------|---------|----------|
| PASS | Meets standard, no known risk | — |
| REJECT | Does not meet standard | Single-line reason + fix suggestion |
| NEEDS_INFO | Insufficient evidence | Specify exactly what is missing |

Output format:
```
verdict: PASS|REJECT|NEEDS_INFO
risk: LOW|MEDIUM|HIGH
reason: {one line}
```

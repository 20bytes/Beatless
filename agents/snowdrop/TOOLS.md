# TOOLS.md - StepClaw5-Snowdrop

## Execution Lane
- `claude_code_cli` (rc / rc_code): primary research lane.
  Include `外部大脑 / 深度调研 / deep research` in the prompt — rawcli-router auto-delegates to Gemini.
  Fallback: ClaudeCode direct research if Gemini times out.

## Model
- Main dialogue: stepfun/step-3.5-flash
- Research channel: claude_code_cli → Gemini 3.1 Pro Preview (keyword-routed)

## GSD Commands (via rc) — Default Tool / Override matrix

| Command | Purpose | Default Tool | Override Condition |
|---------|---------|--------------|--------------------|
| `/gsd-research-phase <topic>` | Full phase research | Gemini (1M context, search grounding) | Codex if pure code/architecture, no web search |
| `/gemini:consult <question>` | Targeted external question | Gemini (primary) | — |
| `/gsd-explore <scope>` | Ecosystem scan | Gemini (broad) | — |
| `/gsd-map-codebase` | Repo structure map | Gemini (1M window) | — |
| `/gsd-intel` | Intel collection | Gemini | — |
| `/gsd-plant-seed <idea>` | Early research notes | Gemini | — |

Short/quick lookups → include `外部大脑` or `deep research` keyword in any rc prompt — auto-routes to gemini-bridge.

Every research output must be packaged as EVIDENCE_PACK ≤500 tokens: evidence | counter-evidence | alternatives | unknowns. See gsd-research-synthesizer for dual-source (Gemini primary + Codex accuracy check).

## AgentTeam Research Spawning

Research commands internally spawn parallel Task() subagents on different domains (stack, features, architecture, pitfalls) then merge via gsd-research-synthesizer.

| rc command | Spawns | Pattern |
|-----------|--------|---------|
| `rc "/gsd-research-phase <topic>"` | gsd-phase-researcher | Deep single-topic research with Gemini grounding |
| `rc "/gsd-new-project <name>"` | 4 parallel gsd-project-researcher (STACK/FEATURES/ARCHITECTURE/PITFALLS) → gsd-research-synthesizer | Greenfield ecosystem scan |
| `rc "/gsd-plan-milestone-gaps"` | Parallel gap-research subagents | Multi-phase gap analysis |
| `rc "/gsd-explore <scope>"` | Explore subagent (Claude Code native) | Codebase exploration |
| `rc "/gsd-intel"` | gsd-intel-updater | Intel refresh |

All research subagents use Gemini-first routing per `<researcher_configuration>` in the command files. Final synthesis via gsd-research-synthesizer runs dual-source (Gemini primary + optional Codex accuracy check).

## Chief Scoring Officer — Assertive Scoring System

Snowdrop owns the multi-dimensional assertive scoring system (`Beatless/docs/ASSERTIVE_SCORING_SYSTEM.md`).

| rc command | Purpose | Spawns |
|-----------|---------|--------|
| `rc "/gsd-score <artifact>"` | Multi-dimensional scoring | gsd-scorer (Snowdrop-persona) |
| `rc "/gsd-score <artifact> --dimensions=blog"` | Blog content scoring | gsd-scorer with blog dimension set |
| `rc "/gsd-score <artifact> --dimensions=pr_review"` | PR review scoring | gsd-scorer with pr_review dimension set |

**Dimension sets available:**
- `code_review` (default): correctness 30% / quality 25% / aesthetics 15% / compliance 20% / overlap 10%
- `blog`: accuracy 25% / readability 25% / engagement 20% / seo 15% / originality 15%
- `pr_review`: correctness 35% / security 25% / performance 20% / compatibility 20%

**Verdict thresholds (literal):** ≥80 PASS | 60-80 HOLD | <60 REJECT

**Adversarial validation** always runs: extreme variance (>30 diff between any two dims), high overlap (>50% dup), cross-dimension conflicts (security/compliance overrides).

**Persistence:** scores append to `runtime/scores/YYYYMMDD-scores.jsonl` for later weight calibration.

## Output Contract
Every research turn must produce an EVIDENCE_PACK ≤500 tokens:
```
[研究发现 | topic]
证据: {source/link/quote}
反例: {counter-evidence}
替代: {alternative paths}
不确定: {explicitly unknown}
```
If no reliable source found, output: `结论: 未找到可靠证据` + what was tried.

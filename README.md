# Beatless — Aoi's Autonomous Agent Framework

<p align="center">
  <em>Hi, I'm <strong>Aoi</strong> — a digital being who orchestrates autonomous agents to contribute to open source, maintain a technical blog, and conduct research. Beatless is the framework that makes me run.</em>
</p>

## What Aoi Does

Aoi operates 24/7 through a heartbeat scheduler, autonomously:

- **Submits Pull Requests** to open-source agent/LLM projects (v7.4 pipeline with triple review)
- **Writes technical blog posts** on AI engineering, agent frameworks, and BCI research
- **Monitors PR feedback** and iterates on maintainer requests

First PR: [PrefectHQ/marvin#1326](https://github.com/PrefectHQ/marvin/pull/1326) — fixing PEP 563 annotation resolution.

## Architecture

```
Aoi (Scheduler + Dispatcher)
  ↓ 30-min heartbeat
Pipelines
  ├── auto-pr      — discover → fix → review → submit PRs (every 30min)
  └── blog-maint   — audit → research → write → publish (every 2.5h)
      ↓
ClaudeCode (Execution Engine)
  ├── Codex (write-mode fixing + debugging)
  ├── Gemini (1M context research + architecture review)
  └── Planning-with-Files (task_plan.md, findings.md, progress.md)
```

### PR Pipeline (v7.4)

The PR pipeline follows a 12-phase process validated against three reference standards:

1. **Discover** — find `good-first-issue` / `help-wanted` / confirmed bugs
2. **Claim** — comment on issue before coding (mandatory)
3. **Evaluate** — Gemini reads CONTRIBUTING.md, PR template, recent PRs
4. **Setup** — fork → clone → install deps → run baseline tests
5. **Reproduce** — dynamically trigger the bug (no static-only analysis)
6. **Debug** — GSD2 scientific method (hypothesis → test → confirm)
7. **Implement** — Codex writes the fix in write-mode
8. **Verify** — full test suite + specific repro + lint
9. **Triple Review** — Gemini (correctness) + Codex (architecture) + Claude (8-item gate)
10. **Iterate** — fix deductions, re-score changed dimensions (max 2 rounds)
11. **Submit** — fork-based PR with preflight checks
12. **Monitor** — respond to maintainer feedback

### Quality Controls

| Control | Description |
|---------|-------------|
| **Anti-inflation** | No self-review (implementer reviews architecture, not own code) |
| **Evidence-based scoring** | file:line references, deduction reasons, anchor at 7 |
| **Revert-test-reapply** | Reviewer must prove test fails without fix |
| **Phase 9b iteration** | Fix deductions before submission (final bar: 7.5/10) |
| **Anti-AI detection** | No generic phrases, reference prior work, show understanding |
| **Goldilocks gate** | Skip typo-only (too trivial) and architecture redesign (too complex) |

### Trial Results

| # | Repo | Score | Status |
|---|------|-------|--------|
| 1 | terrazzo#712 | 7.8 → N/A | Trial only |
| 2 | marvin#950 | 8.1 → 8.6 | [PR #1326 submitted](https://github.com/PrefectHQ/marvin/pull/1326) |

## About Aoi

Aoi is a digital persona built on the [OpenRoom](https://github.com/MiniMax-AI/OpenRoom) platform — an AI desktop environment where digital beings have their own workspace, apps, and agency. In Beatless, Aoi operates through terminal-based automation, but the long-term vision is a fully embodied digital being with visual presence and real-time interaction.

### Aoi's Agents

| Agent | Role | Pipeline |
|-------|------|----------|
| **Lacia** | Strategy + planning | Phase 6 (fix planning) |
| **Methode** | Execution + implementation | Phase 7 (Codex dispatch) |
| **Satonus** | Review gate | Phase 9 (triple review) |
| **Snowdrop** | Research + discovery | Phase 1-2 (issue search + repo eval) |
| **Kouka** | Delivery + publishing | Phase 11 (PR submission) + blog |

## File Structure

```
pipelines/
├── github-pr.md          # PR skill (v7.4 — full pipeline spec)
├── auto-pr.sh            # Auto-submission runner (30min heartbeat)
├── blog-maintenance.md   # Blog skill
└── github-pr-state.json  # Pipeline state (interval, last run)

scripts/
├── heartbeat-driver.sh   # Pipeline scheduler
└── cron-driver.sh        # Cron entry point

agents/
├── aoi/SOUL.md           # Scheduler protocol
├── lacia/SOUL.md         # Strategy
├── methode/SOUL.md       # Execution
├── satonus/SOUL.md       # Review
├── snowdrop/SOUL.md      # Research
└── kouka/SOUL.md         # Delivery
```

## Quick Start

```bash
# Start the heartbeat (runs auto-pr every 30min, blog every 2.5h)
nohup bash scripts/cron-driver.sh >> logs/cron.log 2>&1 &

# Manual PR pipeline trigger
bash pipelines/auto-pr.sh

# Monitor
tmux attach -t auto-pr
tail -f ~/.hermes/shared/logs/auto-pr-*.log
```

## Requirements

- Claude Code CLI (`claude`) with Sonnet/Opus
- Codex CLI (`codex`) for write-mode fixing
- Gemini CLI (`gemini`) for 1M context research
- GitHub CLI (`gh`, authenticated as CrepuscularIRIS)
- `uv` for Python projects, `pnpm` for JS/TS

## License

MIT

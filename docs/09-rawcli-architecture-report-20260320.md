# Beatless RawCli Architecture Report (2026-03-20)

## Scope
This report captures the current Beatless architecture state after the RawCli migration and summarizes the remaining gap to the target/ideal shape.

## Current State (Verified)

### 1. Core Topology
- Runtime pattern is now: `owner_agent (5 core)` + `executor_tool (RawCli pool)`.
- OpenClaw agent list is reduced to 5 core agents only: `lacia/kouka/methode/satonus/snowdrop`.
- Wrapper-agent dispatch path is no longer the primary execution path.

### 2. RawCli Tool Pool
- Tool definitions are centralized in `~/.openclaw/beatless/TOOL_POOL.yaml`.
- Active tools:
  - `codex_cli`
  - `claude_sonnet_cli`
  - `claude_opus_cli`
  - `gemini_cli`
- Codex command shape has been corrected to non-interactive execution (`codex exec ...`), with prompt mode compatibility.

### 3. Hook/Event Runtime
- Dispatch runtime is event-driven (`dispatch-queue.jsonl` -> tmux hook -> per-task pane -> result JSON).
- Hook loop is active under `beatless-v2` session and writing result artifacts.

### 4. End-to-End Runtime Evidence
- Successful RawCli dispatch proof tasks:
  - `BT-RAWCLI2-CODEX-20260320-151143`
  - `BT-RAWCLI2-CLAUDE-20260320-151143`
- Both produced:
  - `dispatch-results/<task>.json` with `status=success`
  - `/home/yarizakurahime/claw/Report/<task>-cli-output.md`

### 5. Skills/Agents Readiness
- Claude workflow plugins remain installed and enabled (high-frequency set intact).
- Codex agents (`explorer/reviewer/docs-researcher`) remain available.
- Codex skill aliases have been normalized (`quality-gate/code-review/refactor-clean/verify/...`) to match operational naming.

## What Was Adapted in This Round
- Added prompt mode routing in hook execution (`positional` vs `-p`) for CLI compatibility.
- Updated tool pool command for Codex RawCli correctness.
- Synced implementation bundle copies in `openclaw/docs/beatless-v2-rawcli/IMPLEMENTATION_BUNDLE`.
- Updated active memory terminology to RawCli naming (`codex_cli/claude_sonnet_cli/claude_opus_cli`).
- Cleaned active TASKS wording for wrapper-name drift (without rewriting historical session keys).

## Gap to Ideal Shape

### Ideal Shape Definition
- Single-path execution: all external model work goes through RawCli tool pool.
- Deterministic routing contract: owner/executor split with no naming ambiguity.
- Fully observable runtime: each dispatch has stable logs, timings, and quality verdict linkage.
- Low drift memory/config docs: no legacy wrapper terms in active policy files.
- Operational hardening: one-command bootstrap, health checks, and CI validation for routing/hook flow.

### Estimated Distance (as of 2026-03-20)
- Overall completion toward ideal shape: **~72%**
- Remaining gap: **~28%**

Breakdown (estimation):
- Architecture migration completeness: **85%** (major design shift completed)
- Runtime reliability/hardening: **70%** (core works, still needs stricter guards)
- Observability/diagnostics: **65%** (artifacts exist, dashboards/alerts missing)
- Config/memory consistency: **68%** (active files mostly aligned, historical drift remains)
- Automation/CI enforcement: **55%** (manual verification dominates)

## Priority Next Steps (to close the 28%)
1. Add a dedicated RawCli health-check script that executes `codex/claude/gemini` probes and fails fast.
2. Add CI checks for route contract (`owner_agent + executor_tool`) and prompt mode compatibility.
3. Introduce dispatch result schema validation + failure classification (timeout/auth/cli-arg).
4. Complete legacy naming cleanup in non-archival docs/tasks while preserving historical IDs.
5. Standardize bootstrap/restart commands for `beatless-v2` tmux/hook lifecycle.

## Conclusion
RawCli architecture is now functionally real and validated in production-like flow. The largest remaining work is operational hardening and consistency cleanup, not core architecture redesign.

---
name: github-hunt
description: "Autonomous bug hunting pipeline for 1K-10K star agent/LLM repos on GitHub. Discovers repos, clones, runs build verification, then performs independent triple review using Codex (via codex:codex-rescue agent), Gemini (via gemini:gemini-consult agent), and Claude's own analysis in parallel. Only files issues for bugs confirmed by >=2/3 reviewers. Use this skill whenever the user mentions hunting bugs, scanning GitHub repos, finding issues in open source projects, automated code auditing, or wants to discover and report bugs in agent/LLM repositories."
---

# GitHub Issue Hunt Pipeline

Autonomous pipeline: discover repos -> clone -> build verify -> **parallel triple review** (Codex + Gemini + Claude) -> cross-validate -> file issues.

## Why This Architecture

Previous versions put Codex/Gemini calls inside a `claude --print` prompt, where Claude could (and did) skip the Bash calls entirely, fabricating "triple review" results from its own analysis alone. This skill fixes that by using Claude Code's **Agent tool** to spawn `codex:codex-rescue` and `gemini:gemini-consult` as independent subagents. These are real subprocesses that must execute — they cannot be skipped.

## Execution Model

- **Claude**: Primary analysis via Read/Grep/Glob tools + orchestration
- **Codex**: Independent audit via `Agent` tool with `subagent_type: "codex:codex-rescue"`
- **Gemini**: Independent analysis via `Agent` tool with `subagent_type: "gemini:gemini-consult"`
- **GitHub CLI**: `gh` via Bash for search, clone, issue creation

All three reviewers run **in parallel** as independent agents. Results are merged only after all three complete.

## Context

- Archive directory: `~/workspace/archive/`
- Staging directory: `~/workspace/pr-stage/`
- GitHub CLI: `gh` (authenticated as CrepuscularIRIS)
- Working directory: MUST `cd` into each repo before analysis

---

## Phase 1: DISCOVERY

Search for agent/LLM repos using `gh` via Bash:

```bash
gh search repos --stars=1000..10000 --sort=updated --limit=30 \
  --json fullName,stargazersCount,description,updatedAt,hasIssuesEnabled,language \
  -- "agent OR llm OR langchain OR autogen OR crewai OR swarm OR rag OR embedding OR inference OR serving"
```

Filter criteria:
- Has issues enabled, not archived, pushed in last 30 days
- Not already in `~/workspace/archive/`
- Related to: AI agents, LLM frameworks, inference engines, RAG pipelines
- Prefer: Python, TypeScript, Go, Rust repos with active communities
- Avoid: tutorial repos, awesome-lists, wrapper-only projects

Select TOP 2 repos. Clone via Bash:
```bash
gh repo clone <owner/repo> ~/workspace/archive/<repo-name> -- --depth=1
```

---

## Phase 2: BUILD VERIFICATION

For each cloned repo, verify it builds before analysis. Run via Bash:

```bash
cd ~/workspace/archive/<repo-name>

# Detect and run build
if [ -f go.mod ]; then go build ./... 2>&1; fi
if [ -f package.json ]; then npm install && npm run build 2>&1; fi
if [ -f pyproject.toml ] || [ -f setup.py ]; then pip install -e . 2>&1; fi
if [ -f Cargo.toml ]; then cargo build 2>&1; fi
```

If build fails, note it but still proceed with static analysis (many bugs are findable without a working build).

---

## Phase 3: TRIPLE INDEPENDENT REVIEW (Parallel Agents)

This is the critical phase. Spawn THREE independent agents in a SINGLE message using the Agent tool. All three must run — this is not optional.

### Agent 1: Codex Review (codex:codex-rescue)

Spawn with `subagent_type: "codex:codex-rescue"`:

```
Analyze the repository at ~/workspace/archive/<repo-name> for critical bugs.

Focus on:
1. Bugs that crash or corrupt data
2. Security vulnerabilities (RCE, injection, SSRF, path traversal)
3. Race conditions and concurrency bugs
4. Missing error handling that causes panics/unhandled exceptions

Only report P0/P1 severity. For each finding, provide:
- File path and line number
- Bug description (what's wrong)
- Impact (what happens to users)
- Suggested fix (one-liner)

Output as structured text, one finding per section.
```

### Agent 2: Gemini Analysis (gemini:gemini-consult)

Spawn with `subagent_type: "gemini:gemini-consult"`:

```
Analyze the repository at ~/workspace/archive/<repo-name> for critical bugs.

Focus on:
1. Crashes and data loss scenarios
2. Security vulnerabilities exploitable by users
3. Race conditions and deadlocks
4. API contract violations and type mismatches

Only report P0/P1 severity. For each finding, provide:
- File path and line number
- Bug description
- Reproduction scenario
- Severity justification

Output as structured text, one finding per section.
```

### Agent 3: Claude Direct Analysis

Use your own Read/Grep/Glob tools directly:

```bash
cd ~/workspace/archive/<repo-name>
```

- Read entry points (main.go, main.py, src/index.ts, etc.)
- Grep for dangerous patterns: `eval(`, `exec(`, `unsafe`, `panic(`, `os.Exit`, `TODO`, `FIXME`, `HACK`
- Find error handling gaps: bare `except:`, empty `catch {}`, unchecked error returns
- Look for race conditions, goroutine leaks, missing locks
- Check for security issues: hardcoded secrets, SQL injection, path traversal

Focus on bugs that break functionality or crash the application. Not style issues.

### Cross-reference with existing issues

After all three agents complete, check existing issues:
```bash
gh issue list --repo <owner/repo> --state open --limit 200 --json title,body,labels | head -500
```

Remove any finding that matches an existing open issue.

---

## Phase 4: CROSS-VALIDATION MERGE

Only keep findings that meet ALL criteria:

1. **>=2/3 reviewers flagged it** — at least two of (Claude, Codex, Gemini) independently identified the same bug
2. **Verified by reading code** — you (Claude) Read the actual file and line to confirm the bug exists
3. **Real impact** — the bug affects actual users, not theoretical edge cases
4. **Not already reported** — no matching open issue exists
5. **P0 or P1 severity only**:
   - P0: Crashes, data loss, RCE, SQL injection, authentication bypass
   - P1: Race conditions causing wrong results, API contract violations, resource leaks causing OOM, panics on malformed input

Save validated findings to `~/workspace/pr-stage/<date>-<repo>-finding-<N>.md`.

---

## Phase 5: FILE ISSUES

For each validated finding, create a GitHub issue via Bash. Follow the professional format below — no internal jargon, no mention of "multi-agent analysis", no "soul contracts" or system names.

```bash
gh issue create --repo <owner/repo> \
  --title "<concise bug title>" \
  --body "$(cat <<'EOF'
## Bug Description

<2-3 sentences: what's broken, in plain language>

## Location

`<file>:<line>`

## Reproduction

1. <step 1>
2. <step 2>
3. <observe: crash/wrong result/security issue>

## Impact

<who is affected and how — data loss? crash? security exposure?>

## Suggested Fix

<brief description or pseudocode of the fix>

---
Found via automated codebase analysis. Happy to submit a PR if this is confirmed.
EOF
)"
```

### Issue Quality Rules (from mention.md)

The issue must read as if a competent engineer found the bug by reading the code:
- **No internal workflow language** — don't mention agents, lanes, triple review, orchestration
- **Problem -> Evidence -> Fix** — that's the only structure needed
- **Be boring** — the most useful issues are the most straightforward ones
- **One issue per bug** — don't bundle findings
- **Minimal scope** — don't suggest refactors alongside the bug report

---

## Phase 6: SUMMARY REPORT

Write to `~/workspace/pr-stage/hunt-summary-<date>.md`:

```markdown
# Hunt Summary — <date>

## Repos Scanned
- <repo1> (<stars> stars, <language>) — <N> findings
- <repo2> (<stars> stars, <language>) — <N> findings

## Issues Filed
- <owner/repo>#<N>: <title> (P0/P1)

## Rejected Findings
- <finding>: <reason for rejection>

## Evidence
- Codex output: <summary of what Codex found>
- Gemini output: <summary of what Gemini found>
- Claude output: <summary of what Claude found>
- Agreement matrix: <which reviewers agreed on which findings>

## Build Status
- <repo1>: PASS/FAIL
- <repo2>: PASS/FAIL
```

---

## Rules

1. **Spawn Codex and Gemini as parallel Agent subagents** — they are independent processes, not suggestions
2. **Both Codex and Gemini must actually run** — check that you received results from both before proceeding to merge
3. **>=2/3 agreement required** — a single reviewer's finding is not enough
4. **Verify before claiming** — Read the actual code file and line
5. **Professional issue format** — follow mention.md guidelines, no internal jargon
6. **One issue per bug** — don't bundle
7. **P0/P1 only** — skip style, docs, performance suggestions
8. **Build first** — attempt build verification before analysis

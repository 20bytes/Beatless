---
description: "Hunt critical bugs in 1K-10K star agent/LLM repos. Deep scan with Codex+Gemini+Claude. File issues for confirmed bugs, consider PR if maintainer responds."
---

# GitHub Issue Hunt Pipeline

Autonomous pipeline: discover repos → clone → deep scan → triple review → file issues for confirmed critical bugs.

## Execution Model

Claude Code is the main executor. For each repo analysis:
- **Claude**: Primary code analysis via Read/Grep/Glob tools
- **Codex CLI**: Code audit via `codex` CLI (Bash)
- **Gemini CLI**: Architecture analysis via `gemini` CLI (Bash)

**CRITICAL**: Do NOT use `/codex:review` or `/gemini:consult` slash commands — they don't work in `--print` mode. Instead, call the CLIs directly via Bash:

```bash
# Codex review (read-only, full-auto approval)
cd <repo> && codex --approval-mode full-auto --quiet "Review this codebase for critical bugs, security vulnerabilities, race conditions, and crashes. Focus only on P0/P1 severity. Output structured findings with file:line."

# Gemini analysis (1M context)
cd <repo> && gemini -p "Analyze this entire codebase for: (1) critical bugs causing crashes or data loss, (2) security vulnerabilities, (3) race conditions, (4) API contract violations. List only P0/P1 with exact file:line."
```

## Context

- Archive directory: `~/workspace/archive/`
- Staging directory: `~/workspace/pr-stage/`
- GitHub CLI: `gh` (authenticated as CrepuscularIRIS)
- Working directory: MUST `cd` into each repo before analysis

---

## Phase 1: DISCOVERY

Search for agent/LLM repos:

```bash
gh search repos --stars=1000..10000 --sort=updated --limit=30 \
  --json fullName,stargazersCount,description,updatedAt,hasIssuesEnabled,language \
  -- "agent OR llm OR langchain OR autogen OR crewai OR swarm OR rag OR embedding OR inference OR serving"
```

Filter criteria:
- Has issues enabled, not archived, pushed in last 30 days
- Not already in `~/workspace/archive/`
- Must be related to: AI agents, LLM frameworks, inference engines, RAG pipelines
- Prefer: Python, TypeScript, Go, Rust repos with active communities
- Avoid: tutorial repos, awesome-lists, wrapper-only projects

Select TOP 2 repos. Clone:
```bash
gh repo clone <owner/repo> ~/workspace/archive/<repo-name> -- --depth=1
```

---

## Phase 2: DEEP SCAN (per repo)

For EACH cloned repo, execute ALL THREE analysis passes:

### Pass 1: Claude Direct Analysis

```bash
cd ~/workspace/archive/<repo-name>
```

Use Read, Grep, Glob tools:
- Read entry points (main.go, main.py, src/index.ts, etc.)
- Grep for dangerous patterns: `eval(`, `exec(`, `unsafe`, `panic(`, `os.Exit`, `TODO`, `FIXME`, `HACK`
- Find error handling gaps: bare `except:`, empty `catch {}`, unchecked error returns
- Look for race conditions, goroutine leaks, missing locks
- Check for security issues: hardcoded secrets, SQL injection, path traversal, SSRF

Focus on **bugs that break functionality or crash the application**. Not style issues.

### Pass 2: Codex CLI Audit (MANDATORY — via Bash)

```bash
cd ~/workspace/archive/<repo-name> && codex --approval-mode full-auto --quiet \
  "Review this codebase. Find: (1) bugs that crash or corrupt data, (2) security vulnerabilities (RCE, injection, SSRF), (3) race conditions, (4) missing error handling that causes panics. Output structured JSON: [{file, line, severity, title, description}]. Only P0/P1."
```

Record Codex output verbatim. Do NOT invent findings.

### Pass 3: Gemini CLI Analysis (MANDATORY — via Bash)

```bash
cd ~/workspace/archive/<repo-name> && gemini -p \
  "Analyze this codebase for critical bugs. Focus on: (1) crashes and data loss, (2) security vulnerabilities exploitable by users, (3) race conditions, (4) API contract violations. Ignore style/docs. List only P0/P1 severity with exact file paths and line numbers."
```

Record Gemini output verbatim. Do NOT invent findings.

### Cross-reference with existing issues

```bash
gh issue list --repo <owner/repo> --state open --limit 200 --json title,body,labels | head -500
```

Remove any finding that matches an existing open issue.

---

## Phase 3: TRIPLE MERGE + QUALITY FILTER

### Severity classification (ONLY keep bugs that break functionality)

- **P0 (Critical)**: Crashes, data loss, RCE, SQL injection, authentication bypass
- **P1 (High)**: Race conditions causing wrong results, API contract violations, resource leaks causing OOM, panics on malformed input
- **P2+ (Skip)**: Style, docs, performance suggestions, test coverage → DO NOT INCLUDE

### Validation checklist (ALL must be true)

- [ ] Bug is reproducible (you can describe exact steps)
- [ ] Bug affects real users (not theoretical edge case)
- [ ] Bug is not already reported
- [ ] You verified the code path exists (Read the actual file and line)
- [ ] At least 2 of 3 reviewers (Claude/Codex/Gemini) flagged it

### Write proposal for each validated finding

Save to `~/workspace/pr-stage/<date>-<repo>-finding-<N>.md`

---

## Phase 4: FILE ISSUES (for confirmed critical bugs only)

For each PASS finding that represents a **real bug breaking functionality** (not security-only):

```bash
gh issue create --repo <owner/repo> \
  --title "<concise bug title>" \
  --body "<markdown: Problem, file:line, reproduction steps, impact, suggested fix, 'Found via automated codebase analysis'>"
```

**Do NOT file issues for**: minor issues, style problems, "potential" vulnerabilities without reproduction, theoretical edge cases.

**Do NOT submit PRs** unless a maintainer responds to the issue and confirms it.

---

## Phase 5: SUMMARY REPORT

Write to `~/workspace/pr-stage/hunt-summary-<date>.md` with: repos scanned, issues filed (URLs), rejected findings with reasons, Codex/Gemini evidence.

---

## Rules

1. **Use Bash to call `codex` and `gemini` CLI directly** — not plugin slash commands
2. **MUST `cd` into repo** before analysis
3. **ONLY file issues for real bugs that break functionality**
4. **At least 2/3 reviewers must agree** for a finding to pass
5. **Verify before claiming** — Read the actual code
6. Report progress after each phase

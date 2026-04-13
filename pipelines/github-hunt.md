---
name: github-hunt
description: "Dynamic-only bug hunting for 1K-10K star agent/LLM repos. Clones repos, sets up full dev environment (uv/npm/go), builds, runs the project's own test suite, and debugs every failure to root cause. NO static code analysis, NO security scanning — only bugs proven by actually running the code. Uses Codex and Gemini as debugging assistants (not code reviewers). Files issues only for bugs with real stack traces and reproduction commands. Use whenever the user mentions hunting bugs, testing repos, finding crashes, or dynamic code analysis."
---

# GitHub Deep Hunt Pipeline v4 — Dynamic Only

Discover repos → clone → **build environment** → **run all tests** → **debug every failure** → file issues for real crashes only.

## Philosophy

Static analysis finds easy, obvious patterns (eval/exec/pickle) that maintainers already know about. These generate noise, not value. Real value comes from **actually running the code** and finding bugs that the maintainers missed — crashes, wrong results, race conditions that only surface at runtime.

This pipeline files issues ONLY for bugs proven by execution:
- A test that fails with a stack trace
- A build that crashes
- A race condition caught by `-race` flag
- A runtime error on edge-case input

If it can't be reproduced by running a command, it doesn't get filed.

## Execution Model

- **Claude**: Orchestrator + debug analysis (Read/Grep/Glob to trace stack traces)
- **Codex** (`codex:codex-rescue` agent): Debug assistant — help trace complex failures, suggest fixes
- **Gemini** (`gemini:gemini-consult` agent): Debug assistant — analyze architecture to understand why a test fails
- **gh CLI**: Repo search, clone, issue creation
- **uv / npm / go / cargo**: Environment setup and test execution

Codex and Gemini are used for **debugging**, not for scanning code. They read the failing test + stack trace and help identify root cause.

## Context

- Archive: `~/workspace/archive/`
- Staging: `~/workspace/pr-stage/`
- GitHub: `gh` authenticated as CrepuscularIRIS
- Python venvs: use `uv` (fast, isolated)

---

## Phase 1: DISCOVERY

```bash
gh search repos --stars=1000..10000 --sort=updated --limit=30 \
  --json fullName,stargazersCount,description,updatedAt,hasIssuesEnabled,language \
  -- "agent OR llm OR langchain OR autogen OR crewai OR swarm OR rag OR embedding OR inference OR serving"
```

Filter:
- Issues enabled, not archived, pushed in last 30 days
- Not already in `~/workspace/archive/`
- AI agents, LLM frameworks, inference, RAG pipelines
- **Prefer repos with existing test suites** (check for pytest.ini, go.mod, package.json with test script)
- Avoid: tutorials, awesome-lists, thin wrappers, repos with 0 tests

Select TOP 2. Clone:
```bash
gh repo clone <owner/repo> ~/workspace/archive/<repo-name> -- --depth=1
```

---

## Phase 2: ENVIRONMENT SETUP

Build a working dev environment. If this fails entirely, **skip this repo** — we can't do dynamic testing without a working build.

```bash
cd ~/workspace/archive/<repo-name>

# Python
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then
  uv venv .venv && source .venv/bin/activate
  uv pip install -e ".[dev,test]" 2>&1 || uv pip install -e ".[dev]" 2>&1 || uv pip install -e . 2>&1
  [ -f requirements.txt ] && uv pip install -r requirements.txt 2>&1
  [ -f requirements-dev.txt ] && uv pip install -r requirements-dev.txt 2>&1
fi

# Go
if [ -f go.mod ]; then
  go mod download 2>&1
  go build ./... 2>&1
fi

# Node.js
if [ -f package.json ]; then
  npm install 2>&1
  npm run build 2>&1 || true
fi

# Rust
if [ -f Cargo.toml ]; then
  cargo build 2>&1
fi
```

- **BUILD PASS**: Proceed to Phase 3
- **BUILD FAIL**: Try to fix obvious dep issues (missing extras, wrong Python version). If still fails, **skip this repo entirely** and pick a new one from the discovery list

---

## Phase 3: RUN ALL TESTS

Execute the project's full test suite. Capture everything — passes, failures, errors, warnings.

```bash
cd ~/workspace/archive/<repo-name>

# Python
if [ -f pyproject.toml ] || [ -f setup.py ]; then
  source .venv/bin/activate 2>/dev/null
  pytest --tb=long -v --timeout=60 2>&1 | tee /tmp/hunt-test-$(basename $PWD).log
fi

# Go (with race detector — catches concurrency bugs)
if [ -f go.mod ]; then
  go test -race -count=1 -v -timeout 120s ./... 2>&1 | tee /tmp/hunt-test-$(basename $PWD).log
fi

# Node.js
if [ -f package.json ]; then
  npm test 2>&1 | tee /tmp/hunt-test-$(basename $PWD).log
fi

# Rust
if [ -f Cargo.toml ]; then
  cargo test 2>&1 | tee /tmp/hunt-test-$(basename $PWD).log
fi
```

Parse results:
- **ALL PASS**: No dynamic bugs found. Write "all tests pass" in summary. Move to next repo.
- **SOME FAIL**: Each failure is a candidate. Capture test name, stack trace, error message. Move to Phase 4.
- **NO TESTS**: Skip this repo — we need tests for dynamic analysis.

---

## Phase 4: DEBUG EVERY FAILURE

For each test failure, determine whether it's a real bug or a test-environment issue.

### 4a. Isolate

Run the failing test alone:
```bash
pytest tests/test_foo.py::test_failing_case -v --tb=long 2>&1
# or: go test -v -run TestSpecificCase ./pkg/...
```

### 4b. Classify first — filter out noise

Many test failures are NOT real bugs:
- **TEST_ENV**: Missing API key, network dependency, Docker not running, wrong OS → **SKIP**
- **FLAKY**: Timing-dependent, passes on retry → **SKIP**
- **KNOWN**: Already reported as open issue → **SKIP**
- **CONFIG**: Wrong test config for this environment (e.g., needs GPU) → **SKIP**

Only proceed to 4c for failures that indicate **real code bugs**.

### 4c. Trace root cause

Read the stack trace bottom-up:
1. What exception/panic/error was thrown?
2. Which file:line in **production code** (not test code) triggered it?
3. Read that code — what condition causes the failure?
4. Is this a logic bug, missing null check, wrong type, race condition, or unhandled edge case?

### 4d. Use Codex or Gemini for complex failures

For failures where the root cause isn't obvious from the stack trace, spawn a debug assistant:

**Codex** (`codex:codex-rescue`):
```
Debug this test failure in ~/workspace/archive/<repo-name>.

Failing test: <test name>
Stack trace:
<paste stack trace>

Read the source code at the crash site. What is the root cause?
Is this a real bug in production code, or a test-environment issue?
If it's a real bug, what's the minimal fix?
```

**Gemini** (`gemini:gemini-consult`):
```
Help debug this test failure. The test <name> fails with:
<paste error>

Read the test file and the production code it tests.
Explain: why does this test exist? What invariant is it checking?
Is the test correct and the code buggy, or is the test itself broken?
```

### 4e. Record confirmed bugs

For each REAL bug (not test-env/flaky/known):

Save to `~/workspace/pr-stage/<date>-<repo>-failure-<N>.md`:
- Test command (exact, copy-pasteable)
- Full stack trace
- Root cause (which production code line, why it fails)
- Severity: P0 (crash/data loss) or P1 (wrong result/race)
- Suggested fix (1-10 lines)

---

## Phase 5: FILE ISSUES (dynamic bugs only)

File issues ONLY for bugs that have a reproduction command and stack trace.

```bash
gh issue create --repo <owner/repo> \
  --title "bug: <concise description of the crash/failure>" \
  --body "$(cat <<'EOF'
## Bug Description

<2-3 sentences: what crashes/fails and why>

## Reproduction

```bash
# Exact command to reproduce:
pytest tests/test_foo.py::test_failing_case -v
# or: go test -race -run TestSpecific ./pkg/...
```

## Stack Trace

```
<full stack trace from the test run>
```

## Root Cause

`<file>:<line>` — <1-2 sentence explanation of why this code fails>

## Impact

<what breaks for users — crash? wrong output? data corruption? hangs?>

## Suggested Fix

```<language>
<1-10 line fix>
```

---
Found by running the test suite. Happy to submit a PR if confirmed.
EOF
)"
```

### What NOT to file
- Static-only findings (eval/exec/pickle patterns found by grep)
- Security vulnerabilities found by code reading
- Style issues, performance suggestions, documentation gaps
- Test-environment failures (missing Docker, API keys, etc.)
- Flaky tests that pass on retry

---

## Phase 6: SUMMARY REPORT

Write to `~/workspace/pr-stage/hunt-summary-<date>.md`:

```markdown
# Hunt Summary — <date>

## Repos Scanned
| Repo | Stars | Lang | Build | Tests | Failures | Issues Filed |
|------|-------|------|-------|-------|----------|-------------|
| name | N⭐ | Go | PASS | 120 pass / 3 fail | 2 real bugs | 2 |

## Issues Filed
| # | Repo | Title | Severity | Test Command |
|---|------|-------|----------|-------------|
| 1 | owner/repo#N | crash description | P0 | `pytest tests/...` |

## Skipped Failures
- <test>: TEST_ENV (needs Docker)
- <test>: FLAKY (passes on retry)
- <test>: KNOWN (matches #123)

## Repos Skipped
- <repo>: build failed (missing dep X)
- <repo>: no test suite
```

---

## Rules

1. **Dynamic only** — every filed issue must have a reproduction command and stack trace
2. **No static analysis** — do not grep for eval/exec/pickle, do not scan for security patterns
3. **No security issues** — security scanning is explicitly disabled in this pipeline
4. **Build first** — if the project doesn't build, skip it
5. **Run tests** — if the project has no tests, skip it
6. **Filter noise** — most test failures are test-env issues, not real bugs
7. **Codex/Gemini for debugging** — use them to trace complex root causes, not to scan code
8. **Professional format** — include exact test command + full stack trace in every issue

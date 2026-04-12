---
name: github-pr
description: "Submit a PR to fix a confirmed GitHub issue. Fork -> fix (via Codex codex:codex-rescue agent) -> test -> PR. Use this skill when a github-hunt issue has been confirmed by maintainers, when you have a clear bug with a known fix path, or whenever the user mentions submitting a fix, creating a PR for a GitHub issue, or contributing a patch to an open source project."
---

# GitHub PR Submission Pipeline

Take a confirmed GitHub issue and submit a minimal fix as a Pull Request.

This is the **delivery half** of the github-hunt workflow:
- `github-hunt` discovers bugs and files issues
- `github-pr` fixes confirmed bugs and submits PRs

## When to Use

- A github-hunt issue received a response from maintainers confirming the bug
- You have a clear bug with a known fix (<100 lines of code change)
- The fix is straightforward enough to verify with existing tests

Do NOT use for: speculative fixes, large refactors, issues without clear reproduction steps.

## Input

Either:
- A GitHub issue URL: `https://github.com/owner/repo/issues/123`
- Or: a repo name + description of what to fix

---

## Phase 1: UNDERSTAND THE ISSUE

Read the issue details via Bash:
```bash
gh issue view <issue-number> --repo <owner/repo> --json title,body,labels,comments
```

Extract:
- What's broken (bug description)
- Which file(s) and line(s) are affected
- Reproduction steps (if provided)
- Any maintainer comments or suggestions

If the issue was created by the github-hunt pipeline, check `~/workspace/pr-stage/` for the original finding which has detailed analysis.

---

## Phase 2: FORK AND CLONE

```bash
# Fork (idempotent)
gh repo fork <owner/repo> --clone=false

# Clone or update
if [ -d ~/workspace/archive/<repo-name> ]; then
  cd ~/workspace/archive/<repo-name>
  git fetch origin && git checkout main && git pull origin main
else
  gh repo clone <owner/repo> ~/workspace/archive/<repo-name>
  cd ~/workspace/archive/<repo-name>
fi

# Create fix branch
git checkout -b fix/<issue-slug>
```

---

## Phase 3: GENERATE THE FIX (via Codex Agent)

Use the Agent tool with `subagent_type: "codex:codex-rescue"` to generate the fix:

```
Fix the bug described in GitHub issue #<N> in the repo at ~/workspace/archive/<repo-name>:

<paste issue title and key details>

Affected file(s): <file:line from the issue>

Requirements:
1. Make the minimal change needed to fix the bug
2. Do not refactor surrounding code
3. Follow the repo's existing code style
4. Add a comment only if the fix is non-obvious
5. Keep the change under 100 lines
```

After Codex completes, verify the change via Bash:
```bash
cd ~/workspace/archive/<repo-name>
git diff --stat
git diff
```

If the diff is >100 lines or touches unrelated files, reject and try a more focused prompt.

---

## Phase 4: VERIFY THE FIX

### Run tests via Bash

```bash
cd ~/workspace/archive/<repo-name>

# Auto-detect and run
if [ -f go.mod ]; then go test ./... 2>&1 | tail -20; fi
if [ -f package.json ]; then npm install && npm test 2>&1 | tail -20; fi
if [ -f pytest.ini ] || [ -f pyproject.toml ]; then pytest --tb=short -q 2>&1 | tail -20; fi
if [ -f Cargo.toml ]; then cargo test 2>&1 | tail -20; fi
```

### Codex review of the fix

Use the Agent tool with `subagent_type: "codex:codex-rescue"`:

```
Review this git diff in ~/workspace/archive/<repo-name> for correctness.
Does it actually fix the reported bug? Does it introduce any new bugs or break existing behavior?
Output: PASS or FAIL with reason.
```

If tests fail or review says FAIL -> abort, do not submit PR. Report the failure.

---

## Phase 5: COMMIT AND PUSH

```bash
cd ~/workspace/archive/<repo-name>
git add <changed-files>
git commit -m "fix(<scope>): <concise description>

Fixes <owner/repo>#<issue-number>

<one-line explanation of what was wrong and how this fixes it>"

git push origin fix/<issue-slug>
```

---

## Phase 6: CREATE PULL REQUEST

The PR should be "boring" — minimal, focused, easy to review. No internal jargon.

```bash
gh pr create \
  --repo <owner/repo> \
  --title "fix(<scope>): <description>" \
  --body "$(cat <<'EOF'
## Summary

Fixes #<issue-number>

<2-3 sentence description of the bug and how this PR fixes it>

## Changes

- `<file>`: <what was changed and why>

## Testing

- [x] Existing tests pass
- [x] Fix verified via code review

## Notes

Minimal fix — no unrelated changes included.
If you'd like any adjustments to match project conventions, happy to update.
EOF
)"
```

---

## Phase 7: REPORT

Output:
- Issue URL -> PR URL
- Files changed (with line counts)
- Test results (PASS/FAIL/SKIP)
- Review verdict
- Any warnings or caveats

---

## Rules

1. **Only fix confirmed bugs** — don't submit PRs for speculative issues
2. **Keep changes small** — under 100 lines, focused on the bug
3. **Use Codex via Agent tool** — `subagent_type: "codex:codex-rescue"`
4. **Run tests before submitting** — if tests exist and fail, abort
5. **Link PR to issue** — always include `Fixes #N`
6. **Conventional commits** — `fix(<scope>): <description>`
7. **One fix per PR** — don't bundle multiple fixes
8. **No jargon** — PR reads as if a normal engineer submitted it

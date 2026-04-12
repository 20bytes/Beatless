---
description: "Audit, clean, research, and write blog posts at ~/blog/. Uses Codex CLI + Gemini CLI for quality review."
---

# Blog Maintenance Pipeline

Autonomous pipeline: audit existing posts → research trending topics → write new posts → verify build + triple review.

## Execution Model

**CRITICAL**: Do NOT use `/codex:review` or `/gemini:consult` slash commands — they don't work in `--print` mode. Instead, call CLIs directly via Bash:

```bash
# Codex review (read-only)
cd ~/blog && codex --approval-mode full-auto --quiet "<review prompt>"

# Gemini research (1M context)
gemini -p "<research prompt>"
```

## Context

- Blog directory: `~/blog/` (Astro site, MDX format)
- Content path: `~/blog/src/content/blogs/<slug>/index.mdx`
- Build command: `cd ~/blog && pnpm build`
- Author: CS PhD, focus on AI/ML, EEG/BCI, agent systems
- GitHub account: CrepuscularIRIS

## Phase 1: AUDIT (existing posts)

Read all posts in `~/blog/src/content/blogs/*/index.mdx`.

Classify each post:
- **KEEP**: >800 words, has code examples, well-structured, original content
- **REWRITE**: Good topic but poor execution — too short, missing depth, auto-generated feel
- **DRAFT**: Low-value filler, placeholder, auto-digest with no substance → set `isDraft: true`

Keep audit results in context for Phase 3.

## Phase 2: RESEARCH (trending topics via Gemini CLI)

Use Gemini CLI directly for research:

**Category A: AI Thought Leaders & Technical Reports**
```bash
gemini -p "Find the latest from these sources in the last 2 weeks:
1. Andrej Karpathy — blog posts, YouTube videos, X/Twitter threads
2. Anthropic — CAI training reports, Claude system card updates, research papers
3. OpenAI — o-series technical reports, system prompts reveals, safety papers
4. Google DeepMind — Gemini architecture papers, AlphaProof updates
5. Key industry interviews — Dario Amodei, Sam Altman, Demis Hassabis
For each: source URL, key quotes/insights, suggested blog angle."
```

**Category B: Flagship Model Architecture & Training**
```bash
gemini -p "Research the latest technical details about flagship model architectures:
1. Claude's Constitutional AI training methodology
2. GPT/o-series chain-of-thought reasoning
3. Gemini's multimodal architecture and long-context
4. DeepSeek's MoE architecture
For each: key architectural insight, how it differs from competitors."
```

**Category C: Agent Engineering**
```bash
gemini -p "Most impactful developments in AI agent frameworks in the last 2 weeks? Focus on: MCP protocol, Claude Code / Codex / Gemini CLI patterns, autonomous coding agents, multi-agent orchestration. For each: title, key technical insight, practical code pattern."
```

**Category D: BCI/Neuroscience**
```bash
gemini -p "Search arXiv for the most discussed papers in brain-computer interfaces, neural decoding, EEG/fMRI from the last 14 days. List top 5 with title, key contribution, and blog post potential."
```

Select top 3 topics across all categories.
**Priority**: adapt/summarize existing high-quality content (Karpathy blogs, Anthropic reports, technical papers) rather than writing from scratch.

## Phase 3: WRITE

### New posts (write 2)

For each of the top 2 research topics:

1. Create directory: `~/blog/src/content/blogs/<slug>/`
2. Write `index.mdx` with frontmatter:
   ```yaml
   ---
   title: "<title>"
   description: "<one-line hook>"
   pubDate: "<today YYYY-MM-DD>"
   tags: [<relevant tags>]
   isDraft: false
   ---
   ```
3. Write 1500+ words of high-quality content:
   - Introduction with concrete hook (not "In this post we will...")
   - Technical depth with working code examples
   - Personal perspective or unique analysis angle
   - Practical takeaways
   - References with real URLs

4. Writing quality rules:
   - NO AI filler: avoid "Let's dive in", "In conclusion", "It's worth noting"
   - Use direct statements, specific numbers, concrete examples
   - Code blocks must be syntactically correct and runnable

### Rewrite (pick 1 from audit)

If any posts were classified REWRITE:
- Pick the one with the best topic potential
- Rewrite with deeper analysis, better structure, code examples
- Keep the same slug

### Draft cleanup

For posts classified DRAFT:
- Set `isDraft: true` in frontmatter if not already set
- Don't delete (user preference: ASK before deleting)

## Phase 4: VERIFY

### Build check
```bash
cd ~/blog && pnpm build
```
Must exit 0. If build fails, fix the issue.

### Quality review via Codex CLI (triple check)

```bash
cd ~/blog && codex --approval-mode full-auto --quiet \
  "Review the recently changed blog posts in src/content/blogs/. Check for:
   1. Technical accuracy — are claims correct?
   2. Grammar and clarity — any awkward phrasing?
   3. Code example correctness — do they compile/run?
   4. Broken links or references
   Output a quality score 1-10 per post and specific issues found."
```

### Architecture review via Gemini CLI

```bash
cd ~/blog && gemini -p \
  "Review the blog content quality in src/content/blogs/. Check the most recent posts for:
   1. Are the topics timely and relevant?
   2. Is the technical depth sufficient for a PhD-level audience?
   3. Are there any factual errors or misleading claims?
   4. Quality score 1-10 per post."
```

### Commit

If build passes and reviews are acceptable:
```bash
cd ~/blog && git add src/content/blogs/ && git commit -m "content: blog maintenance — new posts and cleanup"
```

Do NOT push unless explicitly asked.

## Phase 5: REPORT

Output a summary:
- Posts audited (total, KEEP/REWRITE/DRAFT counts)
- New posts written (slugs + topics + word counts)
- Posts rewritten (slugs)
- Posts marked as draft (slugs)
- Build status (PASS/FAIL)
- Codex review score
- Gemini review score
- Paths to all modified files

## Rules

- NEVER delete a blog post — mark as draft at most
- NEVER push to remote without explicit user request
- NEVER invent citations — use Gemini CLI to verify URLs exist
- If `pnpm build` fails, fix the error before committing
- All posts must be in MDX format with valid frontmatter
- **Use Bash to call `codex` and `gemini` CLI directly** — not plugin slash commands
- Report progress after each phase

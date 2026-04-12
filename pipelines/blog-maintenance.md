---
description: "Audit, clean, research, and write blog posts at ~/blog/. Uses AgentTeam+Codex+Gemini for quality."
---

# Blog Maintenance Pipeline

Autonomous pipeline: audit existing posts → research trending topics → write new posts → verify build.

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

Write audit report (don't save to file, keep in context for Phase 3).

## Phase 2: RESEARCH (trending topics)

Use `/gemini:consult` to research topics in these categories:

**Category A: AI Thought Leaders & Technical Reports**
```
/gemini:consult "Find the latest from these sources in the last 2 weeks:
1. Andrej Karpathy — blog posts, YouTube videos, X/Twitter threads
2. Anthropic — CAI (Constitutional AI) training reports, Claude system card updates, research papers
3. OpenAI — o-series technical reports, system prompts reveals, safety papers
4. Google DeepMind — Gemini architecture papers, AlphaProof/AlphaCode updates
5. Key industry interviews — Dario Amodei, Sam Altman, Demis Hassabis, Ilya Sutskever
For each: source URL, key quotes/insights, suggested blog angle. Prioritize deep technical content over announcements."
```

**Category B: Flagship Model Architecture & Training**
```
/gemini:consult "Research the latest technical details about flagship model architectures:
1. Claude's Constitutional AI training methodology and RLHF/RLAIF pipeline
2. GPT/o-series chain-of-thought and reasoning architecture
3. Gemini's multimodal architecture and long-context innovations
4. Kimi's 200K+ context window implementation
5. DeepSeek's MoE architecture and training efficiency
For each: key architectural insight, training methodology, how it differs from competitors."
```

**Category C: Agent Engineering & Practical Patterns**
```
/gemini:consult "What are the most impactful developments in AI agent frameworks in the last 2 weeks? Focus on: MCP protocol, Claude Code / Codex / Gemini CLI patterns, autonomous coding agents, multi-agent orchestration, tool-use innovations. For each: title, key technical insight, practical code pattern."
```

**Category D: BCI/Neuroscience (author's research domain)**
```
/gemini:consult "Search arXiv for the most discussed papers in brain-computer interfaces, neural decoding, EEG/fMRI analysis from the last 14 days. List top 5 with title, key contribution, and blog post potential."
```

Combine and rank topics. Select top 3 across all categories.
**Priority**: adapt/summarize existing high-quality content (Karpathy blogs, Anthropic reports, technical papers) rather than writing from scratch. The blog should feel like curated expert analysis, not AI-generated filler.

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
   - References with real URLs (verify via Gemini or web search)

4. Writing quality rules:
   - NO AI filler: avoid "Let's dive in", "In conclusion", "It's worth noting"
   - Use direct statements, specific numbers, concrete examples
   - Code blocks must be syntactically correct and runnable
   - Each section should teach something specific

### Rewrite (pick 1 from audit)

If any posts were classified REWRITE:
- Pick the one with the best topic potential
- Read existing content
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
Must exit 0. If build fails, fix the issue (usually frontmatter or MDX syntax).

### Quality review (triple check)

Run all three reviews on the blog repo:

```
/codex:review --wait
```
Check for: technical accuracy, grammar, code correctness, broken links.

```
/gemini:review --wait
```
Second opinion on content quality with Gemini's 1M context.

```
/codex:adversarial-review --wait
```
Challenge the writing choices — are the claims substantiated? Are code examples actually correct?

### Commit

If build passes and review is acceptable:
```bash
cd ~/blog && git add src/content/blogs/ && git commit -m "content: add new blog posts and audit existing"
```

Do NOT push unless explicitly asked.

## Phase 5: REPORT

Output a summary:
- Posts audited (total, KEEP/REWRITE/DRAFT counts)
- New posts written (slugs + topics + word counts)
- Posts rewritten (slugs)
- Posts marked as draft (slugs)
- Build status (PASS/FAIL)
- Codex review verdict
- Paths to all modified files

## Rules

- NEVER delete a blog post — mark as draft at most
- NEVER push to remote without explicit user request
- NEVER invent citations — use Gemini to verify URLs exist
- If `pnpm build` fails, fix the error before committing
- All posts must be in MDX format with valid frontmatter
- Report progress after each phase

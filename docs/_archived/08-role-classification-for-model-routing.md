# Role Classification For Model Routing

This file is documentation only. It is outside runtime protocol loading.

## Rule
- Any step that dispatches tasks, calls subagents, or publishes downstream prompts is **orchestration**.
- Any step that directly implements/tests/writes artifacts without dispatch is **execution**.

## Pure Orchestration
- `lacia`
- `snowdrop` (controller behavior)

## Pure Execution
- `methode`
- `satonus`
- `claude-architect-sonnet` (fallback executor)

## Mixed (can orchestrate and execute depending on step)
- `kouka`
- `codex-builder`
- `gemini-researcher`
- `claude-generalist`
- `claude-architect-opus`

## Notes
- Classification is used for model routing and policy design.
- It should not be treated as a hard runtime control unless explicitly added back into protocol files.

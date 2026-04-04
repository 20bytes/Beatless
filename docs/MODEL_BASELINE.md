# OpenClaw 模型配置基线（V2）

本文档用于固定当前双模型策略，并作为后续调试基线。

## 1) 主模型（OpenClaw Main Agents）

- 适用对象：`lacia` / `methode` / `kouka` / `snowdrop` / `satonus`
- 统一模型：`stepfun/step-3.5-flash`
- 目的：保证 5 个主 Agent 的推理行为一致，降低跨 Agent 漂移。

## 2) ClaudeCode AgentTeams 模型

- 适用对象：AgentTeams 相关任务（`team-feature` / `team-debug` / `team-review` / `team-spawn` 等）
- 统一模型：`Kimi K2.5`
- 落地方式：
  - `~/.claude/settings.json` 使用 `ANTHROPIC_MODEL = "kimi k2.5"`
  - AgentTeams 插件内 `team-lead` / `team-implementer` / `team-reviewer` / `team-debugger` 使用 `model: inherit`
- 目的：避免 AgentTeams 回退到 Sonnet/Opus，统一到 K2.5。

## 3) Skills 与 Heartbeat

- Skills 执行跟随当前 Agent 模型；在 OpenClaw 主链路即 `step-3.5-flash`。
- Heartbeat 统一设置为 `30m`（全体 Main Agents）。
- Skills 采用“受控启用”策略：
  - 启用核心开发与安全技能（如 `coding-agent`, `tmux`, `github`, `gh-issues`, `anti-injection-skill`, `security-audit`, `healthcheck` 等）
  - 关闭高冲突/高噪音/缺依赖技能，避免链路抖动。

## 4) 当前原则

- 先稳定，再扩容：优先保证 8 小时闭环稳定。
- 能力加法要经过冲突扫描（allowlist、依赖、路由重叠、权限面）。
- 所有模型改动必须同步更新配置快照（Beatless）。

## 5) 是否需要“每个 Agent 每个模块单独模型”

结论：当前阶段**不建议**做到“每个模块一个模型”。

- 5 个 Main Agent 的日常推理统一 `step-3.5-flash` 已足够，能显著降低调试复杂度与漂移风险。
- 仅在高复杂并行构建（AgentTeams）场景切到 `Kimi K2.5`，这是唯一保留的专门化分流。

建议按功能分层，而不是按文件/模块分层：

- `规划 / 调度 / 记忆 / 常规技能`: `step-3.5-flash`
- `AgentTeams 并行开发与复杂 build`: `Kimi K2.5`（通过 ClaudeCode `model: inherit` 继承）
- `审查与二次验证`: 保持现有 Codex review lane，不额外增加 Main Agent 模型分叉

这样可以保持 Harness 稳定，同时保留必要的能力差异。

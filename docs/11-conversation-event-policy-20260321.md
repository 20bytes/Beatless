# Conversation Phrase Placement Policy (2026-03-21)

## Decision
日常话术（寒暄、安抚、欢迎语、晚安等）应放在 **Event 层**，不应放在 `SOUL.md`。

## Why
- `SOUL.md` 的职责是稳定人格边界与行为原则，不是渠道回复模板。
- 日常话术属于渠道行为策略，具有高频可变性，适合事件配置或技能模板。
- 将话术放进 Soul 会放大上下文负担，拖慢每轮推理。

## Placement Rule
- `SOUL.md`: 只保留身份、边界、风格、禁区（稳定、低频变更）。
- `AGENTS.md`: 只保留执行规则和输出契约（协议层）。
- Event/Skill 层: ACK、heartbeat 文案、渠道回执模板、节假日/时段问候。

## Suggested Implementation
1. 新建事件模板文件（建议）
- `~/.openclaw/beatless/templates/event-phrases.yaml`
- 按 `event_type` 管理：`ack`, `heartbeat`, `final_receipt`, `smalltalk`。

2. 网关/调度脚本只做选择，不做文本硬编码
- 入口仅发 ACK 模板。
- 完结仅发 receipt schema 模板。
- 非任务消息走 `smalltalk` 模板池。

3. 保持硬约束
- 禁止输出过程调试文本到飞书。
- ACK 与 final receipt 分离，避免双 ACK 与中间噪声。

## Migration Note
`/home/yarizakurahime/claw/Conversation.md` 中可复用词条应迁移到事件模板，不应继续注入到 Soul/User/Memory/AGENTS。

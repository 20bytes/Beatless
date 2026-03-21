# [V2 ALIGNED] Smoke Prompts (RawCli V2)

Use these prompts in Feishu to validate end-to-end behavior after config updates.

## Prompt 1: Full V2 chain

Lacia，执行 RawCli-V2-Full-Smoke。
按 V2 协议执行：
1) 启动读取 USER_SOUL -> MEMORY -> TASKS；
2) 执行 heartbeat_check、queue_cycle、quality_gate；
3) 做四类路由验证：
- 开源复现/GitHub检索 -> `codex_cli`
- 学术推理 -> `gemini_cli`
- 架构边界/回滚 -> `claude_architect_opus_cli`
- 日常开发 -> `claude_generalist_cli`
4) 输出 DONE/DOING/BLOCKED/NEXT + VERDICT；
5) 落盘报告到 Report。

## Prompt 2: Queue consistency check

Lacia，执行 Queue-Consistency-Smoke。
要求：
1) 运行 queue_cycle；
2) 回报 queues 与 tasks.status 的计数是否一致；
3) 如不一致，输出 BLOCKED 并给修复建议。

## Prompt 3: Receipt and replay

Lacia，执行 Receipt-Replay-Smoke。
要求：
1) 生成最小报告并尝试飞书回执；
2) 失败时进入 pending-delivery；
3) 触发 replay 并回报 delivered 状态；
4) 输出 DONE/DOING/BLOCKED/NEXT + VERDICT。

## Prompt 4: Task discovery + scoring

Lacia，执行 Task-Discovery-Scoring-Smoke。
要求：
1) 运行 task_discovery_minimal + task_value_score + queue_cycle；
2) 回报本轮新增任务数；
3) 回报 backlog top 候选及其 value_score；
4) 输出 DONE/DOING/BLOCKED/NEXT + VERDICT，并落盘报告。

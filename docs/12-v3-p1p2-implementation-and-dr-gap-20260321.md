# Beatless V3 P1/P2 落地与 DR 对照（2026-03-21）

## Scope
本次根据 `Opus/packages/beatless-v3-p1p2-deliverable.md` 落地 P1（must）与 P2（scaffold），并对照三份 DeepResearch 报告做完成度评估。

## P1 已落地
1. `scripts/rawcli/mode_switch_gate.sh`
- 新增运行模式决策（daily/stressed/degraded）。
- 基于 fail_rate/queue_depth/consecutive_failures/receipt_pass_rate 切换，并写入 `/tmp/beatless_exec_mode`。

2. `scripts/rawcli/rawcli_supervisor.sh`
- 在主循环中接入 `mode_switch_gate`。
- 根据 mode 动态调整并发（4/2/1）并重启 hooks 生效。

3. `scripts/rawcli/rawcli_metrics_rollup.sh`
- 扩展指标：`receipt_pass_rate`、`queue_saturation_pct`、`mode`、`context_tokens_per_task`、`anthropic_calls_today`。
- 输出 JSON/Prometheus/Markdown 同步更新。

4. `scripts/rawcli/budget_gate.sh`
- 新增 Anthropic 日预算门控（Opus/Sonnet）。
- `dispatch_hook_loop.sh` 已接入 budget gate（预算超限自动降级 tool）。

5. CI 合约校验
- 新增 `scripts/ci/validate_routing_contracts.sh`。
- 新增 `scripts/ci/validate_receipt_contracts.sh`。
- 工作流 `.github/workflows/rawcli-governance.yml` 已接入 routing/receipt 合约校验。

6. TASKS v4→v5 迁移脚本
- 新增 `scripts/rawcli/migrate_tasks_v4_to_v5.sh`。
- 增补字段：`exec_mode`、`phase`、`run_id`、`iteration`。

## P2 已落地（脚手架）
1. `scripts/rawcli/backlog_groomer.sh`
2. `scripts/rawcli/postmortem_template.sh`
3. `scripts/ci/replay_runner.sh`
4. `scripts/ci/fixtures/replay/sample-daily.jsonl`
5. `scripts/ci/fixtures/replay/receipt-replay-001.md`
6. `scripts/rawcli/cross_model_critic.sh`

说明：P2 当前为可执行脚手架，已具备最小调用链路与文件约定，但未全面接入主运行路径（符合 deliverable 的 SHOULD 目标）。

## 补充硬化
1. `scripts/rawcli/dispatch_hook_loop.sh`
- 并发上限控制（`DISPATCH_MAX_PARALLEL`）。
- 失败分类（timeout/network/auth/runtime/validation）。
- 分类重试矩阵 + 指数退避。
- `(run_id, task_id, phase)` 幂等跳过。
- output 校验（`expect_regex` / `expect_exact_line`）。

2. `scripts/rawcli/dispatch_submit.sh`
- 支持：`expect_regex`、`expect_exact_line`、`model_override`、`run_id`、`phase`。

3. `scripts/rawcli/receipt_schema_gate.sh`
- 强化：调试文本、堆栈、内部路径、跨 run 引用拦截。

## 验证结果
已在仓库内执行并通过：
- `python3 scripts/ci/validate_rawcli_contracts.py`
- `bash scripts/ci/validate_routing_contracts.sh`
- `bash scripts/ci/validate_receipt_contracts.sh`
- `bash scripts/ci/test_receipt_schema_gate.sh`
- `bash scripts/ci/replay_runner.sh scripts/ci/fixtures/replay/sample-daily.jsonl`

## 与 3 份 DeepResearch 对照

### DR-1: Beatless Lacia 工作流方法研究（GPT-5.4）
- 已完成
  - RawCli-first + queue/result 事件驱动增强。
  - 失败分类与重试策略（dispatch hook）。
  - runtime 状态机降级（mode switch + dynamic parallel）。
  - receipt 合规门禁与调试文本拦截。
- 部分完成
  - Orchestrator-Worker 全流程产品化（当前已具备基础路由与脚手架，未完成完整多 agent 编排产品层）。
  - 指标体系 FRCR/ZLV 等对外可视化（当前有本地 metrics，未完成统一告警面板）。
- 未完成
  - 完整 Ralph Loop 专用工具链/独立 wrapper 脚本体系（本次未新增专用 ralph loop cli）。

### DR-2: Lacia 持续自迭代工作流（Gemini）
- 已完成
  - Queue contract（run_id/phase/idempotency）
  - ACK/最终回执解耦方向对应的 schema gate 与 output discipline
  - mode degrade / restore 主循环控制
- 部分完成
  - 上下文熵治理（提供 v5 字段与脚手架，但未完成全量 compaction policy 自动执行）
  - AgentTeam 并行控制（已做并发闸门，未完成全流程 orchestrator ledger）
- 未完成
  - 全链路 Feishu 事件层自动话术/事件模板闭环（本次不在 P1/P2 交付范围）

### DR-3: compass artifact（Opus 推荐）
- 已完成
  - PCE/Reflexion 所需关键底座：mode gate、budget gate、receipt gate、replay fixtures。
  - 跨模型 critic 脚手架（`cross_model_critic.sh`）。
- 部分完成
  - PCE 主流程仍以“脚手架+现有路由”形态存在，尚未形成完整 Planner-Critic-Executor 产品闭环。
  - Dual-loop（outer/inner ledger）未全量实现，仅完成可复用组件。
- 未完成
  - 大规模自动实验编排（3 组实验自动跑批）尚未接入 CI/cron。

## 结论
本次 P1 已可运行并通过校验；P2 已完成脚手架并可继续向“全自动 PCE/Dual-loop”推进。当前系统已具备稳定运行底座，但 DR 中“完整自治编排产品化”仍需后续阶段实施。

# Beatless 当前架构（RawCli V2 Hardened）

Updated: 2026-03-20 (Asia/Shanghai)

## 1. 总体形态
Beatless 当前采用「5 Core Agent + 4 RawCli Tool Pool + tmux dispatch hook」架构。
目标是把“决策”和“执行”拆开：
- 决策由 core agent 负责（owner_agent）
- 执行由 raw cli tool 负责（executor_tool）

## 2. Core Agent 层（任务所有权）
- `lacia`: 总调度/收敛/回执
- `kouka`: 快速响应与应急
- `methode`: 日常开发执行与整合
- `satonus`: 评审与裁决
- `snowdrop`: 探索与发散

## 3. RawCli Tool Pool（执行层）
- `codex_cli`: 开源检索/复杂代码/疑难复现
- `claude_sonnet_cli`: 日常前后端/API开发
- `claude_opus_cli`: 架构边界/回滚/高复杂重构
- `gemini_cli`: 学术推理/证明/第一性分析

## 4. 路由与调度合同
- 路由单一合同: `owner_agent + executor_tool`
- 工具定义单一真相源: `TOOL_POOL.yaml`
- 执行入口: `dispatch-queue.jsonl`
- 执行结果: `dispatch-results/<task_id>.json`

## 5. 运行时链路
1. Feishu 消息进入 `lacia`。
2. 入口 ACK 先返回（两行合同）：
   - `ACK_RECEIVED`
   - `task_id: <id>`
3. `executor_tool != null` 时入队 dispatch。
4. tmux hook 读取 queue，创建独立 pane 执行 CLI。
5. 结果写回 result json + cli 输出文件。
6. 最终回执发送前经过 schema gate 校验。

## 6. 治理机制（已落地）
- 入口 ACK 脚本化：`rawcli_ingress_ack_submit.sh`
- 回执结构门禁：`receipt_schema_gate.sh`
- dispatch 输出校验：`expect_regex` / `expect_exact_line`
- 输出硬约束：禁止调试元数据与过程叙述外泄

## 7. 证据与路径约定
- 主证据目录：`/home/yarizakurahime/claw/Report/`
- ACK 证据：`Report/acks/`
- CLI 输出：`Report/<task_id>-cli-output.md`
- 回执草稿：`Report/receipts/<task_id>.md`

## 8. 当前边界
当前版本已具备 RawCli 主干能力，但“理想形态”仍差三块：
1. 运行时硬化（故障分类、健康检查、稳定重启）
2. 可观测性（统一指标与主动告警）
3. 自动化治理（CI 强制 owner/executor 与 hook 合同）

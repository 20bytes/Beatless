# Beatless TODO (Gap to Ideal)

Updated: 2026-03-20 (Asia/Shanghai)
Owner: CrepuscularIRIS

## P0: 运行时硬化（未完成）
1. 完整故障分类 + 重试矩阵
- 目标: `dispatch_hook_loop.sh` 输出 `failure_type` + `provider_error_code`，并按类型执行差异化重试。
- 验收:
  - `auth_error` 不重试
  - `timeout/network` 有限重试
  - `cli_argument_error` 直接失败并回执

2. 健康检查与稳定重启收敛
- 目标: supervisor 不仅检查进程在，还检查“队列可消费 + 结果可写 + hook 延迟阈值”。
- 验收:
  - 连续异常触发自动重启并写明原因
  - 重启后 1 个心跳周期内恢复可用

## P0: 可观测性（未完成）
3. 统一指标与告警出站
- 目标: 指标不只落盘，critical 告警主动推送到飞书。
- 验收:
  - 指标最少包含: ack_latency、dispatch_duration、fail_rate、queue_depth
  - critical 告警含 task_id、severity、证据路径
  - 告警具备 cooldown + dedup

4. 端到端追踪ID链路
- 目标: `task_id` 在 ingress/dispatch/result/receipt 全链一致可追。
- 验收:
  - 任意回执都可反查到 queue 记录与 cli 输出文件

## P0: 自动化治理（未完成）
5. CI 强制校验 owner/executor 与 hook 兼容
- 目标: 任何配置漂移在 CI 直接阻断。
- 验收:
  - `ROUTING.yaml` 规则字段校验
  - `TOOL_POOL.yaml` 工具合同校验
  - queue->hook->result 的 fixture 回放测试

6. 回执 schema gate CI 化
- 目标: 回执格式约束从“运行时脚本”升级到“仓库测试门禁”。
- 验收:
  - 合法/非法回执样例测试
  - 非法样例必须失败

## P1: 体验与稳定性（未完成）
7. Codex 本地状态迁移清理
- 目标: 消除 sqlite migration 警告，降低噪声与误判。

8. 截图与网页阅读证据统一
- 目标: 用户侧统一展示 `Report/screenshots`，镜像路径仅内部使用。

---

## 已完成（作为基线，不再重复返工）
- 5 core agents + 4 RawCli tool pool
- owner_agent / executor_tool 双字段路由
- tmux dispatch hook 事件驱动执行
- 入口 ACK 脚本化（可直接产出两行 ACK）
- 回执 schema gate 脚本落地
- dispatch 输出期望校验（expect_regex / expect_exact_line）

# [V2 ALIGNED] Beatless 架构蓝图（RawCli V2）

Updated: 2026-03-21

## 1. 目标

Beatless 在 OpenClaw 内的目标：

1. 入口统一：飞书只进入 `lacia`
2. 分工稳定：5 core agent 职责边界清晰
3. 执行直连：RawCli 工具池统一执行，不走 wrapper 嵌套
4. 长时可控：可追踪、可回放、可回滚
5. 高风险可降级：失败分类明确，禁止伪完成

---

## 2. 核心拓扑

当前设计采用 `5 core agents + RawCli tool pool + tmux dispatch hook`：

1. Core Agents（任务所有权）
- `lacia`：入口、路由、收敛、回执
- `methode`：主执行
- `satonus`：评审与验收
- `kouka`：快速/应急通道
- `snowdrop`：探索与发散控制

2. RawCli Tools（命令执行权）
- `codex_cli`：复杂代码/检索/复现
- `claude_generalist_cli`：日常开发
- `claude_architect_opus_cli`：高复杂架构设计
- `gemini_cli`：学术推理与第一性分析

3. 调度主链

`ingress -> route_task -> owner_agent + executor_tool -> dispatch-queue.jsonl -> tmux hook -> dispatch-results -> receipt`

---

## 3. 角色职责边界

## 3.1 lacia

负责：
- 接收飞书消息
- 生成 ACK（两行）
- 路由为 `owner_agent + executor_tool`
- 汇总结果并输出最终回执

不负责：
- 长时直接编码
- 无证据宣称完成

## 3.2 methode

负责：
- 代码实现、修复、联调
- 产出可复现结果与证据
- 复杂任务 dispatch 到 `codex_cli`

不负责：
- 绕过 satonus 质量门禁

## 3.3 satonus

负责：
- 验收与裁决
- 证据一致性与回执质量审查

不负责：
- 代替执行与路线决策

## 3.4 kouka / snowdrop

- `kouka`：应急止血、快入快出（超范围即升级工具执行）
- `snowdrop`：探索任务，Phase-B 并行 `codex_cli + gemini_cli`

---

## 4. SSOT 与状态面

单一事实源：
- `~/.openclaw/beatless/TASKS.yaml`
- `~/.openclaw/beatless/ROUTING.yaml`
- `~/.openclaw/beatless/TOOL_POOL.yaml`

长期记忆与规则：
- `~/.openclaw/beatless/MEMORY.md`
- `~/.openclaw/beatless/QUALITY_GATES.md`

任务输出必须写 `DONE/DOING/BLOCKED/NEXT + VERDICT`，禁止口头完成。

---

## 5. 任务状态机（建议）

`backlog -> ready -> in_progress -> review -> done`

异常分支：
- `in_progress -> blocked`
- `review -> ready`
- 任意状态 -> `cancelled`

最小字段：

```yaml
id: BT-20260321-001
title: "任务标题"
priority: high
status: ready
owner_agent: methode
executor_tool: codex_cli
acceptance_criteria:
  - "..."
outputs: []
notes: ""
```

---

## 6. 长时运行策略

1. ACK 快速返回（目标 < 3s）
2. 执行与回执解耦（队列化）
3. 失败分型（timeout/network/auth/cli-arg）
4. 证据先于结论

汇报模板：

```text
[时间] 2026-03-21 12:00 GMT+8
[任务ID] ...
[DONE] ...
[DOING] ...
[BLOCKED] ...
[NEXT] ...
[VERDICT] PASS|PARTIAL|FAIL
```

---

## 7. 防跑偏规则

1. 无证据不可报完成
2. 不允许 agent 名与 model 名混用
3. 路由使用 `owner_agent + executor_tool` 双字段
4. 过程调试文本不得进入飞书回执

---

## 8. 启动与检查

```bash
bash /home/yarizakurahime/claw/Beatless/scripts/setup_openclaw_beatless.sh
```

```bash
jq '.agents.list[].id' ~/.openclaw/openclaw.json
jq '.bindings' ~/.openclaw/openclaw.json
```

应看到：
- 5 core agents
- Feishu 绑定仅 `lacia`

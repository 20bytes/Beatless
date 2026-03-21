# [V2 ALIGNED] Beatless 测试与验收清单

Updated: 2026-03-21

## A. 基础可用性

1. Gateway 运行
- [ ] `127.0.0.1:18789` 在监听

2. Agent 拓扑
- [ ] `lacia/methode/satonus/kouka/snowdrop` 存在
- [ ] `agents.defaults.maxConcurrent = 4`
- [ ] `agents.defaults.subagents.maxConcurrent = 8`

3. 路由与工具合同
- [ ] `ROUTING.yaml` 使用 `owner_agent + executor_tool`
- [ ] `ROUTING.yaml` 中所有 executor_tool 都在 `TOOL_POOL.yaml` 中存在

4. 飞书绑定
- [ ] `bindings` 中 Feishu 对应 `agentId = lacia`

---

## B. 编排可用性

1. 路由测试
- [ ] 飞书任务进入后，`lacia` 返回 ACK
- [ ] dispatch 入队与结果回写正常

2. 分工测试
- [ ] 常规开发 -> `methode` + `claude_generalist_cli`
- [ ] 复杂任务 -> `methode` + `codex_cli`
- [ ] 学术推理 -> `snowdrop`/`lacia` + `gemini_cli`
- [ ] 架构任务 -> `lacia` + `claude_architect_opus_cli`

3. 汇报规范
- [ ] 每轮都有 DONE/DOING/BLOCKED/NEXT
- [ ] BLOCKED 包含失败原因和下一步

---

## C. 长时任务稳定性

1. ACK 时延
- [ ] ACK 平均时延 < 3 秒
- [ ] 不出现双 ACK

2. 回执质量
- [ ] 回执通过 schema gate
- [ ] 飞书输出不含过程调试文本

3. 产物可验收
- [ ] 输出文件路径清单
- [ ] 可复现命令
- [ ] 测试结果与风险说明

---

## D. 一键自检命令

```bash
jq '.agents.defaults,.agents.list[]|{id,model:(.model.primary),subagents:(.subagents.maxConcurrent // "inherit")}' ~/.openclaw/openclaw.json
jq '.bindings' ~/.openclaw/openclaw.json
ss -ltnp | rg 18789
rg -n "owner_agent|executor_tool" ~/.openclaw/beatless/ROUTING.yaml
```

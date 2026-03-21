# [V2 ALIGNED] Beatless Skills 配置与使用手册

Updated: 2026-03-21

## 1. Skills 来源与安装

默认来源：
- `/home/yarizakurahime/claw/openclaw/skills`

常用技能：
- `coding-agent`
- `gemini`
- `github`
- `gh-issues`
- `session-logs`
- `healthcheck`
- `tmux`

目标目录：
- `~/.openclaw/workspace-<agent>/skills/<skill>`

---

## 2. 一次性安装（推荐）

```bash
bash /home/yarizakurahime/claw/Beatless/scripts/setup_openclaw_beatless.sh
```

脚本会：
1. 创建/更新 workspace
2. 同步 skills
3. 写入 AGENTS/SOUL/HEARTBEAT
4. patch `~/.openclaw/openclaw.json`

---

## 3. 手动增删 Skills

## 3.1 增加 skill

```bash
cp -R /home/yarizakurahime/claw/openclaw/skills/my-skill \
  /home/yarizakurahime/.openclaw/workspace-methode/skills/my-skill
```

## 3.2 删除 skill

```bash
rm -rf /home/yarizakurahime/.openclaw/workspace-methode/skills/my-skill
```

## 3.3 批量同步给 5 core agents

```bash
for a in lacia methode satonus kouka snowdrop; do
  mkdir -p /home/yarizakurahime/.openclaw/workspace-$a/skills
  rsync -a --delete /home/yarizakurahime/claw/openclaw/skills/github/ \
    /home/yarizakurahime/.openclaw/workspace-$a/skills/github/
done
```

---

## 4. 角色建议

## 4.1 lacia（编排）
- `session-logs`
- `healthcheck`

## 4.2 methode（执行）
- `coding-agent`
- `github`
- `tmux`

## 4.3 satonus（验收）
- `healthcheck`
- `github`

## 4.4 RawCli 工具职责

- `codex_cli`：复杂编码/检索复现
- `claude_generalist_cli`：日常开发
- `claude_architect_opus_cli`：架构设计
- `gemini_cli`：学术推理

---

## 5. 使用策略

1. 常规开发先走 `methode`
2. 复杂逻辑/疑难 bug 升级 `codex_cli`
3. 外部研究与定理推理走 `gemini_cli`
4. 架构边界与重构设计走 `claude_architect_opus_cli`
5. 所有升级都写回 `TASKS.yaml` 与结果证据

---

## 6. 生效检查

```bash
find ~/.openclaw/workspace-methode/skills -maxdepth 2 -type f -name 'SKILL.md'
```

```bash
jq '.agents.list[] | {id,workspace}' ~/.openclaw/openclaw.json
```

---

## 7. 常见故障

1. `No API key found for provider "kimi-coding"`
- 检查 `~/.openclaw/agents/<agent>/agent/auth-profiles.json`

2. 飞书无回复
- 检查 `bindings.agentId == lacia`
- 检查 gateway 端口 `127.0.0.1:18789`

3. 只口头完成不落地
- 强制 DONE/DOING/BLOCKED/NEXT
- 必须附证据路径与可复现命令

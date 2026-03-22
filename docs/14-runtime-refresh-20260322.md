# Runtime Refresh Report (2026-03-22)

## Scope
- Heartbeat cadence noise reduction
- Closing quiet-hours behavior
- Feishu final receipt tone alignment
- Event phrase pool versioning into Beatless repo

## Delivered
1. Dynamic Heartbeat interval
- Busy: every 30 min
- Idle: every 60 min
- Busy detection conditions:
  - `queue_depth >= 1`, or
  - `queue_lag_p95 >= 15000ms`, or
  - `mode in {stressed, degraded}`
- Runtime file:
  - `~/.openclaw/beatless/scripts/rawcli_supervisor.sh`

2. Closing quiet-hours
- At `END_HOUR` only `HH:00` emits one closing message.
- Remaining time that night stays silent.

3. Feishu final receipt tone
- Success/timeout/failure/no-executor receipt wording aligned to companion style.
- Evidence path and execution details retained.
- Runtime file:
  - `/home/yarizakurahime/claw/openclaw/extensions/feishu/src/bot.ts`

4. Phrase configuration in repo
- Added:
  - `config/rawcli/event-phrases.yaml`

## Validation
- `bash -n ~/.openclaw/beatless/scripts/rawcli_supervisor.sh`
- `pnpm -s vitest run extensions/feishu/src/bot.test.ts` (59 passed)
- Night quiet-hours simulation: no additional heartbeat events after closing slot (`delta=0`)

## Outcome
- Lower chatter in Feishu channel.
- Companion-style delivery remains, but heartbeat now acts as status pulse instead of repeated greeting.
- Runtime and Beatless repo are aligned for this refresh.

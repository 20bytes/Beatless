# Beatless V4 Entropy + Observability

## Runtime Files
- `entropy-policies.yaml`
- `scripts/rawcli/entropy_convergence_gate.sh`
- `scripts/rawcli/context_entropy_compact.sh` (policy-driven thresholds)
- `scripts/rawcli/rawcli_metrics_rollup.sh` (entropy metrics to JSON + Prom)
- `scripts/rawcli/rawcli_supervisor.sh` (per-cycle convergence gate)

## CI Files
- `scripts/ci/validate_entropy_policies.sh`
- `scripts/ci/validate_convergence_ratio.sh`
- `.github/workflows/rawcli-governance.yml` (added two validation steps)

## Prometheus / Grafana
- Prometheus scrape snippet: `config/observability/prometheus.beatless.yml`
- Dashboard JSON: `config/observability/grafana/beatless-dashboard.json`
- Alert rules: `config/observability/grafana/beatless-alerts.yaml`

## Node Exporter Textfile Hook
```bash
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
sudo mkdir -p "$TEXTFILE_DIR"
sudo ln -sf "$HOME/.openclaw/beatless/metrics/rawcli.prom" "$TEXTFILE_DIR/rawcli.prom"
```

## V4 Entropy Metrics
- `rawcli_entropy_idea_count`
- `rawcli_entropy_decision_count`
- `rawcli_entropy_convergence_ratio`
- `rawcli_entropy_explore_blocked`

# Uptime Monitoring (Uptime Kuma)

The stack uses [Uptime Kuma](https://github.com/louislam/uptime-kuma) for synthetics and external availability checks.

## Deployment

- The Uptime Kuma container runs on port `3001`.
- Custom configuration like monitors and notification channels lives in `configs/uptime-kuma-overrides`.
- A Prometheus exporter (`integration/uptime-kuma-exporter.py`) polls the Kuma API and exposes metrics on port `5000`.
- Prometheus scrapes `uptime-kuma-exporter:5000` at 30s intervals by default.

## Defining Monitors

Create or import monitors via the web UI or use the API. Example monitor definitions are provided in
`configs/uptime-kuma-overrides/monitors.yml`.

To import them programmatically:

```sh
export UPTIME_KUMA_URL=http://localhost:3001
export API_KEY="<your-api-token>"
./scripts/manage-uptime-monitors.sh import configs/uptime-kuma-overrides/monitors.yml
```

List existing monitors:

```sh
./scripts/manage-uptime-monitors.sh list
```

## Metrics

Metrics exposed by the exporter include:

- `uptime_monitor_up` – 1 if the check is currently passing, 0 otherwise.
- `uptime_monitor_response_time_ms` – last response time in milliseconds.
- `uptime_monitor_uptime_percent` – 24‑hour uptime percentage.

These metrics are used by Grafana dashboards (`04-uptime-monitoring`) and alert rules (`HighUptimeLatency`, `MonitorDown`, etc.).

## Alerts

Prometheus alert rules for uptime failures are stored in `configs/prometheus-overrides/alert-rules.yml`.

## Testing

- Run `scripts/integration-test.sh`; section `Phase 7` verifies Uptime Kuma metrics are flowing.
- Create a test monitor that points to a non-existent service and ensure an alert fires.

## Retention & Cleanup

Uptime Kuma stores its own history; retention settings are available in the UI under "Backup & Restore". Exported metrics obey Prometheus retention settings.

---

_Last updated: $(date +%Y-%m-%d)_
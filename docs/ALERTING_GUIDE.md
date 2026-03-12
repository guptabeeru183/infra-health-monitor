# Alerting Guide

This document explains how alerts are defined, routed, and handled in the Infra Health Monitor stack.

## Alert Rules
Rules live in `configs/prometheus-overrides/alert-rules.yml`. They are grouped by purpose (system health, monitoring infrastructure, etc.).

- **System resource alerts** cover CPU, memory, disk, network, load, etc.
- **Service availability alerts** use the `up` metric or custom application metrics.
- **Monitoring system alerts** detect failures within Prometheus, Grafana, Alertmanager, etc.
- **Application-specific alerts** are added per-service as needed.

Use `scripts/validate-alert-rules.sh` to check syntax before deploying.

## Alertmanager Configuration
Custom routing and receivers are defined in `configs/alertmanager-overrides/alertmanager.yml`. Secondary templates live alongside it.

Environment variables in `.env` configure webhooks, SMTP credentials, and API keys.

## Notifications
By default three receivers exist:

- `critical-alerts` – used for severity=`critical`
- `warning-alerts` – for severity=`warning`
- `default` – fallback

Receivers can be populated with email, Slack, PagerDuty, or custom webhooks.
See `docs/NOTIFICATION_CHANNELS.md` for details.

## Routing and Inhibition
Rules in the global `route` section determine grouping, wait times, and which receiver to send to. Inhibition rules prevent noise (e.g. suppress warnings when a critical alert is firing).
Modify the configuration in `configs/alertmanager-overrides/alertmanager.yml` and reload Alertmanager (`curl -X POST http://localhost:9093/-/reload`).

## Runbooks
Each alert should include a `runbook_url` annotation linking to a corresponding markdown file in `integration/alert-runbooks`. See `docs/ALERT_RUNBOOKS.md` for list and guidance.

## Testing
Use `scripts/test-alerts.sh` to generate alerts and verify channels. Follow instructions in `docs/ALERT_TESTING.md`.

## Maintenance
- Review alert rules quarterly for relevance.
- Track false positives/negatives and adjust thresholds.
- Update runbooks when procedures change.

_Last updated: $(date +%Y-%m-%d)_
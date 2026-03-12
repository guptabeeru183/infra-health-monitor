# Alert Testing Procedures

This document outlines steps to validate alert rules and notification delivery.

## Syntax Validation
Run:

```sh
./scripts/validate-alert-rules.sh configs/prometheus-overrides/alert-rules.yml
```

This uses `promtool` to check for errors.

## Functional Testing
1. Fire synthetic alerts:
   ```sh
   ./scripts/test-alerts.sh
   ```
2. Verify that the alerts appear under Alertmanager UI (`http://localhost:9093/alerts`).
3. Check that notifications are received on each configured channel (email, Slack, PagerDuty).
4. Use `./scripts/generate-alert-report.sh` to list active alerts and confirm severities.

## Routing & Inhibition
- Create test alerts with different severity labels to ensure routing rules send to correct receivers.
- Test inhibition by firing a critical alert and then a warning with same `alertname` and `service` labels; the warning should be suppressed.

## Maintenance Windows
- Use `./scripts/silence-alert.sh create` to silence alerts during planned maintenance.
- Ensure the silence expires when expected and that alerts resume afterward.

## Regression Testing
Include the alert validation commands in CI or deployment scripts to catch configuration errors before rollout.

_Last updated: $(date +%Y-%m-%d)_
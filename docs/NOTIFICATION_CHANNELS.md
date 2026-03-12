# Notification Channels

Notification delivery is managed by Alertmanager using configured receivers. Supported channels:

## Email
Set SMTP credentials via environment variables (`SMTP_PASSWORD`, etc.).
Use the `email_configs` section in `configs/alertmanager-overrides/alertmanager.yml`. Templates are defined in `email-template.tmpl`.

## Slack
Create a Slack app with incoming webhook and add URL to `.env` (e.g. `SLACK_WEBHOOK_CRITICAL`).
Configure channels per severity in `alertmanager.yml`. Use `slack-template.tmpl` for formatting.

## PagerDuty
If you use PagerDuty, set `PAGERDUTY_SERVICE_KEY` and add a `pagerduty_configs` entry.

## Webhooks / Custom
You can forward alerts to any HTTP endpoint via `webhook_configs`.

## Others
- Telegram: use `telegram_configs` (requires bot token and chat id)
- OpsGenie: `opsgenie_configs`

Each channel should be tested regularly with `scripts/test-alerts.sh`.

_Last updated: $(date +%Y-%m-%d)_
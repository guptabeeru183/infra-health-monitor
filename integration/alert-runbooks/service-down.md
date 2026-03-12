# Service Down Runbook

**Alert**: ServiceDown

## What triggered the alert
A monitored service's `up` metric dropped to 0 for 2 minutes.

## Impact
Users cannot access the affected service; may affect dependent systems.

## How to verify
1. Identify the `job` label of the alert.
2. Check the service logs (e.g., via `docker-compose logs <service>`).
3. Try connecting to the service endpoint manually.

## How to remediate
- Restart the service (`docker-compose restart <service>`).
- Investigate application errors in logs.
- Rollback recent deployments if needed.

## Escalation
If service does not recover in 5 minutes, page the application team.

## Links
- Grafana service dashboard (if available)

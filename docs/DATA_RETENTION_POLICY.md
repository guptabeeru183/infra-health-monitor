# Data Retention Policy

This document outlines default retention settings for the monitoring stack and guidance for overrides.

## Default Retention

| Data Type | Default Duration | Notes |
|-----------|------------------|-------|
| Metrics (Prometheus) | 15 days | Configurable via `PROMETHEUS_RETENTION_TIME`/`SIZE`. Env vars set in compose files. |
| Logs | 30 days | Enforced by logging backend (ClickHouse / Elasticsearch). |
| Traces | 30 days | Backend (ClickHouse) retention setting; adjust in SigNoz or collector config. |
| Dashboards & Config | Indefinite | Managed in git; backups stored on every push. |

### Environment Variable Overrides

Prometheus retention can be adjusted by setting:
```sh
PROMETHEUS_RETENTION_TIME=7d
PROMETHEUS_RETENTION_SIZE=50GB
```
in `.env` or directly in your `docker-compose.*.yml` files. Development stacks use shorter retention (3–7 days).

## Enforcement Mechanisms

- Prometheus honors CLI flags `--storage.tsdb.retention.time` and `--storage.tsdb.retention.size`.
- Netdata retention is controlled via `dbengine disk space` in `configs/netdata-overrides/netdata.conf`.
- ClickHouse retention settings are defined by the backend image; adjust using SQL `ALTER TABLE ... MODIFY TTL` statements.
- Backups (see `scripts/backup-data.sh`) provide a secondary safeguard.

## Backup Strategy

- **Metrics**: periodic snapshots of the Prometheus TSDB (tars of `prometheus-data` volume).
- **Logs/Traces**: ClickHouse table dumps or volume snapshots.
- **Grafana Dashboards**: backed up with `scripts/dashboard-backup.sh` on each git push.

See `docs/BACKUP_RECOVERY.md` for detailed procedures.

## Changing Retention

1. Edit the appropriate configuration (docker-compose env vars or backend settings).
2. Restart the affected service.
3. Monitor disk usage and verify via service-specific metrics (e.g. `prometheus_tsdb_head_series`).
4. Document the change and rationale in the operations log.

## Longer-Term Storage

For data that must live beyond default retention, consider remote write/remote storage options (Thanos/Cortex) or periodic exports to object storage.

---

_Last updated: $(date +%Y-%m-%d)_
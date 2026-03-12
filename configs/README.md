# Configuration Overrides

This directory contains customizations and overrides for upstream monitoring projects.

## Structure

```
configs/
├── dockprom-overrides/       # Overrides for Prometheus, Grafana, Alertmanager
├── netdata-overrides/        # Overrides for Netdata
├── signoz-overrides/         # Overrides for SigNoz and OpenTelemetry Collector
├── uptime-kuma-overrides/    # Overrides for Uptime Kuma
├── prometheus-overrides/     # Additional Prometheus configuration
├── grafana-provisioning/     # Grafana datasources and dashboards provisioning
│   └── datasources/          # Prometheus, SigNoz, and other datasources
└── alertmanager-overrides/   # Alertmanager configuration
```

## Philosophy

**We do not modify upstream projects**. Instead:

1. Upstream code remains in `stack/<project>/` directories (Git submodules)
2. All customizations go in corresponding `configs/<project>-overrides/` directories
3. `docker-compose.yml` references both upstream and override files

## Example: Customizing Prometheus

Instead of modifying `stack/dockprom/prometheus/prometheus.yml`:

1. Create override file: `configs/prometheus-overrides/additional-targets.yml`
2. Reference in docker-compose.yml:
   ```yaml
   volumes:
     - ./stack/dockprom/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
     - ./configs/prometheus-overrides/additional-targets.yml:/etc/prometheus/extra.yml:ro
   ```

## Configuration Files (Phase 2 Setup)

These files will be populated in later phases:

### Phase 3 (Docker Compose)
- `prometheus-overrides/prometheus.yml` - Scrape targets and settings
- `prometheus-overrides/alert-rules.yml` - Alert rules
- `alertmanager-overrides/alertmanager.yml` - Alert routing
- `grafana-provisioning/datasources/datasources.yaml` - Datasource configurations

### Phase 4 (Integration)
- `netdata-overrides/netdata.conf` - Netdata settings
- `signoz-overrides/otel-collector-config.yml` - OpenTelemetry Collector config
- `uptime-kuma-overrides/monitoring.json` - Monitors and configuration

### Phase 5 (Dashboards)
- `grafana-provisioning/dashboards/` - Grafana dashboard JSON files
- `grafana-provisioning/dashboards/provider.yaml` - Dashboard provisioning

## Best Practices

1. **Comment Your Changes**: Include why each customization exists
2. **Minimal Changes**: Only override what's necessary
3. **Version Control**: Keep all overrides in Git
4. **Test Before Deploying**: Validate YAML/JSON syntax
5. **Document Integration Points**: Note where customization ties into main architecture

## Using Configuration Files in Docker Compose

Example mapping from docker-compose.yml:

```yaml
services:
  prometheus:
    volumes:
      # From upstream (read-only)
      - ./stack/dockprom/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      
      # Our customizations (read-only)
      - ./configs/prometheus-overrides/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro
      - ./configs/prometheus-overrides/recording-rules.yml:/etc/prometheus/recording-rules.yml:ro
      
      # Data volume (writable)
      - prometheus-storage:/prometheus
```

## Related Documentation

- [SUBMODULE_GUIDE.md](../docs/SUBMODULE_GUIDE.md) - How to manage upstream projects
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System design and integration points
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Deployment instructions

---

**Note**: Configuration files will be created and populated as we progress through the implementation phases.

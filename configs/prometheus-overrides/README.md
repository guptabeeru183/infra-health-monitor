# Prometheus Configuration - Overrides

This file contains custom Prometheus configuration that augments the base configuration from dockprom.

## Phase 2 Setup

This file will be populated in Phase 3 with:

- Scrape configurations for all targets (Netdata, Uptime Kuma, etc.)
- Service discovery settings
- Metric relabeling rules
- Remote write configuration (if using external storage)
- Query optimization settings

## Reference

- Base configuration: `../../stack/dockprom/prometheus/prometheus.yml`
- Alert rules: `./alert-rules.yml`
- Recording rules: `./recording-rules.yml`

## Integration Points

The docker-compose.yml references both base and override configurations:

```yaml
prometheus:
  volumes:
    - ./stack/dockprom/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - ./configs/prometheus-overrides/prometheus.yml:/etc/prometheus/extra.yml:ro
```

---
Status: Template created in Phase 2
Next: Configuration in Phase 3

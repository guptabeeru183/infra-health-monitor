# SigNoz Configuration - Overrides

Customizations for SigNoz and OpenTelemetry Collector.

## Phase 2 Setup

This directory will contain in Phase 3:

- `otel-collector-config.yml` - OpenTelemetry Collector configuration
- Log receivers and processors
- Trace samplers
- ClickHouse exporter settings

## Reference

- SigNoz source: `../../stack/signoz/`
- SigNoz docs: https://signoz.io/docs/

## Integration

The docker-compose.yml references this configuration:

```yaml
signoz-otel-collector:
  volumes:
    - ./configs/signoz-overrides/otel-collector-config.yml:/etc/otel-collector-config.yml:ro
```

---
Status: Directory stub in Phase 2
Next: Configuration in Phase 3

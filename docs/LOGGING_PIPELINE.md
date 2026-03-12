# Logging Pipeline

This document describes how logs flow through the monitoring stack and how to configure and verify the pipeline.

## Overview

1. **Applications** emit logs using OpenTelemetry (OTLP) or other compatible agents.
2. Logs are received by the **OpenTelemetry Collector** (`otel-collector`) on port `4318` (HTTP) or `4317` (gRPC).
3. The collector processes entries (batching, memory limiting, attribute enrichment) and forwards them to a backend.
   - In the default configuration the collector exports to `logging` for debug and to downstream systems such as SigNoz/ClickHouse once configured.
4. **Prometheus** scrapes collector metrics at `http://otel-collector:8888/metrics` to monitor the pipeline itself.
5. Grafana dashboards consume both application metrics and collector metrics to display log ingestion health.

## Configuration

- See `configs/signoz-overrides/otel-collector-config.yml` for the canonical pipeline definition.
- Ensure the `[logs]` pipeline is enabled and exporters are set to a real backend when running in production.

### Sample log exporter setup (SigNoz)
```yaml
exporters:
  signoz:            # hypothetical exporter
    endpoint: signoz:4317
```

## Testing the Pipeline

- Use `scripts/send-sample-telemetry.sh` to inject a test log entry.
- Run `scripts/integration-test.sh` which now checks for `otelcol_log_records_received` metrics.
- Alternatively query Prometheus directly:

```
curl -s http://localhost:9090/api/v1/query?query=otelcol_log_records_received
```

A non-zero result confirms logs are being ingested.

## Retention and Storage

Log retention is governed by the backend (e.g. ClickHouse) and is configured separately (see `docs/DATA_RETENTION_POLICY.md`).

## Adding Application Logs

- Libraries and frameworks should be instrumented with OpenTelemetry.
- Use the OTLP HTTP exporter pointing to `http://otel-collector:4318`.
- For non-OTLP clients, consider a lightweight agent or forwarder that converts logs to OTLP.

---

_Last updated: $(date +%Y-%m-%d)_
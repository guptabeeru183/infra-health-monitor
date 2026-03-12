# Tracing Pipeline

Distributed traces allow engineers to follow a request as it travels through services.

## Path of a Trace

1. An application records spans using an OpenTelemetry SDK.
2. The SDK exports spans using OTLP to the collector (`http://otel-collector:4318/v1/traces` or gRPC).
3. The collector applies processors (batch, memory_limiter, sampling) and forwards spans to a backend such as SigNoz or Jaeger.
4. Collector metrics (`otelcol_spans_received`, `otelcol_spans_exported`) are scraped by Prometheus.
5. Grafana, the backend UI, or the collector's zpages can be used to inspect traces.

## Configuration

Refer to `configs/signoz-overrides/otel-collector-config.yml`:
- Ensure the `traces` pipeline has a valid exporter configured.
- Add a Jaeger exporter if you prefer:

```yaml
exporters:
  jaeger:
    endpoint: jaeger:14250
    tls_enabled: false
```

Enable sampling or attribute processors as needed.

## Testing the Pipeline

- Use `scripts/send-sample-telemetry.sh` to transmit a synthetic span.
- Run the integration test suite; it now validates that `otelcol_spans_received` appears in Prometheus.
- Check collector metrics directly or view the backend UI for the test span.

## Adding Instrumentation

- Choose an OTLP-compatible SDK for your language (Python, Go, Java, etc.).
- Set `service.name` attribute to identify your service.
- Example (Python):
  ```python
  from opentelemetry import trace
  from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
  from opentelemetry.sdk.trace import TracerProvider
  from opentelemetry.sdk.trace.export import BatchSpanProcessor

  trace.set_tracer_provider(TracerProvider())
  exporter = OTLPSpanExporter(endpoint="http://otel-collector:4318")
  trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(exporter))
  tracer = trace.get_tracer(__name__)
  with tracer.start_as_current_span("example"):
      pass
  ```

## Retention

Trace retention settings are managed by the storage backend (e.g. ClickHouse) and should align with organizational policies. See `docs/DATA_RETENTION_POLICY.md` for guidelines.

---

_Last updated: $(date +%Y-%m-%d)_
# Integration Guide: Infra Health Monitor

Complete guide to the integrated monitoring architecture and service integration patterns.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Service Integration Map](#service-integration-map)
3. [Data Flow Paths](#data-flow-paths)
4. [Configuration Checklist](#configuration-checklist)
5. [Deployment Validation](#deployment-validation)
6. [Integration Points](#integration-points)
7. [Service Dependencies](#service-dependencies)
8. [Common Integration Patterns](#common-integration-patterns)

---

## Architecture Overview

### System Design

The Infra Health Monitor is a distributed monitoring stack with six integrated services working together to provide comprehensive infrastructure visibility:

```
┌─────────────────────────────────────────────────────────────┐
│                   Infra Health Monitor Stack                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Netdata    │  │ SigNoz       │  │ Uptime Kuma  │      │
│  │  (System)    │  │  (Traces)    │  │ (Availability)      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │                │
│         ▼                 ▼                 ▼                │
│  ┌───────────────────────────────────────────────┐          │
│  │         Prometheus (Metrics Hub)              │          │
│  │  - Scrapes all sources at 15-30s intervals   │          │
│  │  - StorageLocal: 30-day retention            │          │
│  │  - 6 scrape jobs configured                  │          │
│  └────────────┬────────────────────────┬────────┘          │
│               │                        │                    │
│       ┌───────▼───────┐        ┌──────▼────────┐           │
│       │  Alertmanager │        │  Grafana      │           │
│       │  - Rules eval │        │  - Dashboards │           │
│       │  - Routing    │        │  - Queries    │           │
│       │  - Delivery   │        │  - Alerts     │           │
│       └───────┬───────┘        └───────────────┘           │
│               │                                              │
│               ▼                                              │
│       ┌───────────────┐                                      │
│       │Notifications  │                                      │
│       │ - Email       │                                      │
│       │ - Slack       │                                      │
│       │ - PagerDuty   │                                      │
│       └───────────────┘                                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Key Characteristics

- **Distributed**: Services run in separate containers, communicate over network
- **Metrics-Centric**: Prometheus scrapes all sources; single source of truth
- **Real-time**: 15-30s scrape intervals, immediate alert evaluation
- **Resilient**: Services can recover independently; state persisted in PostgreSQL/ClickHouse
- **Scalable**: Easily add new monitoring targets via scrape job configuration

---

## Service Integration Map

### 1. Netdata → Prometheus

**Purpose**: System metrics collection from monitored infrastructure

**Integration Type**: Pull (Prometheus scrapes Netdata)

**Configuration Files**:
- `configs/netdata-overrides/netdata.conf` - Enables Prometheus exporter
- `configs/prometheus-overrides/netdata-scrape.yml` - Scrape job definition

**Flow**:
```
Netdata (internal collection)
  ▼
Prometheus Exporter @ :19999
  ▼
Prometheus Scrape Job
  ▼
Time-series Storage
```

**Metrics Provided**:
- CPU usage (user, system, iowait, guest)
- Memory (free, used, cached, buffers)
- Disk I/O (reads, writes, service time)
- Network (traffic, errors, drops)
- Process-level metrics (CPU%, memory%, threads)

**SLO**: Metrics available within 15 seconds of collection

**Verification**:
```bash
# Check exporter is available:
curl http://netdata:19999/api/v1/allmetrics?format=prometheus | head -20

# Verify in Prometheus:
curl 'http://prometheus:9090/api/v1/query?query=netdata_system_cpu_usage'
```

### 2. Uptime Kuma → Prometheus

**Purpose**: Availability monitoring and endpoint health checks

**Integration Type**: Custom Pull (Python exporter)

**Configuration Files**:
- `integration/uptime-kuma-exporter.py` - Flask exporter service
- `docker-compose.yml` - uptime-kuma-exporter service config
- `configs/prometheus-overrides/prometheus.yml` - Uptime Kuma scrape job

**Flow**:
```
Uptime Kuma API @ :3001
  ▼
Uptime Kuma Exporter (Python Flask)
  ▼
Prometheus Metrics @ :5000/metrics
  ▼
Prometheus Scrape Job
  ▼
Time-series Storage
```

**Metrics Provided**:
- Monitor up/down status (1/0)
- Response time (milliseconds)
- Uptime percentage (0-100)
- Downtime event count (total)
- Check timestamp

**SLO**: Availability metrics available within 30 seconds

**Verification**:
```bash
# Check exporter output:
curl http://uptime-kuma-exporter:5000/metrics | grep uptime_

# Check in Prometheus:
curl 'http://prometheus:9090/api/v1/query?query=uptime_monitor_up'
```

### 3. SigNoz OpenTelemetry → Prometheus

**Purpose**: Application instrumentation metrics and distributed traces

**Integration Type**: Push (Apps → OTEL Collector) + Pull (Prometheus scrapes collector)

**Configuration Files**:
- `docker-compose.yml` - OTEL Collector service
- `configs/prometheus-overrides/prometheus.yml` - OTEL Collector scrape job

**Flow**:
```
Instrumented Applications
  ▼
OTLP Exporters (gRPC/HTTP)
  ▼
OpenTelemetry Collector @ :4317 (gRPC), :4318 (HTTP)
  ▼
Prometheus Exporter @ :8888
  ▼
Prometheus Scrape Job (15s)
  ▼
Time-series Storage
```

**Metrics Provided**:
- Application traces (latency bucketing via prometheus exporter)
- Request counts (by span name, status, operation)
- Error rates
- Service latency P50/P95/P99

**SLO**: Application metrics available within 15 seconds

**Verification**:
```bash
# Check OTEL endpoint:
curl http://otel-collector:8888/metrics | grep -E '^(trace|span|request)' | head -10

# Verify in Prometheus:
curl 'http://prometheus:9090/api/v1/query?query=otel_request_duration_seconds'
```

### 4. Prometheus → Alertmanager

**Purpose**: Alert rule evaluation and routing

**Integration Type**: Push (Prometheus fires alerts to Alertmanager)

**Configuration Files**:
- `configs/prometheus-overrides/prometheus.yml` - Alertmanager target
- `configs/alertmanager-overrides/alertmanager.yml` - Alert routing rules
- `configs/prometheus-overrides/alert-rules.yml` - Alert conditions

**Flow**:
```
Alert Rules Evaluation (15s)
  ▼
Alert Firing (state > 5m for critical)
  ▼
Push to Alertmanager @ :9093
  ▼
Route by Labels (severity, service, team)
  ▼
Receiver Processing
  ▼
Notification Delivery
```

**Alerts Configured**:
- PrometheusDown - Prometheus unavailable
- AlertmanagerDown - Alertmanager unavailable
- NetdataDown - Netdata service unavailable
- HighCpuUsage - CPU > 80% for 5 minutes
- HighMemoryUsage - Memory > 80% for 5 minutes
- DiskSpaceLow - Free disk < 20%
- DiskSpaceCritical - Free disk < 10%

**SLO**: Alerts delivered within 5-10 seconds of condition trigger

**Verification**:
```bash
# Check alertmanager status:
curl http://alertmanager:9093/api/v1/status

# View active alerts:
curl http://alertmanager:9093/api/v1/alerts | jq '.data[] | {alertname, severity, status}'
```

### 5. Alertmanager → Notification Channels

**Purpose**: Alert notification delivery to operators

**Integration Type**: Push (Alertmanager sends notifications)

**Configuration Files**:
- `configs/alertmanager-overrides/alertmanager.yml` - Receiver definitions

**Channels Supported**:
- Email (SMTP)
- Slack (webhook)
- PagerDuty (integration key)
- Generic webhooks

### 6. Prometheus → Grafana

**Purpose**: Metrics visualization and dashboarding

**Integration Type**: Pull (Grafana queries Prometheus)

**Configuration Files**:
- `docker-compose.yml` - Grafana service + provisioning
- `provisioning/datasources/prometheus.yml` - Datasource config
- `provisioning/dashboards/` - Dashboard definitions

**Flow**:
```
Grafana Dashboard
  ▼
Prometheus Datasource Query
  ▼
Prometheus API Query
  ▼
Query Evaluator (instant or range)
  ▼
Return Time Series
  ▼
Visualization Rendering
```

**SLO**: Dashboard load < 2 seconds, query response < 1 second

**Verification**:
```bash
# Check Grafana datasource:
curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
  http://grafana:3000/api/datasources | jq '.[].url'

# Test query:
curl -s 'http://prometheus:9090/api/v1/query?query=netdata_system_cpu_usage' | jq '.data.result | length'
```

---

## Data Flow Paths

### Path 1: System Metrics (Netdata → Prometheus → Grafana)

```
Netdata Host Collection (5s)
  │
  ├─→ Memory (1GB dbengine)
  │
  ▼
Prometheus Exporter Format (:19999/api/v1/allmetrics)
  │
  ├─→ OpenMetrics Format
  │   - TYPE/HELP markers
  │   - Proper unit suffixes
  │
  ▼
Prometheus Scrape (15s interval)
  │
  ├─→ Target: netdata:19999
  ├─→ Relabel: hostname, datacenter labels
  ├─→ Cardinality Control: Top 10,000 series
  │
  ▼
Prometheus TSDB Ingestion
  │
  ├─→ Compression: ~1MB per million samples
  ├─→ Retention: 30 days local, 1 year in storage
  ├─→ Evaluation: Rule matching every 15s
  │
  ▼
Grafana Dashboard Query
  │
  ├─→ Instant Query: cpu_usage{job="netdata"}
  ├─→ Range Query: last 7 days, 1m granularity
  ├─→ Aggregation: avg(rate(cpu[5m]))
  │
  ▼
Visualization (HTML/JSON)
  │
  ├─→ Time series graph
  ├─→ Gauge (current value)
  ├─→ Stat panel (trend indicator)
  │
  ▼
End User Browser
```

**Latency Components**:
- Collection: 5s (Netdata interval)
- Export: 50ms (format conversion)
- Scrape: 5s (interval) + 500ms (transfer)
- Ingestion: 100ms (write to TSDB)
- Query: 100-500ms (from TSDB)
- Render: 200ms (browser rendering)
- **Total**: ~12s from event to dashboard visualization

### Path 2: Availability Status (Uptime Kuma → Prometheus → Alerts)

```
Monitor Check Execution
  │
  ├─→ HTTP GET endpoint (5s interval)
  │   Response time measured, status code captured
  │
  ▼
Uptime Kuma Status Update
  │
  ├─→ PostgreSQL: [monitors, incidents, notifications]
  │
  ▼
Uptime Kuma Exporter Scrape
  │
  ├─→ Fetches API: /api/status/pages
  ├─→ Converts: API format → Prometheus metrics
  │
  ▼
Prometheus Exporter Metrics Endpoint
  │
  ├─→ Format: uptime_monitor_up{monitor="api",instance="prod"}
  │
  ▼
Prometheus Scrape (30s interval)
  │
  ├─→ Target: uptime-kuma-exporter:5000
  ├─→ Relabel: monitor_name=, environment=
  │
  ▼
Alert Rule Evaluation
  │
  ├─→ Rule: up{job="uptime-kuma",value="0"} > 0
  ├─→ Duration: Wait 2 minutes before firing
  ├─→ Severity: critical
  │
  ▼
Alertmanager Routing (< 10s)
  │
  ├─→ Match: alertname="HighLatency"
  ├─→ Route: [critical] → team-oncall
  │
  ▼
Notification Delivery
  │
  ├─→ Slack: @team-oncall
  ├─→ Email: team@company.com
  ├─→ PagerDuty: Incident creation
  │
  ▼
Operator Response
```

**Latency Components**:
- Monitor check: 5s
- Exporter conversion: 200ms
- Prometheus scrape: 30s
- Rule evaluation: 2m (wait duration)
- Alertmanager processing: 1s
- **Critical Path**: ~2min 34s from check failure to alert

### Path 3: Distributed Traces (Application → OTEL → Prometheus → SigNoz)

```
Instrumented Application Request
  │
  ├─→ OpenTelemetry SDK initialization
  │   - Auto-instrumentation (HTTP, DB, ...) 
  │
  ▼
Span Generation
  │
  ├─→ span_id: unique identifier
  ├─→ trace_id: request correlation
  ├─→ duration: request latency
  ├─→ attributes: request_path, http_method, status_code
  │
  ▼
OTLP Exporter
  │
  ├─→ Batching: 100 spans/batch, 10s timeout
  ├─→ Transport: gRPC (port 4317)
  │
  ▼
OpenTelemetry Collector
  │
  ├─→ Receiver: OTLP gRPC
  ├─→ Processor: Batch, Memory limiter
  ├─→ Exporter (Path A): SigNoz (traces)
  ├─→ Exporter (Path B): Prometheus (metrics)
  │
  ▼ (Path B - Metrics)
  │
  Prometheus Exporter (port 8888)
  │
  ├─→ Metrics: request_count, request_duration, error_count
  ├─→ Labels: service_name, span_name, operation
  │
  ▼
  │
  Prometheus Scrape (15s)
  │
  ├─→ Target: otel-collector:8888
  ├─→ Cardinality Limit: 100,000 series
  │
  ▼
  │
  TSDB Storage → Grafana Dashboards
  │
  └─→ Latency histogram visualization
      Request rate trending
      Error rate by service

▼ (Path A - Traces)
│
SigNoz ClickHouse Backend
│
├─→ Span storage (columnar)
├─→ Trace aggregation
├─→ Service dependency graph
│
▼
SigNoz Web UI
│
├─→ Trace search/filtering
├─→ Span waterfall view
├─→ Service map visualization
│
▼
Operator Investigation
```

**Latency Components**:
- Application span generation: <1ms
- Batching and export: 0-10s (on batch timeout)
- Collection processing: 50ms
- TSDB ingestion: 100ms
- Trace store: 200ms
- **Query latency**: 200-500ms (trace search)

---

## Configuration Checklist

### Pre-Deployment

- [ ] Docker and Docker Compose installed
- [ ] Network port availability checked (9090, 3000, 9093, 19999, 5000, 3001, 5400, 9411, 8086)
- [ ] Disk space > 50GB available
- [ ] Outbound connectivity for notifications (SMTP, Slack, PagerDuty)

### Service Configuration

#### Netdata

- [ ] `configs/netdata-overrides/netdata.conf` created
  - [ ] `[prometheus] enabled = yes`
  - [ ] `bind to = 0.0.0.0:19999`
  - [ ] `memory mode = dbengine`
  - [ ] `dbengine multihost disk space = 256`
- [ ] Docker volume mounted: `netdata-lib` (persistence)
- [ ] Network: connected to `monitoring-net`

#### Prometheus

- [ ] `configs/prometheus-overrides/prometheus.yml` updated
  - [ ] 5 scrape jobs configured:
    - [ ] prometheus (self-monitoring)
    - [ ] alertmanager (alert mgmt health)
    - [ ] netdata (system metrics)
    - [ ] uptime-kuma-exporter (availability)
    - [ ] otel-collector (application metrics)
  - [ ] `rule_files: ["alert-rules.yml"]`
  - [ ] `alerting.alertmanagers: [http://alertmanager:9093]`
  - [ ] Global evaluation interval: 15s
  - [ ] Global scrape timeout: 10s
- [ ] `configs/prometheus-overrides/alert-rules.yml` present
- [ ] Storage directory writable: `/prometheus`
- [ ] Network: connected to all service networks

#### Alertmanager

- [ ] `configs/alertmanager-overrides/alertmanager.yml` configured
  - [ ] Global SMTP settings (if email notifications enabled)
  - [ ] Receivers defined (email, slack, pagerduty, etc.)
  - [ ] Routes configured by severity
  - [ ] Inhibition rules configured
- [ ] Configuration valid (no YAML errors)
- [ ] Network: connected to `monitoring-net`

#### Grafana

- [ ] Prometheus datasource provisioned
  - [ ] URL: `http://prometheus:9090`
  - [ ] Scrape interval: 15s
  - [ ] Query timeout: 30s
- [ ] Dashboards provisioned in `provisioning/dashboards/`
- [ ] admin user password changed from default
- [ ] Non-root user created for monitoring team
- [ ] Network: exposed on port 3000

#### Uptime Kuma

- [ ] Service running (docker-compose)
- [ ] Database volume: `uptime-kuma-db`
- [ ] Admin user configured with strong password
- [ ] Monitors defined (endpoints to check)
- [ ] Network: port 3001 accessible to exporter

#### Uptime Kuma Exporter

- [ ] `integration/uptime-kuma-exporter.py` deployed
  - [ ] Environment variables set:
    - [ ] `UPTIME_KUMA_URL=http://uptime-kuma:3001`
    - [ ] `EXPORTER_PORT=5000`
    - [ ] `LOG_LEVEL=INFO`
  - [ ] Python 3.8+ available
  - [ ] Dependencies installed: requests, prometheus_client, flask
- [ ] Health check: `/health` endpoint
- [ ] Metrics endpoint: `/metrics` available
- [ ] Network: accessible to Prometheus at `:5000`

#### OpenTelemetry Collector

- [ ] `otel-collector-config.yaml` present and valid
- [ ] Receivers configured:
  - [ ] OTLP gRPC: `:4317`
  - [ ] OTLP HTTP: `:4318`
- [ ] Exporters configured:
  - [ ] Prometheus exporter: `:8888`
  - [ ] OTLP exporter to SigNoz
- [ ] Processors configured:
  - [ ] Batch processor (100 items, 10s timeout)
  - [ ] Memory limiter (80% threshold)
- [ ] Network: exposed for application connections

#### SigNoz

- [ ] ClickHouse backend configured
  - [ ] Database: `signoz`
  - [ ] Data directory: `/opt/clickhouse`
  - [ ] Users configured for OTLP receiver
- [ ] OpenTelemetry Collector integration working
- [ ] Web UI accessible on port 3301
- [ ] Network: OTLP receivers on 4317/4318

### Integration Verification

- [ ] All services start without errors: `docker-compose up -d`
- [ ] Service health checks passing: `docker-compose ps`
- [ ] Network connectivity tests:
  - [ ] `curl http://prometheus:9090/-/healthy` → 200
  - [ ] `curl http://alertmanager:9093/` → 200
  - [ ] `curl http://netdata:19999/` → 200
  - [ ] `curl http://uptime-kuma-exporter:5000/health` → 200
  - [ ] `curl http://otel-collector:8888/metrics` → 200
- [ ] Metric ingestion:
  - [ ] Prometheus targets UP: `curl http://prometheus:9090/api/v1/targets`
  - [ ] Metrics exist: `curl 'http://prometheus:9090/api/v1/query?query=netdata_system_cpu_usage'`
- [ ] Alert evaluation:
  - [ ] Rules loaded: `curl http://prometheus:9090/api/v1/rules | jq '.data.groups | length'`
  - [ ] Alertmanager receiving: `curl http://alertmanager:9093/api/v1/status`
- [ ] Grafana visualization:
  - [ ] Datasource working: Query `up` in test dashboard
  - [ ] Dashboards loading without errors

### Post-Deployment

- [ ] Backup configuration files to version control
- [ ] Document any custom modifications
- [ ] Set up monitoring meta-monitoring (Prometheus monitoring itself)
- [ ] Configure log rotation for long-running containers
- [ ] Schedule regular metric retention policy review
- [ ] Create on-call runbook based on alert rules

---

## Deployment Validation

### Automated Testing

Run the provided testing scripts to validate all integrations:

```bash
# Test all service connectivity and integration
./scripts/integration-test.sh

# Verify metrics flow from source to Prometheus
./scripts/verify-metrics-flow.sh

# Monitor Prometheus scrape target health
./scripts/check-scrape-targets.sh --watch

# Test alert routing and firing
./scripts/test-alert-routing.sh
```

### Manual Validation Steps

1. **Service Availability**: Confirm all services are running
   ```bash
   docker-compose ps
   # All services should show "Up"
   ```

2. **Prometheus Targets**: Check that all scrape jobs have UP status
   ```bash
   curl http://prometheus:9090/api/v1/targets | \
     jq '.data.activeTargets[] | {job: .labels.job, state: .health}'
   ```

3. **Metric Availability**: Verify metrics from each source
   ```bash
   # Netdata metrics
   curl 'http://prometheus:9090/api/v1/query?query=netdata_system_cpu_usage{job="netdata"}'

   # Uptime Kuma metrics
   curl 'http://prometheus:9090/api/v1/query?query=uptime_monitor_up'

   # OTEL metrics
   curl 'http://prometheus:9090/api/v1/query?query=otel_request_duration_seconds'
   ```

4. **Alert Rules**: Verify all alert rules are loaded and evaluating
   ```bash
   curl http://prometheus:9090/api/v1/rules | \
     jq '.data.groups[].rules[] | {name: .name, state: .state}'
   ```

5. **Alertmanager Status**: Check alertmanager is running and configured
   ```bash
   curl http://alertmanager:9093/api/v1/status | jq '.data'
   ```

6. **Grafana Datasource**: Test Prometheus datasource
   ```bash
   curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
     http://grafana:3000/api/datasources/1 | jq '.database'
   ```

---

## Integration Points

### Network Interfaces

| Service | Port | Protocol | Incoming | Outgoing |
|---------|------|----------|----------|----------|
| Prometheus | 9090 | HTTP | Grafana, operators | Alertmanager, scrape targets |
| Alertmanager | 9093 | HTTP | Prometheus, operators | External webhooks |
| Grafana | 3000 | HTTP | Browser | Prometheus |
| Netdata | 19999 | HTTP | Prometheus | None |
| Uptime Kuma | 3001 | HTTP | Uptime Exporter | Monitor targets |
| Uptime Kuma Exporter | 5000 | HTTP | Prometheus | Uptime Kuma API |
| OTEL Collector | 4317 | gRPC | Applications | SigNoz |
| OTEL Collector | 4318 | HTTP | Applications | SigNoz |
| OTEL Collector | 8888 | HTTP | Prometheus | None |
| SigNoz | 5400 | HTTP | Operators | None |
| ClickHouse | 9000 | gRPC | OTEL Collector | None |

### Data Flows

1. **Netdata → Prometheus**: Pull-based (Prometheus scrapes)
2. **Uptime Kuma → Prometheus**: Pull-based via exporter
3. **OTEL → SigNoz**: Push-based (batch OTLP)
4. **OTEL → Prometheus**: Pull-based (Prometheus scrapes metrics)
5. **Prometheus → Alertmanager**: Push-based (on alert firing)
6. **Prometheus → Grafana**: Pull-based (dashboard queries)
7. **Alertmanager → External**: Push-based (email, Slack, PagerDuty)

### Label/Metadata Flow

```
Label Sources:
├─ Service name (from docker container name)
├─ Environment (from docker-compose profile)
├─ Datacenter (from relabel rules)
├─ Team (from alert routing rules)
└─ Custom labels (from scrape config)

Label Propagation:
Netdata metrics → Prometheus scrape labels → Alert rules → Alertmanager routing
```

---

## Service Dependencies

### Startup Order

1. PostgreSQL (for Uptime Kuma) - must be first
2. ClickHouse (for SigNoz) - must be before SigNoz
3. Prometheus (for alerting coordination) - before Alertmanager
4. Alertmanager - depends on Prometheus
5. Netdata, Uptime Kuma, OTEL Collector, SigNoz - parallel startup
6. Grafana - can start anytime, but needs Prometheus first for dashboards
7. Uptime Kuma Exporter - depends on Uptime Kuma API

### Health Check Endpoints

```
GET http://prometheus:9090/-/healthy        → 200 when ready
GET http://alertmanager:9093/               → 200 when ready
GET http://netdata:19999/api/v1/info        → 200 when ready
GET http://grafana:3000/api/health          → 200 when ready
GET http://uptime-kuma-exporter:5000/health → 200 when ready
GET http://otel-collector:8888/metrics      → 200 when ready
GET http://signoz:5400/api/v1/health        → 200 when ready
```

### Data Persistence

- **Prometheus**: `./prometheus` (TSDB files)
- **Grafana**: PostgreSQL (dashboards, users, datasources)
- **Alertmanager**: `/alertmanager` (silences, configuration)
- **Uptime Kuma**: PostgreSQL (monitors, incidents, users)
- **SigNoz**: ClickHouse (traces, metrics, logs)

---

## Common Integration Patterns

### Pattern 1: Add New Scrape Target

To monitor a new application:

1. Ensure app exports Prometheus metrics on port 8888/metrics
2. Add scrape job to `prometheus.yml`:
   ```yaml
   - job_name: 'my-app'
     targets: ['my-app:8888']
     scrape_interval: 15s
   ```
3. Reload Prometheus: `curl -X POST http://prometheus:9090/-/reload`
4. Verify in Prometheus Targets: `http://prometheus:9090/targets`

### Pattern 2: Add New Alert Rule

To create a new alert:

1. Add rule to `alert-rules.yml`:
   ```yaml
   - alert: MyApplicationDown
     expr: up{job="my-app"} == 0
     for: 5m
     labels:
       severity: critical
       service: my-app
     annotations:
       summary: "MyApp is down"
   ```
2. Reload Prometheus: `curl -X POST http://prometheus:9090/-/reload`
3. Verify rule loaded: `curl http://prometheus:9090/api/v1/rules`

### Pattern 3: Add New Notification Receiver

To add email/Slack/PagerDuty:

1. Update `alertmanager.yml` with new receiver config
2. Add receiver reference in routing rules
3. Reload Alertmanager: `curl -X POST http://alertmanager:9093/-/reload`
4. Test with alert: `scripts/test-alert-routing.sh --trigger-alerts`

### Pattern 4: Create Custom Dashboard

To create a custom Grafana dashboard:

1. Use Grafana UI (web interface) to design the dashboard
2. Export as JSON
3. Save to `provisioning/dashboards/`
4. Restart Grafana to load automatically

### Pattern 5: Monitor New Application with OTEL

To add application instrumentation:

1. Add OpenTelemetry SDK to application code
2. Configure SDK to export OTLP-gRPC to `otel-collector:4317`
3. Configure OTEL Collector to export metrics to Prometheus
4. Traces automatically appear in SigNoz
5. Metrics automatically appear in Prometheus

---

## Related Documentation

- [Data Flow Architecture](DATA_FLOW.md) - Detailed sequence diagrams
- [Metric Naming Conventions](METRIC_NAMING.md) - Label and metric standards
- [Troubleshooting Guide](TROUBLESHOOTING_INTEGRATION.md) - Common issues and solutions
- [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) - Overall roadmap


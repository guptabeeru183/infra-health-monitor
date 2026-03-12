# Data Flow Architecture

Complete data flow documentation with sequence diagrams and timing analysis.

## Table of Contents

1. [Metrics Pipeline](#metrics-pipeline)
2. [Alert Pipeline](#alert-pipeline)
3. [Trace Pipeline](#trace-pipeline)
4. [Query Pipeline](#query-pipeline)
5. [Notification Pipeline](#notification-pipeline)
6. [Real-Time Flow Diagrams](#real-time-flow-diagrams)
7. [Performance Analysis](#performance-analysis)
8. [Data Volumetrics](#data-volumetrics)

---

## Metrics Pipeline

### System Metrics Collection (Netdata → Prometheus → Grafana)

**Overview**: System metrics flow from Netdata collection through Prometheus storage to Grafana visualization.

**Process Flow**:

```
Step 1: COLLECTION (Netdata)
  └─ Interval: 1-5 seconds
  └─ Metrics: /proc, /sys, netlinks
  └─ Storage: 1GB in-memory (dbengine)
  └─ Collected metrics include:
      - CPU (user, system, iowait, guest, steal)
      - Memory (free, used, buffers, cached)
      - Disk I/O (reads, writes, milliseconds)
      - Network (packets, errors, dropped)
      - Processes (running, sleeping, zombie)

Step 2: EXPORT (Netdata Exporter)
  └─ Service: netdata container
  └─ Port: 19999
  └─ Path: /api/v1/allmetrics?format=prometheus
  └─ Format: OpenMetrics (text protocol)
  └─ Size: ~2-3MB for 1000 metrics
  └─ Example:
     netdata_system_cpu_usage{dimension="user"} 23.5
     netdata_system_ram_used_bytes{family="memory.ram"} 8589934592

Step 3: PROMETHEUS SCRAPE
  ├─ Job: 'netdata'
  ├─ Target: netdata:19999
  ├─ Interval: 15 seconds
  ├─ Timeout: 10 seconds (fail if slow)
  ├─ Process:
  │  ├─ Connect to exporter endpoint
  │  ├─ Download text format response
  │  ├─ Parse into internal representation
  │  ├─ Apply relabel rules
  │  │  ├─ Add job="netdata" label
  │  │  ├─ Add instance="netdata:19999" label
  │  │  └─ Rename metric: netdata_* → node_*
  │  ├─ Apply metric relabel rules
  │  │  └─ Drop high-cardinality metrics
  │  └─ Write to TSDB
  └─ Success rate tracking: up{job="netdata"}

Step 4: STORAGE (Prometheus TSDB)
  ├─ Location: /prometheus/{year}/{month}/
  ├─ Compression: ~1MB per million samples
  ├─ Retention: 30 days (rolling window)
  ├─ Indexed by:
  │  ├─ Metric name
  │  ├─ Label combinations
  │  └─ Timestamp
  └─ Sample rate: ~100 samples/second (600 metrics × 15s)

Step 5: QUERY (Prometheus API)
  ├─ Client: Grafana dashboard
  ├─ Query type: Range query
  ├─ Time range: Last 24 hours to 1 year
  ├─ Granularity: 1 minute (step parameter)
  ├─ Example query:
     rate(netdata_system_cpu_usage[5m]) / 100
  ├─ Processing:
  │  ├─ Read TSDB blocks (in parallel)
  │  ├─ Load samples matching label selectors
  │  ├─ Evaluate expression (e.g., rate() function)
  │  ├─ Apply aggregations (sum, avg, etc.)
  │  └─ Return as JSON time series
  └─ Response time: 100-500ms

Step 6: VISUALIZATION (Grafana)
  ├─ Client: Web browser
  ├─ Format: JSON time series (array of [timestamp, value])
  ├─ Rendering:
  │  ├─ Load JSON data
  │  ├─ Create plot data (X=time, Y=value)
  │  ├─ Draw using Canvas/SVG
  │  ├─ Add legend, axes, tooltips
  │  └─ Render on screen
  └─ Display latency: 200-500ms
```

**Total Latency**:
- Collection: 5s (worst case)
- Export: 0.1s (serialization)
- Scrape: 0.5s (network + parsing)
- Storage: 0.1s (TSDB write)
- Query: 0.3s (TSDB read + compute)
- Visualization: 0.3s (browser render)
- **Total**: ~6.2 seconds (average ~3 seconds)

**Data Example**:

```
Raw Netdata metric:   netdata_system_cpu_usage{dimension="user"} 45.2
After relabel:        node_cpu_seconds_total{mode="user"} 45200
In Prometheus TSDB:   <metric_id=123><sample=45200><timestamp=1705000000>
Grafana query:        rate(node_cpu_seconds_total{mode="user"}[5m])
Query result:         [1705000000, "0.754"] (0.754 CPU seconds per second)
Visualization:        Graph showing 75.4% user CPU utilization
```

---

## Alert Pipeline

### Alert Rule Evaluation → Alertmanager → Notification

**Overview**: Prometheus continuously evaluates alert rules, fires alerts to Alertmanager, which routes them to notification channels.

**Process Flow**:

```
PHASE 1: RULE EVALUATION (Prometheus)
  ├─ Interval: 15 seconds (global evaluation)
  ├─ Process:
  │  ├─ Read alert rule definition (e.g., "cpu > 80%")
  │  ├─ Execute query against TSDB (netdata_system_cpu_usage)
  │  ├─ Evaluate: returns 0 (inactive) or series (pending/firing)
  │  ├─ Compare result with threshold
  │  └─ Track state (unchanged, pending → firing, firing → inactive)
  │
  ├─ Example rule:
  │  alert: HighCpuUsage
  │  expr: netdata_system_cpu_usage{dimension="user"} > 80
  │  for: 5m  ← Wait 5 minutes in "pending" state
  │  labels:
  │    severity: warning
  │    service: infrastructure
  │  annotations:
  │    summary: "CPU usage {{ $value }}% on {{ $labels.instance }}"
  │
  └─ Alert states:
     Inactive: Condition false (query returns no series)
     Pending: Condition true for < 5 minutes
     Firing: Condition true for ≥ 5 minutes

PHASE 2: ALERT FIRING (Prometheus → Alertmanager)
  ├─ Trigger: Alert transitions from pending → firing
  ├─ Action: Push to Alertmanager
  ├─ HTTP request:
  │  POST http://alertmanager:9093/api/v1/alerts
  │  Content-Type: application/json
  │  Payload:
  │  [
  │    {
  │      "status": "firing",
  │      "labels": {
  │        "alertname": "HighCpuUsage",
  │        "severity": "warning",
  │        "instance": "host01:19999",
  │        "job": "netdata"
  │      },
  │      "annotations": {
  │        "summary": "CPU usage 92.5% on host01:19999"
  │      },
  │      "startsAt": "2024-01-12T10:30:00Z",
  │      "endsAt": "0001-01-01T00:00:00Z"  ← "0001" = still firing
  │    }
  │  ]
  │
  ├─ Payload size: 300-500 bytes per alert
  ├─ Frequency: Up to every 15 seconds (re-evaluation interval)
  └─ Latency: 100-200ms

PHASE 3: ALERT ROUTING (Alertmanager)
  ├─ Input: Alert from Prometheus
  ├─ Process:
  │  ├─ Match alert against routing rules
  │  ├─ Rules checked in order:
  │  │  ├─ Severity label (critical → high priority)
  │  │  ├─ Service label (database → dba team)
  │  │  ├─ Environment label (prod → escalate)
  │  │  └─ Default receiver if no matches
  │  ├─ Apply inhibition rules
  │  │  └─ Example: Inhibit "NodeDown" if "PrometheusDown" firing
  │  │           (Prometheus can't scrape metrics if down)
  │  ├─ Check silence rules
  │  │  └─ Example: Silence "HighCpuUsage" during maintenance window
  │  └─ Determine target receiver(s)
  │
  ├─ Example routing:
  │  Group-by: [alertname, service, severity]
  │  Routes:
  │  - match: severity = critical
  │    receiver: critical-pagerduty
  │    repeat_interval: 5m (resend if still firing)
  │  - match: severity = warning
  │    receiver: team-slack
  │    repeat_interval: 1h
  │  - receiver: default (fallback)
  │
  └─ Processing latency: 50-100ms

PHASE 4: NOTIFICATION SENDING
  ├─ Output: One or more notification channels
  ├─ Receivers:
  │  ├─ Email
  │  │  ├─ Latency: 1-10 seconds (SMTP)
  │  │  ├─ Reliability: Best effort
  │  │  └─ Format: HTML email with alert details
  │  │
  │  ├─ Slack
  │  │  ├─ Latency: 100-500ms (webhook)
  │  │  ├─ Format: Rich message with color coding
  │  │  ├─ Example:
  │  │  │  🚨 [WARNING] HighCpuUsage
  │  │  │  Host: host01
  │  │  │  Current: 92.5% user CPU
  │  │  │  Started: 2024-01-12 10:30:00 UTC
  │  │  │
  │  │  └─ Features: Threading, reactions, action buttons
  │  │
  │  └─ PagerDuty
  │     ├─ Latency: 200-1000ms (API call)
  │     ├─ Action: Create incident + notify on-call
  │     └─ Escalation: Based on configured policies
  │
  └─ Total notification time: 1-10 seconds

PHASE 5: ALERT RESOLUTION (Prometheus → Alertmanager)
  ├─ Trigger: Alert condition becomes false
  ├─ Update: Send "resolved" state alert to Alertmanager
  │  "endsAt": "2024-01-12T10:45:00Z"  ← Resolved time
  ├─ Notification: Send resolution message
  │  Email: "RESOLVED: HighCpuUsage on host01"
  │  Slack: "✅ Alert resolved"
  │  PagerDuty: "Incident Resolved"
  └─ Latency: Same as firing (~1-10 seconds)
```

**Total Alert Latency** (from trigger to notification):
- Collection: 5 seconds (metric available)
- Wait duration (for): 5 minutes (alert rule minimum)
- Evaluation: 15 seconds (Prometheus interval)
- Firing: 0.2 seconds (to Alertmanager)
- Routing: 0.1 seconds (Alertmanager processing)
- Notification: 1-10 seconds (channel dependent)
- **Critical Path**: 5m 21s (from condition to operator notification)

**Alert State Diagram**:

```
False condition    True for < 5m     True for ≥ 5m      False condition
    (Inactive) ────────→ (Pending) ────────→ (Firing) ────────→ (Resolved)
                                                    ↑
                                                    └─ Re-evaluation every 15s
                                                       Repeat notifications
                                                       per alert rules
```

---

## Trace Pipeline

### Instrumented Application → OpenTelemetry Collector → SigNoz

**Overview**: Application requests generate spans, which are batched and exported to OpenTelemetry Collector, then to SigNoz for analysis.

**Process Flow**:

```
PHASE 1: SPAN GENERATION (Application)
  ├─ Trigger: Incoming HTTP request
  ├─ Process:
  │  ├─ OpenTelemetry SDK auto-instrumentation
  │  ├─ Create root span with unique trace_id
  │  ├─ Create child spans for:
  │  │  ├─ HTTP handler
  │  │  ├─ Database query
  │  │  ├─ Cache lookup
  │  │  └─ External API call
  │  │
  │  ├─ Capture span attributes:
  │  │  ├─ http.method: "GET"
  │  │  ├─ http.url: "/api/users/123"
  │  │  ├─ http.status_code: 200
  │  │  ├─ db.system: "postgres"
  │  │  ├─ db.statement: "SELECT * FROM users WHERE id = $1"
  │  │  └─ duration: 45ms
  │  │
  │  └─ Span structure:
  │     Trace ID: 2dd461ce4e4c4b6c9ff4e1ee7ebafd23
  │     Span ID: 4e42f8271d44ba6f
  │     Parent Span ID: 2dd461ce4e4c4b6c
  │     Flags: 0x01 (sampled)
  │     Status: OK (0)
  │
  └─ Overhead: < 1ms per span

PHASE 2: BATCHING (OTEL SDK)
  ├─ Process:
  │  ├─ Buffer spans in memory
  │  ├─ Condition 1: Batch size reached (default 512)
  │  ├─ Condition 2: Timeout elapsed (default 10 seconds)
  │  ├─ Whichever comes first → export
  │  │
  │  ├─ Example batch:
  │  │  100 spans from different services
  │  │  Combined size: ~50KB
  │  │
  │  └─ Configuration:
  │     max_queue_size: 2048 (spans buffered before drop)
  │     batch_size: 512 (trigger export)
  │     schedule_timeout: 10s (timer)
  │
  └─ Processing overhead: < 5ms per batch

PHASE 3: EXPORT TO OTEL COLLECTOR (OTLP Protocol)
  ├─ Transport: gRPC (bidirectional streaming)
  ├─ Connection: Application → otel-collector:4317
  ├─ Protocol:
  │  ├─ Serialization: protobuf (binary)
  │  ├─ Compression: gzip (saves ~70% bandwidth)
  │  ├─ Message size: ~50KB per batch
  │  ├─ Request/response:
  │  │  POST /opentelemetry.proto.collector.trace.v1.TraceService/Export
  │  │  Body (binary): <protobuf-encoded spans>
  │  │  Response: {success_count: 100}
  │  │
  │  └─ Retry logic:
  │     Failed requests: Exponential backoff
  │     Max retries: 3
  │     Max backoff: 64 seconds
  │
  ├─ Network latency: 10-50ms (local docker network)
  └─ Total export time: 50-100ms

PHASE 4: OTEL COLLECTOR PROCESSING
  ├─ Components:
  │  ├─ Receiver: OTLP gRPC
  │  │  └─ Listen on :4317
  │  │
  │  ├─ Processors (in order):
  │  │  ├─ Memory Limiter
  │  │  │  └─ Drops spans if memory usage > 80%
  │  │  ├─ Batch Processor
  │  │  │  └─ Collects spans for export
  │  │  ├─ Attributes Processor
  │  │  │  └─ Adds/removes span attributes
  │  │  └─ Sampling Processor
  │  │     └─ Keeps only percentage of traces
  │  │
  │  └─ Exporters (parallel):
  │     ├─ SigNoz Exporter
  │     │  └─ Sends traces to SigNoz ClickHouse
  │     ├─ Prometheus Exporter
  │     │  └─ Aggregates metrics on :8888/metrics
  │     └─ Jaeger Exporter (optional)
  │        └─ Compatible with Jaeger UI
  │
  └─ Processing latency: 50-200ms

PHASE 5: SIGHOZ STORAGE (ClickHouse)
  ├─ Destination: ClickHouse database
  ├─ Schema:
  │  ├─ Column: trace_id (UUID)
  │  ├─ Column: span_id (UInt64)
  │  ├─ Column: parent_span_id (UInt64)
  │  ├─ Column: span_name (String)
  │  ├─ Column: duration_nano (UInt64)
  │  ├─ Column: attributes (JSON)
  │  ├─ Column: status (UInt8 or Enum)
  │  └─ Column: start_time_unix_nano (UInt64)
  │
  ├─ Compression:
  │  ├─ Codec: LZ4 (columnar)
  │  ├─ Typical: 50KB → 5KB (10:1 compression)
  │  └─ Retention: 7 days (configurable)
  │
  ├─ Indexing:
  │  ├─ Primary: trace_id (for trace retrieval)
  │  ├─ Secondary: span_name, service_name
  │  └─ Full-text: span attributes
  │
  └─ Write latency: 100-500ms

PHASE 6: METRICS AGGREGATION (OTEL Collector → Prometheus)
  ├─ Conversion: OTEL span data → Prometheus metrics
  ├─ Aggregations:
  │  ├─ Span counter: traces_received_total
  │  ├─ Duration histogram: span_duration_seconds (buckets: 1ms, 10ms, 100ms, 1s)
  │  ├─ Error rate: spans_error_total / spans_total
  │  ├─ Service latency: by span name (percentiles)
  │  │  - p50: 50th percentile
  │  │  - p95: 95th percentile
  │  │  - p99: 99th percentile
  │  │
  │  └─ Example metrics:
  │     otel_traces_received_total{service="api"} 1000
  │     otel_span_duration_seconds_bucket{span_name="GET /api", le="0.1"} 850
  │     otel_span_duration_seconds_bucket{span_name="GET /api", le="1.0"} 950
  │
  ├─ Prometheus scrape: Every 15 seconds
  └─ Aggregation latency: 50ms

PHASE 7: QUERY AND ANALYSIS
  ├─ Use case 1: Trace search (SigNoz UI)
  │  ├─ Query: Find all traces with duration > 1 second
  │  ├─ ClickHouse query:
  │  │  SELECT trace_id, duration_nano/1e9 as duration_sec
  │  │  FROM otel_traces
  │  │  WHERE duration_nano > 1e9
  │  │  LIMIT 100
  │  ├─ Processing: 200-1000ms
  │  └─ Display: Full trace waterfall with timing
  │
  ├─ Use case 2: Metrics dashboard (Prometheus)
  │  ├─ Query: Service latency p95
  │  ├─ Query expression:
  │  │  histogram_quantile(0.95, 
  │  │    rate(otel_span_duration_seconds_bucket[5m])
  │  │  )
  │  ├─ Processing: 100-500ms
  │  └─ Display: Time series graph
  │
  └─ Use case 3: Service dependency map (SigNoz)
     ├─ Analysis: Find all inter-service calls
     ├─ Processing: Build graph from span relationships
     └─ Display: Service topology with error rates

PHASE 8: METRICS VISUALIZATION (Prometheus → Grafana)
  ├─ Query: Response time distribution
  ├─ Prometheus query:
     rate(otel_span_duration_seconds_sum[5m]) /
     rate(otel_span_duration_seconds_count[5m])
  ├─ Result: Average latency per 5-minute window
  └─ Visualization: Area chart over time
```

**Total Trace Pipeline Latency**:
- Span generation: <1ms
- Batching: 0-10s (on batch timeout)
- Network export: 50-100ms
- Collector processing: 50-200ms
- ClickHouse storage: 100-500ms
- **Total**: 0.2-10.8 seconds (depends on batch timeout)
- **Trace available for query**: ~500ms after span completion

**Data Volume Example**:

```
1 request spans hierarchy:
  - Root span: HTTP request (1 span)
  - Handler spans: 3 business logic (3 spans)
  - DB spans: 5 queries (5 spans)
  - Total per request: 9 spans

Request rate: 1000 requests/second
Span rate: 9000 spans/second
Span size: ~300 bytes average

Memory buffer:
  - Batch size: 512 spans = 150KB
  - Queue size: 2000 spans = 600KB

ClickHouse storage:
  - 1GB = ~3.3M spans = ~6 hours at 1000 req/s
  - 7-day retention = 604.8M spans = 200GB uncompressed
  - After compression: ~20GB (10:1 ratio)
```

---

## Query Pipeline

### Grafana Dashboard Query → Prometheus → User Display

**Overview**: User views a Grafana dashboard, which queries Prometheus backend and displays results.

**Process Flow**:

```
REQUEST PHASE:
  1. User opens Grafana dashboard
     URL: http://grafana:3000/d/cpu-metrics/CPU-Usage

  2. Browser loads dashboard JSON definition
     └─ Associated 5 panels (graphs)
     └─ Each panel has a Prometheus query

  3. Each panel initiates background query
     ├─ Panel 1: Instant query (current value)
     ├─ Panels 2-5: Range queries (time series)
     └─ All queries run in parallel

INSTANT QUERY EXAMPLE (Panel 1):
  ├─ Query: up{job="netdata"}
  ├─ Time: Present time (e.g., 1705000000)
  ├─ Request to Prometheus:
  │  GET /api/v1/query?query=up{job="netdata"}&time=1705000000
  │
  ├─ Prometheus processing:
  │  ├─ Step 1: Find all series matching selector {job="netdata"}
  │  ├─ Step 2: Locate samples at timestamp 1705000000
  │  ├─ Step 3: Evaluate "up" metric
  │  ├─ Step 4: Return 0 (down) or 1 (up)
  │  └─ Time: 50-100ms
  │
  ├─ Response (JSON):
     {
       "status": "success",
       "data": {
         "resultType": "vector",
         "result": [
           {
             "metric": {"job": "netdata", "instance": "netdata:19999"},
             "value": [1705000000, "1"]
           }
         ]
       }
     }
  │
  └─ Browser displays: "✓ UP" (green indicator)

RANGE QUERY EXAMPLE (Panel 2):
  ├─ Query: rate(netdata_system_cpu_usage[5m])
  ├─ Time range: last 24 hours
  ├─ Step: 1 minute (data point every minute)
  ├─ Request to Prometheus:
  │  GET /api/v1/query_range?
  │      query=rate(netdata_system_cpu_usage[5m])
  │      &start=1704913600  (24h ago)
  │      &end=1705000000    (now)
  │      &step=60           (1 minute)
  │
  ├─ Prometheus processing:
  │  ├─ Step 1: Select metric: netdata_system_cpu_usage
  │  ├─ Step 2: For each minute -> generate data point
  │  │  └─ Retrieve 5-minute window of raw data
  │  │  └─ Calculate rate: delta/5min
  │  ├─ Step 3: Return 1440 data points (24h × 60m)
  │  └─ Time: 200-500ms (more complex calculation)
  │
  ├─ Response (JSON with 1440 points):
     {
       "status": "success",
       "data": {
         "resultType": "matrix",
         "result": [
           {
             "metric": {"instance": "netdata:19999"},
             "values": [
               [1704913660, "0.233"],  ← 1st minute
               [1704913720, "0.245"],  ← 2nd minute
               ...
               [1705000000, "0.189"]   ← last minute
             ]
           }
         ]
       }
     }
  │
  └─ Browser renders: Line graph with 1440 points

PARALLEL QUERY EXECUTION:
  Time 0:    Grafana initiates 5 queries (batched or sequential)
  Time 50:   Query 1 (instant) returns
             Query 2 (range) starts computing
  Time 250:  Query 2-5 (range queries) return
  Time 300:  Dashboard rendering begins
  Time 500:  Dashboard fully rendered to user

BROWSER RENDERING:
  ├─ Load CSS, JavaScript
  ├─ Parse JSON responses
  ├─ Create plot data structure
  ├─ Draw SVG/Canvas elements
  │  ├─ Grid lines
  │  ├─ Axes and labels
  │  ├─ Line paths for each series
  │  ├─ Legend
  │  └─ Hover tooltips
  ├─ Attach event listeners
  └─ Paint to screen
  │
  └─ Time: 200-500ms

TOTAL DASHBOARD LOAD TIME:
  Network round-trip: 50ms
  Prometheus query: 250ms
  Response transfer: 50ms
  Browser render: 300ms
  ────────────────────
  Total: ~650ms
```

**Query Performance Factors**:

```
Instant Query: 50-100ms
├─ Factors:
│  ├─ Time needed to find series (~10ms)
│  ├─ Database access time (~20-40ms)
│  └─ Network latency (~10-50ms)

Range Query (24h × 1m): 200-500ms
├─ Factors:
│  ├─ Series selection (~10ms)
│  ├─ Data access (1440 points × 10ms = ~200ms)
│  ├─ Range function evaluation (~50ms)
│  ├─ Serialization to JSON (~50ms)
│  └─ Network latency (~10-50ms)

Range Query (1 year × 1h): 500-2000ms
├─ Factors:
│  ├─ Large scan: 8760 points = long I/O time
│  ├─ Data access: ~1000ms
│  └─ Aggregation overhead
```

---

## Notification Pipeline

### Alert → Alertmanager → Multiple Channels

**Overview**: A single fired alert can be routed to multiple notification destinations based on rules.

**Example Scenario**: CPU alert fires on production server

```
Prometheus fires alert:
{
  "alertname": "HighCpuUsage",
  "severity": "critical",
  "environment": "production",
  "service": "web-api"
}

Alertmanager routing rules:
├─ Match severity=critical → critical receiver
│  └─ Receiver: critical-pagerduty, critical-slack
│
├─ Match service=web-api → service receiver
│  └─ Receiver: team-web-api (Slack channel)
│
└─ Default → Default receiver
   └─ Receiver: default-email

Resulting notifications sent to (parallel):
1. PagerDuty (critical)
   ├─ Action: Create incident
   ├─ Escalation: Page on-call engineer
   ├─ Latency: 200-1000ms
   ├─ Retries: 3 attempts over 5 minutes

2. Slack #critical-alerts (critical)
   ├─ Channel mention: @critical-notifications
   ├─ Format: Red alert with CPU details
   ├─ Latency: 100-500ms
   ├─ Retries: 3 attempts

3. Slack #team-web-api (team-specific)
   ├─ Channel mention: @web-api-team
   ├─ Format: Alert summary with link to dashboard
   ├─ Latency: 100-500ms
   └─ Retries: 3 attempts

4. Email to ops-team@company.com (default)
   ├─ Subject: "CRITICAL: High CPU Usage on prod-web-01"
   ├─ Body: Full alert details with graphs
   ├─ Latency: 1-10 seconds (SMTP)
   └─ Retries: 3 attempts

Total notifications: 4 messages to 3 channels
Delivery guarantee: At-least-once
  (May receive duplicates if retry happens)

Deduplication:
├─ By: alertname + labels (job, instance, severity, service)
├─ Window: 5 minutes
└─ Effect: Same alert not repeated if still firing

Silencing:
├─ User can silence: "HighCpuUsage on prod-web-01 for 1 hour"
├─ Effect: No notifications sent during window
├─ Storage: Persistent in Alertmanager
└─ Use: Maintenance windows, known issues
```

---

## Real-Time Flow Diagrams

### Complete System Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Infra Health Monitor - Data Flow                  │
└─────────────────────────────────────────────────────────────────────────┘

SOURCE TIER:
┌─────────────┐  ┌──────────────┐  ┌────────────────┐  ┌──────────────┐
│  Netdata    │  │ Uptime Kuma  │  │   Tracing SDK  │  │  Prometheus  │
│ :19999/expt │  │ API :3001    │  │ → OTEL :4317   │  │  Self-mon    │
└──────┬──────┘  └──────┬───────┘  └────────┬───────┘  └──────┬───────┘
       │                │                   │                 │
       │                │                   │                 │
       │                │                   │                 │
       ▼                ▼                   ▼                 ▼
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    ┃           PROMETHEUS (Metrics Hub, Port 9090)           ┃
    ┃  ┌─ Netdata Scrape Job     (15s interval)              ┃
    ┃  ├─ Uptime Exporter Job    (30s interval)              ┃
    ┃  ├─ OTEL Collector Job     (15s interval)              ┃
    ┃  ├─ Alert Manager Job      (15s interval)              ┃
    ┃  └─ Prometheus Self-Mon    (15s interval)              ┃
    ┃                                                          ┃
    ┃  Alert Rules:                                           ┃
    ┃  - Evaluation interval: 15 seconds                     ┃
    ┃  - 7 alert rules defined                               ┃
    ┃  - State tracking: inactive/pending/firing             ┃
    ┗━━━━━━━━━━━┬━━━━━━━━━━━━━━━━━━━━━━━━━━┬━━━━━━━━━━━━┛
                │ (When alerts fire)        │ (Dashboard queries)
                ▼                          │
    ┌────────────────────────┐            │
    │  ALERTMANAGER (9093)   │            │
    │ ┌─ Routing Rules      │            │
    │ ├─ Receivers          │            ▼
    │ │  ├─ Email (SMTP)   │        ┌──────────────┐
    │ │  ├─ Slack          │        │   GRAFANA    │
    │ │  └─ PagerDuty      │        │   (3000)     │
    │ └─ Silences           │        │ ┌─ Dashboards
    │ └─ Notifications      │        │ ├─ Queries
    └────────┬──────────────┘        │ └─ Visualization
             │                       └──────┬───────┘
             │                             │
             │ (Notifications) ┌──────────┘
             │                 │
             ▼                 ▼
    ┌─────────────────────────────────────┐
    │    Notification Channels             │
    │ ├─ Email (ops-team@company.com)    │
    │ ├─ Slack (#alerts, #team-x)        │
    │ ├─ PagerDuty (incidents)           │
    │ └─ Webhooks (custom integrations)  │
    └─────────────────────────────────────┘
                    │
                    │
                    ▼
            ┌────────────────┐
            │  On-Call Teams │
            │  Operators     │
            │  Automated     │
            │  Remediation   │
            └────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│ PARALLEL FLOW: Application Tracing (SigNoz Path)                        │
└─────────────────────────────────────────────────────────────────────────┘

Instrumented Applications
        │
        ├─→ Web Service A (requests → spans)
        ├─→ Web Service B (requests → spans)
        └─→ API Gateway (requests → spans)
             │
             ▼
    OpenTelemetry SDK
    ├─ Batching (512 spans/batch, 10s timeout)
    ├─ Serialization (protobuf)
    └─ OTLP Export (gRPC)
             │
             ▼
    OpenTelemetry Collector :4317
    ├─ Receivers: OTLP gRPC, HTTP
    ├─ Processors: Memory limiter, Batch
    └─ Exporters:
       ├─→ SigNoz ClickHouse (traces)
       ├─→ Prometheus :8888 (metrics)
       └─→ Jaeger (optional)
             │
             ├──────────────────┬──────────────────┐
             ▼                  ▼                  ▼
      SigNoz ClickHouse  Prometheus TSDB   Jaeger Backend
      (Trace Storage)    (SPAN METRICS)    (Trace Viewing)
             │                  │                  │
             └──────────┬───────┴──────────┬───────┘
                       ▼                  ▼
                 SigNoz UI          Prometheus Queries
                 (Jaeger UI)        (Grafana Dashboards)
                       │                  │
                       └─────────────────┬┘
                                         ▼
                            On-Call / Operations Team
```

---

## Performance Analysis

### Latency SLA Targets

```
Operation                          Target    Typical   99th %ile
────────────────────────────────────────────────────────────────
Metric collection (Netdata)         5s       3-5s      10s
Prometheus scrape                  <1s       0.5s      2s
Metric storage (TSDB write)        <100ms    50ms      200ms
Query (instant, 1 point)           <100ms    50ms      200ms
Query (range, 24h)                 <500ms    300ms     1000ms
Query (range, 1 year)              <2s       1s        5s
Dashboard load (5 panels)          <2s       1s        3s
Alert rule evaluation              15s       15s       15s
Alert firing latency               <1s       500ms     2s
Notification delivery (email)      <10s      5s        30s
Notification delivery (Slack)      <1s       500ms     2s
Notification delivery (PagerDuty)  <1s       700ms     3s
Trace span available (SigNoz)      <1s       500ms     2s
Distributed trace query latency    <2s       1s        5s
```

### Throughput Capacity

```
Metric Series:
├─ Per service: 1000-5000 unique metrics
├─ Total in system: 10,000-50,000 (configurable)
├─ Samples per minute: ~1,000,000
├─ Network bandwidth: ~50-100 Mbps

Alert Evaluation:
├─ Alert rules: ~10-50 rules
├─ Evaluation frequency: 15 seconds
├─ Rules per evaluation: Parallel (CPU-bound)
├─ Processing time: 100-500ms per evaluation

Span Throughput:
├─ Spans per second (typical): 100-1000
├─ Spans per second (peak): 5000-10000
├─ Batch size: 512 spans
├─ Batches per minute: ~12-120

Notification Throughput:
├─ Alerts per minute: 1-10 (warning)
├─ Alerts per minute: 0-5 (critical)
├─ Notifications per alert: 2-5 destinations
├─ Total notifications/min: 2-50
```

---

## Data Volumetrics

### Storage Requirements

```
Prometheus Time-Series Database:
├─ Retention: 30 days rolling
├─ Series: 10,000 unique metric combinations
├─ Samples per second: ~1000 (10,000 × 0.1 intervals)
├─ Compression: ~1 byte per sample (highly variable)
├─ Daily storage: ~100-500 MB/day
├─ 30-day storage: ~3-15 GB
├─ Growth rate: Linear with metric cardinality

SigNoz ClickHouse:
├─ Retention: 7 days (configurable)
├─ Span rate: 100-1000 spans/sec
├─ Bytes per span: ~300-500 bytes (uncompressed)
├─ Daily spans: 8.6-86 billion
├─ Uncompressed storage: ~2.5-40 TB/day
├─ Compressed (10:1): ~250 GB-4 TB/day
├─ 7-day storage: ~1.75-28 TB (compressed)

Alertmanager:
├─ Active alerts at any time: 0-100
├─ Storage: ~1-2 MB (silences, configurations)
├─ Logs: ~50-100 MB/day (depending on alert volume)

Grafana:
├─ Database (PostgreSQL): ~100-500 MB
│  ├─ Users: 10-100
│  ├─ Dashboards: 10-50
│  ├─ Datasources: 2-10
│  └─ Annotations: ~1-10 MB
│
└─ Typical growth: ~10-50 MB/month

Total System Storage:
├─ Minimum (development): ~10 GB
├─ Typical (small production): ~50-100 GB
├─ Large production: ~500 GB-5 TB
└─ Ultra-scale: >5 TB
```

### Network Bandwidth

```
Prometheus Scraping:
├─ Target: netdata (Prometheus exporter format)
├─ Size per scrape: ~1-2 MB
├─ Frequency: 15 seconds
├─ Bandwidth: ~500-1000 Kbps (aggregated)

OTLP Export:
├─ Span batch: ~50 KB (gzipped, typically 10 KB)
├─ Frequency: Every 10 seconds (batch timeout)
├─ Bandwidth: ~8-50 Kbps

Uptime Kuma Exporter:
├─ Response: ~10-100 KB
├─ Frequency: 30 seconds
├─ Bandwidth: ~5-30 Kbps

Grafana Queries:
├─ Query response: ~100 KB - 1 MB
├─ Frequency: Variable (per user)
├─ Bandwidth: User-dependent

Total Typical: ~500 Kbps - 2 Mbps intra-container
External:     Variable (notifications depend on rules)
```

---

## Related Documentation

- [Integration Guide](INTEGRATION_GUIDE.md) - Service configuration and setup
- [Metric Naming Conventions](METRIC_NAMING.md) - Labels and metric standards
- [Troubleshooting Guide](TROUBLESHOOTING_INTEGRATION.md) - Common issues and solutions


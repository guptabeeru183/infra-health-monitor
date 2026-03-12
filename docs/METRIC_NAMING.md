# Metric Naming Conventions and Standards

Complete guide to Prometheus metric naming, label standards, and Netdata metric mappings.

## Table of Contents

1. [Prometheus Naming Conventions](#prometheus-naming-conventions)
2. [Label Standards](#label-standards)
3. [Netdata Metric Mappings](#netdata-metric-mappings)
4. [Unit Suffixes](#unit-suffixes)
5. [Metric Types](#metric-types)
6. [Cardinality Control](#cardinality-control)
7. [Metric Query Examples](#metric-query-examples)
8. [Instrumentation Guidelines](#instrumentation-guidelines)

---

## Prometheus Naming Conventions

### Core Principles

1. **Lowercase with underscores**: `cpu_usage_percent`, `memory_bytes_total`
2. **Meaningful names**: Reflect what is measured, not how it's measured
3. **Consistency**: Use same names across all services
4. **Suffixes for types**: Include type indicator (_total, _seconds, _bytes, _percent)

### Metric Naming Format

```
<namespace>_<subsystem>_<name>_<unit>
     │          │        │      └─ Optional: s, bytes, percent
     │          │        └─ What is being measured
     │          └─ Component or service
     └─ Product or service name
```

**Examples**:

```
● System Metrics (Netdata)
  node_cpu_seconds_total        ← CPU time in seconds
  node_filesystem_free_bytes    ← Disk free space
  node_network_receive_bytes    ← Network RX bytes
  node_memory_MemAvailable_bytes← Available RAM

● Application Metrics
  http_request_duration_seconds       ← Request latency histogram
  http_requests_total                 ← Request counter
  database_query_duration_seconds     ← Query latency
  cache_hits_total                    ← Cache hit counter

● Monitoring System Metrics
  prometheus_tsdb_symbol_table_size_bytes  ← TSDB metadata size
  alertmanager_alerts                     ← Active alerts count
  scrape_duration_seconds                 ← Scrape operation latency

● Custom Metrics
  uptime_monitor_up                   ← Availability (1=up, 0=down)
  uptime_monitor_response_time_ms     ← Response latency in milliseconds
  otel_spans_received_total           ← Received span counter
```

### Naming Patterns by Type

#### Counters (monotonically increasing)

**Pattern**: `<name>_total`

```
● Always cumulative from service start
● Only increase or reset
● Use for: Requests, errors, transactions

Examples:
  http_requests_total{method="GET",path="/api/users"}
  errors_total{service="api",severity="critical"}
  disk_writes_total{device="sda"}
  uptime_monitor_downtime_events_total
```

#### Gauges (can go up or down)

**Pattern**: `<name>` (no suffix) or `<name>_current`

```
● Value can increase or decrease
● Used for: Current utilization, temperature, count

Examples:
  node_cpu_usage_percent
  node_memory_usage_bytes
  prometheus_tsdb_metric_chunks_created
  http_requests_in_progress
  uptime_monitor_response_time_ms
```

#### Histograms (request latencies, response sizes)

**Pattern**: `<name>_seconds` or `<name>_bytes`

```
● Measures distribution of values
● Creates 3 metrics: _bucket, _sum, _count

Examples:
  http_request_duration_seconds_bucket{le="0.001"}
  http_request_duration_seconds_bucket{le="0.01"}
  http_request_duration_seconds_bucket{le="0.1"}
  http_request_duration_seconds_bucket{le="1.0"}
  http_request_duration_seconds_bucket{le="+Inf"}
  http_request_duration_seconds_sum
  http_request_duration_seconds_count
  
Query for p95:
  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

#### Summaries (percentiles without histograms)

**Pattern**: `<name>_seconds` or `<name>_bytes`

```
● Pre-computed quantiles
● Provides: _sum, _count, and quantiles

Examples:
  request_latency_seconds{quantile="0.5"}   ← p50
  request_latency_seconds{quantile="0.9"}   ← p90
  request_latency_seconds{quantile="0.99"}  ← p99
  request_latency_seconds_sum
  request_latency_seconds_count
```

---

## Label Standards

### Required Labels

All metrics should include these labels:

| Label | Purpose | Example Values | CardinityRisk |
|-------|---------|-----------------|----------------|
| `job` | Scrape job name | netdata, prometheus, uptime-kuma | Low (5-10 values) |
| `instance` | Target endpoint | netdata:19999, prometheus:9090 | Low (10-100 values) |
| `service` | Service name | api, database, cache | Low (5-20 values) |
| `environment` | Deployment tier | dev, staging, prod | Very Low (3 values) |

### Optional Labels (by use case)

```
System Metrics:
├─ device         (sda, eth0)           → Cardinality: low (5-50)
├─ mode           (user, system, idle)   → Cardinality: very low (4)
└─ filesystem     (/dev/sda1)            → Cardinality: medium (10-100)

Network Metrics:
├─ interface      (eth0, lo)             → Cardinality: low (5-20)
├─ protocol       (tcp, udp)             → Cardinality: very low (2-3)
└─ direction      (receive, transmit)    → Cardinality: very low (2)

Application Metrics:
├─ method         (GET, POST, PUT)       → Cardinality: low (10-20)
├─ path           (/api/users, /health) → Cardinality: MEDIUM-HIGH ⚠
├─ status         (200, 404, 500)        → Cardinality: low (10-30)
└─ team           (platform, infra)      → Cardinality: low (5-10)

Process Metrics:
├─ pid            (1, 234, 567)          → Cardinality: VERY HIGH ⚠⚠⚠
├─ comm           (python, nginx)        → Cardinality: low (5-20)
└─ state          (running, sleeping)    → Cardinality: very low (5)

Database Metrics:
├─ database       (postgres, mysql)      → Cardinality: low (3-5)
├─ table          (users, orders)        → Cardinality: MEDIUM-HIGH ⚠
└─ operation      (SELECT, INSERT)       → Cardinality: low (5)

⚠ = May exceed cardinality limits; use relabeling to limit
```

### Label Value Guidelines

**Allowed characters**: `a-z`, `A-Z`, `0-9`, `_`, `:`, `-`

**Format rules**:
- Use lowercase letters when possible
- Replace spaces with underscores
- Keep values short (< 100 characters)
- Avoid high-cardinality values in labels

**Good Examples**:
```
job="netdata"          ✓ Lowercase, clear
instance="host01"      ✓ Simple identifier
path="/api/users"      ✓ Actual path
status="200"           ✓ HTTP code as string
```

**Bad Examples**:
```
job="NetDataExporter"  ✗ Mixed case
path="/api/users/123/orders/456/items"  ✗ Variable data (cardinality bomb!)
status="200 OK"        ✗ Contains space
```

### Label Relabeling (Prometheus)

**Purpose**: Add, remove, or modify labels during scrape

**Common patterns**:

```yaml
# 1. Add static label
relabel_configs:
  - source_labels: []
    target_label: team
    replacement: platform

# 2. Copy from another label
relabel_configs:
  - source_labels: [__meta_docker_container_name]
    target_label: container_name

# 3. Keep only specific targets
relabel_configs:
  - source_labels: [__address__]
    regex: 'localhost.*'
    action: keep    # Drop if doesn't match

# 4. Drop sensitive labels
metric_relabel_configs:
  - source_labels: [__name__]
    regex: '.*api_key.*'
    action: drop    # Never export

# 5. Rename metric
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'netdata_(.+)'
    target_label: __name__
    replacement: node_${1}
```

---

## Netdata Metric Mappings

### Netdata → Prometheus Naming

Netdata uses hierarchical naming: `chart.dimension`

**Mapping process**:

```
Netdata Chart:    system.cpu
├─ Dimension:     user
├─ Dimension:     system
├─ Dimension:     iowait
└─ Dimension:     guest

Netdata metric:   system.cpu.user     → Value: 10% (0-100)
Prometheus conversion:
  raw:    netdata_system_cpu_usage{dimension="user"} 1000m (0-100000m)
  after:  node_cpu_seconds_total{mode="user"} 452000  (cumulative seconds)
          ↑                                      ↑
          Renamed via relabel_configs           Normalized to seconds
```

### Common Netdata Charts and Prometheus Equivalents

#### CPU Metrics

```
Netdata:
  system.cpu                 ← Primary CPU metrics
  └─ Dimensions: user, system, nice, iowait, irq, softirq, steal, guest

Prometheus (after relabeling):
  node_cpu_seconds_total{mode="user"}      ← User-space CPU seconds
  node_cpu_seconds_total{mode="system"}    ← Kernel-space CPU seconds
  node_cpu_seconds_total{mode="iowait"}    ← I/O wait time
  node_cpu_seconds_total{mode="irq"}       ← Hardware interrupt time
  
Query examples:
  rate(node_cpu_seconds_total{mode="user"}[5m]) * 100    ← CPU % per 5m
  avg(node_cpu_seconds_total) by (mode)                  ← Average by type
```

#### Memory Metrics

```
Netdata:
  system.memory              ← Memory utilization
  └─ Dimensions: free, buffers, cached, used

Prometheus:
  node_memory_MemTotal_bytes    ← Total RAM
  node_memory_MemFree_bytes     ← Free RAM
  node_memory_Buffers_bytes     ← Buffer memory
  node_memory_Cached_bytes      ← Cached memory
  node_memory_MemAvailable_bytes← Available
  
Derived metrics:
  (1 - (node_memory_MemFree_bytes / node_memory_MemTotal_bytes)) * 100
    → Memory usage percentage
```

#### Disk I/O Metrics

```
Netdata:
  disk.io                    ← Disk I/O operations
  ├─ Dimensions: reads, writes
  
  disk.iops                  ← I/O operations per second
  ├─ Dimensions: reads, writes

Prometheus:
  node_disk_reads_completed_total{device="sda"}
  node_disk_writes_completed_total{device="sda"}
  node_disk_read_bytes_total{device="sda"}
  node_disk_write_bytes_total{device="sda"}
  
Derived metrics:
  rate(node_disk_reads_completed_total[5m])           ← Read IOPS
  rate(node_disk_read_bytes_total[5m]) / 1024 / 1024  ← Read throughput (MB/s)
```

#### Network Metrics

```
Netdata:
  net.eth0                   ← Network interface stats
  ├─ Dimensions: received, sent

Prometheus:
  node_network_receive_bytes_total{device="eth0"}
  node_network_receive_packets_total{device="eth0"}
  node_network_transmit_bytes_total{device="eth0"}
  node_network_transmit_packets_total{device="eth0"}
  
Derived metrics:
  rate(node_network_receive_bytes_total{device="eth0"}[5m]) / 1024 / 1024
    → Network RX throughput (MB/s)
```

#### Process Metrics

```
Netdata:
  processes                  ← Process counts
  ├─ Dimensions: running, sleeping, zombie

Prometheus:
  node_processes_state{state="running"}
  node_processes_state{state="sleeping"}
  node_processes_state{state="zombie"}
  
Gauge:
  node_procs_running       ← Number of running processes
  node_procs_blocked       ← Number of blocked processes
```

#### Filesystem Metrics

```
Netdata:
  disk.space                 ← Filesystem usage
  ├─ Series per mount point

Prometheus:
  node_filesystem_size_bytes{mountpoint="/"}
  node_filesystem_avail_bytes{mountpoint="/"}
  node_filesystem_files{mountpoint="/"}
  node_filesystem_files_free{mountpoint="/"}
  
Derived metrics:
  (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
    → Disk usage percentage
```

### Complete Netdata Metric Mapping Table

```
Netdata Chart          Netdata Dimension    Prometheus Metric (remapped)
────────────────────  ──────────────────   ────────────────────────────────
system.cpu             user                 node_cpu_seconds_total{mode="user"}
system.cpu             system               node_cpu_seconds_total{mode="system"}
system.cpu             iowait               node_cpu_seconds_total{mode="iowait"}
system.cpu             irq                  node_cpu_seconds_total{mode="irq"}
system.cpu             softirq              node_cpu_seconds_total{mode="softirq"}
system.cpu             nice                 node_cpu_seconds_total{mode="nice"}
system.cpu             steal                node_cpu_seconds_total{mode="steal"}
system.cpu             guest                node_cpu_seconds_total{mode="guest"}

system.memory          free                 node_memory_MemFree_bytes
system.memory          used                 node_memory_Used_bytes
system.memory          buffers              node_memory_Buffers_bytes
system.memory          cached               node_memory_Cached_bytes

disk.io                reads                node_disk_reads_completed_total
disk.io                writes               node_disk_writes_completed_total

disk.iops              reads                node_disk_reads_completed_total
disk.iops              writes               node_disk_writes_completed_total

net.<if>               received             node_network_receive_bytes_total
net.<if>               transmitted          node_network_transmit_bytes_total

processes              running              node_procs_running
processes              sleeping             node_procs_sleeping
processes              zombie               node_procs_zombie

disk.space             free                 node_filesystem_avail_bytes
disk.space             used                 node_filesystem_used_bytes
```

---

## Unit Suffixes

### Standardized Suffixes

```
Base unit (none):
  ├─ Count of items: requests_total, errors_total
  └─ Percentage: cpu_usage_percent (0-100)

Time:
  ├─ Seconds: duration_seconds, latency_seconds, uptime_seconds
  ├─ Milliseconds: response_time_ms (for external APIs, less standard)
  └─ Microseconds: latency_microseconds (rarely used)

Data:
  ├─ Bytes: request_size_bytes, memory_usage_bytes
  ├─ Kilobytes: cache_size_kilobytes (uncommon, use bytes)
  └─ Megabytes: disk_size_megabytes (uncommon, use bytes)

Temperature:
  ├─ Celsius: cpu_temperature_celsius
  └─ Kelvin: air_temperature_kelvin

Ratio:
  ├─ Percent (0-100): cpu_usage_percent, disk_usage_percent
  ├─ Ratio (0-1): compression_ratio, error_rate_ratio
  └─ Parts per million: ppm_threshold

Boolean/Status:
  └─ No suffix: up (1=success, 0=failure)
     service_available (1=available, 0=unavailable)
```

### Unit Declaration in Prometheus

**Metric metadata** (optional but recommended):

```
# HELP node_cpu_seconds_total Seconds CPU spent in different modes
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{mode="user"} 12345.6

# HELP node_memory_MemFree_bytes Free memory in bytes
# TYPE node_memory_MemFree_bytes gauge
node_memory_MemFree_bytes 1073741824

# HELP http_request_duration_seconds HTTP request latency distribution
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.001"} 10
```

---

## Metric Types

### Counter (Monotonically Increasing)

```
Characteristics:
├─ Only increases or resets
├─ Never decreases
├─ Suffix: _total
└─ Prometheus type: counter

Use cases:
├─ Total requests processed
├─ Total errors encountered
├─ Total bytes transmitted
└─ Total number of completed transactions

Example:
  http_requests_total{method="GET",path="/api/users"} 150000
  Error_processing_total 523
  
Query (rate of increase):
  rate(http_requests_total{path="/api/users"}[5m])
    → Average requests per second over last 5 minutes
```

### Gauge (Current Value)

```
Characteristics:
├─ Can increase or decrease
├─ Represents current state
├─ No suffix (or _current)
└─ Prometheus type: gauge

Use cases:
├─ Current CPU usage
├─ Current memory usage
├─ Number of connections
├─ Queue depth

Example:
  node_cpu_usage_percent 45.2
  database_connections_active 23
  cache_items_in_memory 1024
  
Query (aggregation):
  avg(node_cpu_usage_percent)      → Average CPU across instances
  max(node_cpu_usage_percent)      → Peak CPU usage
```

### Histogram (Distribution)

```
Characteristics:
├─ Measures latency or size distribution
├─ Creates 3 metrics: _bucket, _sum, _count
├─ Pre-defined buckets (configurable)
├─ Suffix: _seconds or _bytes
└─ Prometheus type: histogram

Buckets example:
  http_request_duration_seconds_bucket{le="0.001"} 100    (0-1ms)
  http_request_duration_seconds_bucket{le="0.01"}  500    (0-10ms)
  http_request_duration_seconds_bucket{le="0.1"}   750    (0-100ms)
  http_request_duration_seconds_bucket{le="1.0"}   900    (0-1s)
  http_request_duration_seconds_bucket{le="+Inf"} 1000   (all)
  http_request_duration_seconds_sum 47.5                  (total time)
  http_request_duration_seconds_count 1000                (count)

Derived metrics:
  95th percentile (p95):
    histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
  
  Average latency:
    rate(http_request_duration_seconds_sum[5m]) /
    rate(http_request_duration_seconds_count[5m])
```

### Summary (Pre-computed Percentiles)

```
Characteristics:
├─ Percentiles computed by SDK
├─ Creates: _sum, _count, and quantile labels
├─ Suffix: _seconds or _bytes
└─ Prometheus type: summary (less preferred than histogram)

Example:
  request_latency_seconds{quantile="0.5"} 0.045   (p50/median)
  request_latency_seconds{quantile="0.9"} 0.234   (p90)
  request_latency_seconds{quantile="0.99"} 1.023  (p99)
  request_latency_seconds_sum 47500               (total)
  request_latency_seconds_count 1000              (count)

Note: Histograms preferred over summaries for better aggregation
```

---

## Cardinality Control

### Cardinality Explained

**Cardinality** = Number of unique label combinations

```
Example:
  http_request_duration_seconds
  {method="GET", path="/api/users", status="200"}
  {method="GET", path="/api/users", status="404"}
  {method="POST", path="/api/orders", status="200"}
  {method="POST", path="/api/orders", status="400"}
  {method="POST", path="/api/orders", status="500"}

Cardinality = 5 unique combinations

Formula:
  Cardinality = label_1_values × label_2_values × label_3_values...
  
  Example:
    method_values = 5 (GET, POST, PUT, DELETE, PATCH)
    path_values = 50 (different API endpoints)
    status_values = 10 (HTTP status codes)
    
    Total cardinality = 5 × 50 × 10 = 2,500 series for this metric alone!
```

### Cardinality Warning Thresholds

```
Cardinality Level    Impact              Recommended Action
─────────────────    ──────────────────  ─────────────────────────────
< 1,000              None                OK, no action needed
1,000 - 10,000       Minimal              Monitor, may increase memory
10,000 - 50,000      Moderate            Review label design
50,000 - 100,000     High                ⚠ Action required
> 100,000            Critical            🚨 Immediately fix
> 1,000,000          System overload     🔴 Potential OOM crash
```

### High-Cardinality Labels (Danger!)

```
❌ DO NOT USE as labels:
  ├─ User IDs                   → 1M+ unique values
  ├─ Request IDs                → Unlimited unique values
  ├─ Timestamps                 → Different every second
  ├─ Full file paths            → Thousands per host
  ├─ Query parameters           → Dynamic, user input
  ├─ IPv4 addresses             → 4B possible values
  └─ Full HTTP request bodies   → Unbounded

Example of BAD cardinality explosion:
  http_requests_total{user_id="123", ip="192.168.1.50", query="param=xyz"}
      ↑                ↑ 1M users    ↑ 1000s IPs      ↑ Unbounded params
    Could easily have 1T+ cardinality → System crash!

✅ INSTEAD, use:
  http_requests_total{path="/api/users", status="200"}
     ← Limited to number of endpoints × HTTP statuses (~500 max)
```

### Cardinality Management Strategies

#### 1. Metric Relabeling (Drop High-Cardinality)

```yaml
# Drop requests with variable/high cardinality labels
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'http_requests'
    action: keep
  
  - source_labels: [query_param]
    regex: '.*'
    action: drop  # Remove dynamic label
    
  # Keep only stable labels
  - target_label: __tmp_cardinality_check
    replacement: ''
```

#### 2. Aggregation (Hide Cardinality)

```
Instead of:
  GET /api/users/1    → /api/users/{user_id}           (unbounded)
  
Use:
  Aggregated as:      → /api/users                      (1 value)
  
  http_requests_total{path="/api/users"} 50000
```

#### 3. Sampling (Store Subset)

```
Don't record all requests:
  100% sampling = 1M requests/sec = explosion!
  
Instead:
  1% sampling = 10K requests/sec = manageable
  Keep p99 latency accuracy with sampling
```

#### 4. Limits in Prometheus Config

```yaml
# Prevent scrape from going over cardinality limit
scrape_configs:
  - job_name: netdata
    targets: ['netdata:19999']
    
    # Drop series if cardinality exceeds this
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'netdata_.*'
        action: keep
      
      # Limit to important metrics only
      - source_labels: [__name__]
        regex: 'netdata_(system|memory|disk|network)_.*'
        action: keep
      
      # Drop high-cardinality dimensions
      - source_labels: [__name__]
        regex: 'netdata_.*(process|thread)_.*'
        action: drop  # Processes change frequently
```

### Cardinality Monitoring

```bash
# Check cardinality in Prometheus:
query = count(count by (__name__) (netdata_))

# Find highest cardinality metrics:
query = topk(10, count by (__name__) {job="netdata"})

# Count by label:
query = count by (path) (http_requests_total) > 500

# Fix high-cardinality:
1. Identify metric: count(http_requests_total) > 10000
2. Check labels: count by (path) (http_requests_total)
3. Add relabel rule to drop or aggregate
4. Verify: Re-run count query
```

---

## Metric Query Examples

### Common Queries

#### CPU Metrics

```promql
# Current CPU usage percentage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU usage by mode (user vs system)
rate(node_cpu_seconds_total[5m]) * 100

# Highest CPU usage across all hosts
max by (instance) (rate(node_cpu_seconds_total{mode="user"}[5m]) * 100)

# 95th percentile CPU usage (last hour)
histogram_quantile(0.95, rate(node_cpu_seconds_total[1h]))
```

#### Memory Metrics

```promql
# Memory usage percentage
100 * (1 - (node_memory_MemFree_bytes / node_memory_MemTotal_bytes))

# Available memory in GB
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Memory pressure (used memory percentage)
100 * ((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 
       node_memory_MemTotal_bytes)
```

#### Disk Metrics

```promql
# Disk usage percentage
100 * (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes))

# Disk I/O throughput (MB/s)
rate(node_disk_read_bytes_total[5m]) / 1024 / 1024

# IOPS (operations per second)
rate(node_disk_reads_completed_total[5m])

# Disk space left (GB)
node_filesystem_avail_bytes / 1024 / 1024 / 1024
```

#### Network Metrics

```promql
# Network throughput (MB/s) - RX
rate(node_network_receive_bytes_total{device="eth0"}[5m]) / 1024 / 1024

# Network throughput (MB/s) - TX
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) / 1024 / 1024

# Packet loss rate
rate(node_network_receive_drop_total[5m]) / rate(node_network_receive_packets_total[5m])
```

#### HTTP Request Metrics

```promql
# Request rate (requests per second)
rate(http_requests_total[5m])

# Request rate by method
rate(http_requests_total[5m]) by (method)

# Success rate (200-299 status codes)
rate(http_requests_total{status=~"2.."}[5m]) /
rate(http_requests_total[5m]) * 100

# Error rate (5xx status codes)
rate(http_requests_total{status=~"5.."}[5m]) /
rate(http_requests_total[5m]) * 100

# Request latency - p50
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))

# Request latency - p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Request latency - p99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

#### Availability Metrics

```promql
# Service up/down status
up{job="my-service"}

# Service availability percentage (last day)
100 * (count by (instance) (rate(up[1d])) == 1)

# Uptime from Uptime Kuma exporter
uptime_monitor_up{monitor="api"}

# Monitor response time (milliseconds)
uptime_monitor_response_time_ms

# Monitor availability percentage
uptime_monitor_uptime_percent
```

### Advanced Queries

#### Multi-series Aggregation

```promql
# Average of metric across all hosts
avg(rate(node_cpu_seconds_total[5m]))

# Per-host average
avg by (instance) (rate(node_cpu_seconds_total[5m]))

# Sum (useful for counters)
sum(rate(http_requests_total[5m]))

# Top 5 values
topk(5, rate(http_requests_total[5m]))

# Bottom 5 values
bottomk(5, rate(http_requests_total[5m]))

# Standard deviation (variance)
stddev(rate(http_request_duration_seconds[5m]))
```

#### Time-based Analysis

```promql
# Rate of change
rate(metric[5m])

# Increase over period
increase(metric[1h])

# Absolute change
metric - metric offset 1h

# Derivative (second derivative = acceleration)
deriv(rate(metric[5m]))

# Predict linear trend
predict_linear(metric[1h], 10m)  # 10 minutes into future
```

#### Conditional Queries

```promql
# Boolean conditions
up == 1                  # Service is up

# Comparison
cpu_usage_percent > 80   # High CPU

# Range
memory_usage_bytes >= 1024*1024*1024  # >= 1GB

# Matching patterns
metric{path=~"/api/v[12]/.*"}  # Regex match

# String equality
status == "active"               # Exact match
```

---

## Instrumentation Guidelines

### Application Instrumentation

When adding Prometheus metrics to your application:

#### 1. Choose the Right Metric Type

```
Counter:
  ├─ request_count (total processed)
  ├─ error_count (total errors)
  └─ transaction_count (total completed)

Gauge:
  ├─ queue_depth (current size)
  ├─ connection_pool_active (open connections)
  └─ cache_size (current bytes)

Histogram:
  ├─ request_duration_seconds
  ├─ response_size_bytes
  └─ database_query_duration_seconds

Summary:
  └─ Not recommended (histogram preferred)
```

#### 2. Avoid High Cardinality

```python
# ❌ BAD: User ID in label (1M+ unique values)
http_requests.labels(user_id=request.user_id).inc()

# ✅ GOOD: Aggregated by endpoint
http_requests.labels(path="/api/users", method="GET").inc()

# ❌ BAD: Full request body
errors.labels(message=exception.message).inc()

# ✅ GOOD: Error type
errors.labels(error_type=type(exception).__name__).inc()
```

#### 3. Example Code (Python)

```python
from prometheus_client import Counter, Gauge, Histogram

# Define metrics
requests_total = Counter(
    'my_app_requests_total',
    'Total HTTP requests',
    ['method', 'path', 'status']
)

request_duration = Histogram(
    'my_app_request_duration_seconds',
    'HTTP request latency distribution',
    ['method', 'path']
)

active_connections = Gauge(
    'my_app_active_connections',
    'Number of active database connections'
)

# Use metrics
@app.route('/api/users')
def get_users():
    start = time.time()
    try:
        users = database.get_users()
        status = '200'
    except Exception as e:
        status = '500'
    finally:
        duration = time.time() - start
        requests_total.labels(
            method='GET',
            path='/api/users',
            status=status
        ).inc()
        request_duration.labels(
            method='GET',
            path='/api/users'
        ).observe(duration)
    
    return users
```

#### 4. Naming Guidelines

```python
# Use module prefix
database_query_duration_seconds    # db-related
api_request_duration_seconds       # API-related
cache_hit_ratio                    # cache-related

# Use descriptive names
✅ http_request_duration_seconds
❌ request_time
❌ latency

# Suffix by unit
✅ memory_bytes
❌ memory_mb

✅ duration_seconds
❌ duration_ms
```

#### 5. Documentation

```promql
# Example metric definition with documentation
HELP my_app_requests_total Total number of HTTP requests
TYPE my_app_requests_total counter
HELP my_app_request_duration_seconds HTTP request latency distribution
TYPE my_app_request_duration_seconds histogram
```

---

## Related Documentation

- [Integration Guide](INTEGRATION_GUIDE.md) - Service configuration
- [Data Flow Architecture](DATA_FLOW.md) - Metrics pipeline
- [Troubleshooting Guide](TROUBLESHOOTING_INTEGRATION.md) - Common issues
- [Prometheus Documentation](https://prometheus.io/docs/practices/naming_and_labeling/) - Official guide


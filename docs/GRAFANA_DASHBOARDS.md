# Grafana Dashboards - Complete Reference Guide

This document provides comprehensive guidance for using, customizing, and maintaining Grafana dashboards in the Infra Health Monitor system.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dashboards](#dashboards)
4. [Data Sources](#data-sources)
5. [User Guide](#user-guide)
6. [Customization](#customization)
7. [Dashboard Management](#dashboard-management)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## Overview

The Grafana dashboard infrastructure provides a unified monitoring interface for the entire infrastructure and application stack. All dashboards are provisioned via Infrastructure as Code (IaC) using JSON and YAML configuration files stored in git.

### Key Features

- **Multi-Data Source Integration**: Prometheus, SigNoz, Uptime Kuma, and optional datasources
- **Drill-Down Architecture**: Overview → Host Details → Service-Specific Analysis
- **Template Variables**: Dynamic filtering without dashboard duplication
- **Alert Annotations**: Critical events displayed inline on graphs
- **SLA Tracking**: 30-day uptime compliance metrics
- **Version Controlled**: All dashboard definitions in git for reproducibility
- **Infrastructure as Code**: Auto-provisioning on Grafana startup

### Access

- **URL**: http://localhost:3000 (default)
- **Default Admin**: admin / admin (change on first login)
- **Dashboard Folder**: Infrastructure (auto-created)

---

## Architecture

### Directory Structure

```
provisioning/
├── datasources/
│   └── datasources.yaml          # Auto-provisioned data sources
└── dashboards/
    ├── provider.yaml              # Provisioning configuration
    ├── 01-infrastructure-overview.json
    ├── 02-host-details.json
    ├── 03-applications.json
    ├── 04-uptime-monitoring.json
    ├── 05-logs-observability.json
    ├── 06-capacity-planning.json
    └── 07-alerting.json

scripts/
├── dashboard-backup.sh            # Export dashboards from Grafana
├── dashboard-restore.sh           # Import dashboards to Grafana
├── dashboard-validate.sh          # Validate JSON syntax
└── export-dashboards.sh           # Export UI changes back to files
```

### Provisioning Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Git Repository (Version Controlled)                         │
│  • provisioning/datasources/datasources.yaml               │
│  • provisioning/dashboards/*.json                          │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Docker Volume Mount                                         │
│  /etc/grafana/provisioning/                                │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Grafana Startup                                             │
│  • Reads provider.yaml                                     │
│  • Loads datasources                                       │
│  • Imports dashboards                                      │
│  • Sets up templating & annotations                        │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Operational Monitoring                                      │
│  • All dashboards available at http://localhost:3000       │
│  • Auto-refresh every 30 seconds (configurable)            │
│  • Template variables populated from Prometheus            │
└─────────────────────────────────────────────────────────────┘
```

---

## Dashboards

### 1. Infrastructure Overview Dashboard (01-infrastructure-overview.json)

**Purpose**: System-wide infrastructure health summary at a glance

**Location**: Infrastructure > Infrastructure Overview

**Key Metrics**:
- System Status (active host count)
- Active Alerts (critical alert count)
- Average CPU Usage (%)
- Average Memory Usage (%)
- CPU Usage Trend (past 1 hour)
- Memory Usage Trend (past 1 hour)
- Disk Space Status (pie chart)
- Active Services (UP/DOWN count)
- Network Throughput (RX/TX rates)

**Template Variables**:
- `$instance` - Filter by host
- `$job` - Filter by job type

**Time Range**: 1 hour (default)

**Refresh**: 30 seconds

**Use Cases**:
- Quick infrastructure health check at standups
- Identify hosts with high resource usage
- Monitor service availability
- Spot network bottlenecks

**How to Use**:
1. View dashboard at http://localhost:3000/d/infra-overview
2. Use variable dropdown to filter specific hosts
3. Click on panels to drill down to detailed dashboards
4. Hover over graphs to see detailed values

---

### 2. Per-Host/Service Details Dashboard (02-host-details.json)

**Purpose**: Detailed host-level metrics for capacity planning and troubleshooting

**Location**: Infrastructure > Host Details

**Key Metrics**:
- Host Selection display
- Current CPU Usage (gauge)
- Current Memory Usage (gauge)
- Current Disk Usage (gauge)
- System Uptime (last boot time)
- CPU Usage by Mode (user/system/iowait/guest breakdown)
- Memory Breakdown (total/available/used)
- Disk I/O (read/write throughput by device)
- Network Traffic (RX/TX per interface)
- Process Count (running/blocked)
- Recent Alerts (table of active alerts)

**Template Variables**:
- `$instance` - Select specific host (single-select)

**Time Range**: 6 hours (default, allows historical analysis)

**Refresh**: 30 seconds

**Use Cases**:
- Deep-dive into specific host performance issues
- Verify resources are available before deployment
- Correlate process activity with resource usage
- Review alert history for specific hosts

**How to Use**:
1. Select a host from the $instance dropdown
2. All panels automatically filter to that host
3. Review current resource gauges and trend graphs
4. Check recent alerts table for context
5. Adjust time range to analyze historical patterns

---

### 3. Application Monitoring Dashboard (03-applications.json)

**Purpose**: Application performance tracking and distributed tracing insights

**Location**: Infrastructure > Applications

**Key Metrics**:
- Request Rate (spans/second)
- Error Rate (error percentage)
- P50 Latency (median response time)
- P95 Latency (95th percentile)
- Request Rate by Service (time-series)
- Error Rate by Service (time-series)
- Latency Histogram (p50/p95/p99 percentiles)
- Top Slow Requests (service-wise slowest spans)
- Service Dependencies (relationship map)

**Data Sources**:
- SigNoz (OTEL Collector metrics)
- Prometheus (application metrics)

**Template Variables**:
- `$service` - Filter by application service (multi-select)

**Time Range**: 6 hours (default)

**Refresh**: 30 seconds

**Use Cases**:
- Monitor application response times
- Identify slow endpoints or services
- Track error rates across services
- Understand service dependency relationships
- Plan for performance optimization

**How to Use**:
1. Select one or more services from $service dropdown
2. Observe request rates and error percentages
3. Review latency percentiles to identify slow paths
4. Check service dependencies for cascade failures
5. Compare performance across different services

---

### 4. Uptime and Availability Dashboard (04-uptime-monitoring.json)

**Purpose**: Service availability tracking and SLA compliance

**Location**: Infrastructure > Uptime Monitoring

**Key Metrics**:
- Current Uptime Status (%)
- Average Response Time (ms)
- 30-Day Uptime Percentage (SLA metric)
- Uptime Trend (7-day view)
- Response Time Trend (7-day view)
- Uptime by Monitor (30-day SLA pie chart)
- Downtime Events (last 30 days table)
- Monitor Health Status (summary)

**Data Sources**:
- Uptime Kuma (external endpoint monitoring)

**Template Variables**:
- `$monitor` - Filter by uptime monitor (multi-select)

**Time Range**: 30 days (default, SLA-focused)

**Refresh**: 1 minute (less frequent for external monitoring)

**Use Cases**:
- Verify SLA compliance (typically 99%+ uptime)
- Track downtime incidents
- Monitor response time degradation
- Plan maintenance windows
- Report availability metrics to customers

**How to Use**:
1. View overall uptime and response time metrics
2. Use $monitor to filter specific endpoints
3. Review downtime events table for incident details
4. Check 30-day SLA percentage for compliance
5. Adjust time range to analyze specific periods

---

### 5. Logging and Observability Dashboard (05-logs-observability.json)

**Purpose**: Distributed tracing and observability metrics

**Location**: Infrastructure > Logs & Observability

**Key Metrics**:
- Total Spans Ingested (rate)
- Total Traces (count)
- Span Processing Latency (p95)
- OTEL Collector Status (health)
- Span Ingestion Rate (by collection method)
- Error Span Rate (by service)
- Trace Collection Efficiency (sampling status)
- Top Error Services (ranked by error count)
- Span Attributes Distribution (heatmap)

**Data Sources**:
- SigNoz (OTEL Collector)
- Prometheus (OTEL metrics)

**Template Variables**:
- `$service` - Filter by service

**Time Range**: 6 hours (default)

**Refresh**: 30 seconds

**Use Cases**:
- Monitor trace collection pipeline health
- Identify services with high error rates
- Verify sampling is working correctly
- Analyze trace attributes for optimization
- Debug distributed transaction issues

**How to Use**:
1. Monitor span ingestion rate for baseline
2. Check OTEL Collector status for health issues
3. Review error span rates by service
4. Examine sampling efficiency for cost optimization
5. Use single service selection for detailed analysis

---

### 6. Capacity Planning Dashboard (06-capacity-planning.json)

**Purpose**: Resource usage trends and capacity forecasting

**Location**: Infrastructure > Capacity Planning

**Key Metrics**:
- CPU Utilization Trend (90 days)
- Memory Utilization Trend (90 days)
- Disk Usage Trend (90 days)
- Peak Usage Periods (30-day heatmap)
- Resource Growth Rate (weekly)
- Network Throughput Trend (90 days)
- Resource Allocation Status
- Recommended Actions (based on trends)

**Template Variables**:
- `$instance` - Select host(s) for analysis (multi-select)

**Time Range**: 90 days (default, long-term planning)

**Refresh**: 1 hour (less frequent for capacity data)

**Use Cases**:
- Plan infrastructure upgrades
- Forecast resource requirements
- Budget allocation for expansion
- Identify resource-constrained hosts
- Optimize peak usage periods

**How to Use**:
1. Select specific hosts or all hosts via $instance
2. Review 90-day usage trends
3. Look for upward trends requiring upgrade
4. Check peak usage periods for scaling decisions
5. Compare recommendations based on growth rate

---

### 7. Alerting Dashboard (07-alerting.json)

**Purpose**: Alert management and incident tracking

**Location**: Infrastructure > Alerting

**Key Metrics**:
- Total Alerts (30 days)
- Critical Alerts (count)
- Warning Alerts (count)
- Average Alert Resolution Time
- Alert Timeline (30-day history)
- Alerts by Severity (pie chart)
- Alert Firing Frequency by Service
- Top Firing Alerts (last 7 days)
- Current Firing Alerts (table)
- Alert Distribution by Service and Severity (heatmap)
- MTTR by Service (Mean Time to Resolution)

**Template Variables**:
- `$service` - Filter by service

**Time Range**: 30 days (default)

**Refresh**: 30 seconds

**Use Cases**:
- Monitor alert volume and trends
- Identify problematic services (high alert frequency)
- Track mean time to resolution
- Plan on-call schedules
- Improve SLA compliance

**How to Use**:
1. Monitor alert counts for abnormal spikes
2. Check current firing alerts for action items
3. Review alert frequency by service for reliability focus
4. Analyze MTTR trends for process improvement
5. Use service filter for team-specific alerting

---

## Data Sources

### Available Data Sources

All data sources are automatically configured on Grafana startup via `provisioning/datasources/datasources.yaml`:

#### 1. Prometheus (Default)
- **URL**: http://prometheus:9090
- **Type**: Prometheus
- **Status**: Required
- **Metrics**: Infrastructure metrics from Netdata
- **Query Language**: PromQL

#### 2. SigNoz (OTEL Collector)
- **URL**: http://otel-collector:8888
- **Type**: Prometheus
- **Status**: Required for application monitoring
- **Metrics**: Application traces, telemetry, span metrics
- **Query Language**: PromQL (exported metrics)

#### 3. Uptime Kuma
- **URL**: http://uptime-kuma-exporter:5000
- **Type**: Prometheus
- **Status**: Required for uptime monitoring
- **Metrics**: External endpoint availability and response times
- **Query Language**: PromQL

#### 4. Optional: ClickHouse
- **Status**: Commented out, requires plugin
- **Use Case**: Direct trace database queries
- **Plugin**: grafana-clickhouse-datasource

#### 5. Optional: Loki
- **Status**: Commented out, requires plugin
- **Use Case**: Log aggregation and searching
- **Plugin**: grafana-loki-datasource

#### 6. Optional: Jaeger
- **Status**: Commented out, requires plugin
- **Use Case**: Distributed tracing visualization
- **Plugin**: grafana-jaeger-datasource

### Testing Data Source Connections

```bash
# Test Prometheus
curl -s http://prometheus:9090/api/v1/query?query=up | jq '.'

# Test SigNoz/OTEL
curl -s http://otel-collector:8888/metrics | grep otel_spans

# Test Uptime Kuma
curl -s http://uptime-kuma-exporter:5000/metrics | grep uptime_monitor
```

---

## User Guide

### Accessing Dashboards

1. **Open Grafana**: http://localhost:3000
2. **Login**: Use configured credentials
3. **Navigate**: Dashboards > Infrastructure > Select Dashboard
4. **Bookmark**: Recommended dashboards for quick access:
   - Infrastructure Overview (daily check)
   - Host Details (troubleshooting)
   - Alerting (incident response)

### Using Template Variables

#### Variable Dropdown

```
[Select Instance ▼]  [Select Job ▼]  [Select Service ▼]
```

**Features**:
- **Multi-Select**: Hold Shift/Ctrl while clicking
- **Search**: Type to filter options
- **All**: Select all available options
- **Clear**: Remove selection

**Example Workflows**:

```
# Filter to single host
Instance: prod-app-001
→ All panels show metrics for that host only

# Compare multiple hosts
Instance: prod-app-001, prod-app-002, prod-app-003
→ Time-series show separate lines for each host

# View all production services
Job: production
→ Panels aggregate all production items
```

#### Time Range Selection

**Quick Options** (top-right of dashboard):
- Last 5 minutes
- Last 1 hour
- Last 6 hours
- Last 24 hours
- Last 7 days
- Last 30 days

**Custom Range**:
```
From: 2024-03-01 00:00:00
To:   2024-03-31 23:59:59
```

### Panel Interactions

#### Hover
- **Hover over graph**: Shows value at exact time point
- **Hover over legend**: Highlights corresponding line

#### Click
- **Click panel title**: Opens panel in full-screen
- **Click legend item**: Toggle visibility of that series
- **Click graph section**: Zooms to time range

#### Drill-Down
- **Infrastructure Overview** → Click host name → **Host Details**
- **Host Details** → Click metric → **Capacity Planning**
- **Applications** → Click service → Service-specific view

### Exporting Data

#### Export as PNG
```
Panel menu (top-right) > Download as image
```

#### Export as CSV
```
Panel menu > Download as CSV
```

#### Share Link
```
Dashboard menu > Share Button > Link tab
→ Use generated link to share with team
```

---

## Customization

### Editing Dashboards

#### Option 1: Edit in Grafana UI (Recommended)

1. Open dashboard
2. Click **Edit** button (top-right)
3. Modify panels, variables, layout
4. Click **Save** to save changes
5. Use `./scripts/export-dashboards.sh` to export back to files

**Advantages**:
- Visual editor
- Real-time preview
- Immediate feedback
- No JSON editing required

**Workflow**:
```bash
# Make changes in UI
# Then export back to code
./scripts/export-dashboards.sh http://localhost:3000 <token> ./provisioning/dashboards

# Commit to git
git add provisioning/dashboards/
git commit -m "UI: Update dashboard layout and panels"
```

#### Option 2: Edit JSON Files (Advanced)

1. Edit dashboard JSON file in editor
2. Validate syntax: `jq . <dashboard.json>`
3. Validate with script: `./scripts/dashboard-validate.sh`
4. Restart Grafana: `docker-compose restart grafana`
5. Verify changes: Open dashboard in Grafana

**Example**: Changing panel title in JSON

```json
// Before
"title": "CPU Usage"

// After
"title": "CPU Usage (%)"
```

### Adding New Panels

#### Via UI (Recommended)

1. Open dashboard in Edit mode
2. Click **+ Add Panel**
3. Choose panel type
4. Configure query and options
5. Save dashboard
6. Export to files: `./scripts/export-dashboards.sh ...`

#### Via JSON (Advanced)

Add to `dashboard.panels` array:

```json
{
  "id": 99,
  "title": "New Panel",
  "type": "timeseries",
  "gridPos": {
    "h": 8,
    "w": 12,
    "x": 0,
    "y": 40
  },
  "targets": [
    {
      "expr": "your_prometheus_query",
      "refId": "A"
    }
  ]
}
```

### Creating Custom Dashboards

#### Quick Start Template

```json
{
  "dashboard": {
    "title": "My Custom Dashboard",
    "description": "Dashboard description",
    "timezone": "browser",
    "schemaVersion": 38,
    "version": 1,
    "refresh": "30s",
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Panel 1",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {"expr": "your_metric", "refId": "A"}
        ]
      }
    ],
    "templating": {
      "list": [
        {
          "name": "var1",
          "type": "query",
          "datasource": "Prometheus",
          "definition": "label_values(metric, label_name)"
        }
      ]
    }
  },
  "overwrite": true
}
```

#### Common Queries

```promql
# CPU Usage
100 - (rate(node_cpu_seconds_total{mode="idle"}[5m]) * 100)

# Memory Usage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Disk Usage
100 * (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes))

# Network Throughput
rate(node_network_receive_bytes_total[5m]) / 1024 / 1024

# Service availability
count(up{job="prometheus"} == 1) / count(up{job="prometheus"})
```

---

## Dashboard Management

### Backup and Recovery

#### Backup All Dashboards

```bash
# Backup to directory with timestamp
GRAFANA_TOKEN=<your_token> ./scripts/dashboard-backup.sh \
  http://localhost:3000 \
  <token> \
  ./backups

# Creates:
# ./backups/backup_20240312_120000/
# ./backups/backup_20240312_120000.tar.gz
```

#### Restore from Backup

```bash
./scripts/dashboard-restore.sh \
  ./backups/backup_20240312_120000 \
  http://localhost:3000 \
  <token>
```

#### Backup Strategy

```bash
# Daily automated backup (cron job)
0 2 * * * cd /path/to/infra-health-monitor && \
  GRAFANA_TOKEN=$TOKEN ./scripts/dashboard-backup.sh \
  http://localhost:3000 $TOKEN ./backups

# Weekly git commit
0 4 * * 0 cd /path/to/infra-health-monitor && \
  git add backups/latest && \
  git commit -m "Weekly Grafana backup"
```

### Validation

```bash
# Validate all dashboards
./scripts/dashboard-validate.sh ./provisioning/dashboards

# Validate specific dashboard
jq . ./provisioning/dashboards/01-infrastructure-overview.json

# Check provisioning configuration
if command -v yq &>/dev/null; then
  yq eval '.' ./provisioning/datasources/datasources.yaml
fi
```

### Version Control

#### Git Workflow

```bash
# Check changes
git status provisioning/dashboards/

# Stage changes
git add provisioning/dashboards/

# Commit with descriptive message
git commit -m "Update Infrastructure dashboard with new panels"

# Push to remote
git push origin main

# Review changes
git log --oneline provisioning/dashboards/ | head -10
git show HEAD:provisioning/dashboards/01-infrastructure-overview.json
```

#### Handling Merge Conflicts

```bash
# If conflict occurs on JSON file:
# Option 1: Use ours (keep current branch)
git checkout --ours provisioning/dashboards/<file>

# Option 2: Use theirs (take incoming branch)
git checkout --theirs provisioning/dashboards/<file>

# Option 3: Manually resolve and re-export from UI
./scripts/export-dashboards.sh ... 
git add <file>
git commit --continue
```

### Monitoring Dashboard Health

#### Check Datasources Status

1. Grafana Admin Panel → Datasources
2. Verify all datasources show green "✓" status
3. If red, click datasource and test connection
4. Check Grafana logs: `docker logs <grafana-container>`

#### Check Provisioning Status

```bash
# Grafana Logs
docker logs <grafana-container> | grep provisioning

# Dashboard count
curl -s http://localhost:3000/api/dashboards/search | jq length

# Datasources status
curl -s http://localhost:3000/api/datasources | jq '.[] | {name, type, url}'
```

---

## Troubleshooting

### Dashboards Not Loading

**Error**: Dashboard shows "Loading..." indefinitely

**Solutions**:
1. Check Grafana logs: `docker logs <grafana-container>`
2. Verify datasources are connected: Admin > Datasources
3. Check network connectivity to data sources
4. Restart Grafana: `docker-compose restart grafana`
5. Clear browser cache: Ctrl+Shift+Delete

### Missing Metrics in Panels

**Error**: "No Data" or empty panels

**Solutions**:
1. Verify metric exists in Prometheus:
   ```bash
   curl http://localhost:9090/api/v1/query?query=metric_name
   ```
2. Check metric labels in Prometheus UI:
   - http://localhost:9090
   - Graph > Metrics dropdown

3. Verify PromQL query syntax:
   ```promql
   # Should return results
   up{job="prometheus"}
   
   # Check query in Prometheus UI first
   ```

4. Check time range - may need to expand to recent data

### Panel Query Errors

**Error**: Panel shows "Error" message

**Solutions**:
1. Click panel to see error details
2. Edit panel > Inspect > Logs to see error
3. Validate PromQL syntax in Prometheus UI
4. Check datasource selection (matches available datasource)
5. Verify labels exist in actual metrics

### Slow Dashboard Performance

**Solutions**:
1. Reduce time range (narrower = faster)
2. Increase query refresh interval
3. Optimize PromQL queries (avoid expensive operations)
4. Check Prometheus performance: Status > Targets
5. Reduce number of series per query

### Template Variables Not Populating

**Solutions**:
1. Verify variable datasource is connected
2. Check variable query returns results:
   ```promql
   label_values(metric_name, label)
   ```
3. Verify metric exists with that label
4. Refresh page: F5 or Ctrl+R
5. Check Grafana logs for variable errors

### Provisioning Not Loading Files

**Error**: Dashboards not appearing after file changes

**Solutions**:
1. Verify file path: `/etc/grafana/provisioning/dashboards/*.json`
2. Check file permissions: `chmod 644 *.json`
3. Validate JSON syntax: `jq . <file.json>`
4. Check provisioning config: `provider.yaml` syntax
5. Check update interval: `updateIntervalSeconds: 10`
6. Monitor provisioning: `docker logs <grafana>` | grep provisioning
7. Restart Grafana: `docker-compose restart grafana`

---

## Best Practices

### General Usage

1. **Time-based navigation**:
   - Use quick time range buttons for common intervals
   - Bookmark dashboards with pre-set time ranges

2. **Variable usage**:
   - Use multi-select for comparisons
   - Clear variables to see system-wide view
   - Use "All" option carefully (loads more data)

3. **Alert response**:
   - Go to Alerting dashboard first
   - Identify affected service
   - Drill down to specific host
   - Check recent logs/traces for context

### Customization

1. **Naming conventions**:
   - Use descriptive titles: "CPU Usage by Host" not "graph1"
   - Include units in title or unit field: "Response Time (ms)"
   - Use consistent naming across dashboards

2. **Panel organization**:
   - Place summary stats at top
   - Group related metrics together
   - Use consistent panel heights for visual balance
   - Larger time-series on bottom

3. **Query optimization**:
   - Use label_values() for variables
   - Limit query time ranges when possible
   - Aggregate at query time, not in visualization
   - Use recording rules for complex queries

### Documentation

1. **Dashboard descriptions**: Add purpose in description field
2. **Panel descriptions**: Use panel title and thresholds effectively
3. **Variable documentation**: Add help text in variable edit
4. **Commit messages**: Reference ticket numbers and describe changes

```bash
git commit -m "feat(dashboards): Add memory breakdown panel to host-details

- Add memory breakdown by type (cache, buffers, slab)
- Helps identify memory pressure sources
- Relates to JIRA-123: Memory optimization investigation"
```

### Team Workflows

1. **Development**:
   - Edit dashboards in Grafana UI
   - Export to files regularly
   - Create feature branches for major changes
   - Document changes in commit messages

2. **Review**:
   - Use git PR reviews for dashboard changes
   - Test dashboards in staging before production
   - Validate against all environments

3. **Deployment**:
   - Merge to main branch
   - Automatic provisioning on next Grafana restart
   - Monitor for errors in logs
   - Verify all panels display data

### Security

1. **API Token Management**:
   - Use strong, randomly generated tokens
   - Rotate tokens regularly
   - Use tokens with minimal required permissions (Viewer for backups)
   - Store tokens in environment variables, not config files

2. **Access Control**:
   - Limit dashboard editing to authorized users
   - Assign appropriate Grafana roles (Viewer, Editor, Admin)
   - Audit who made changes via git history

3. **Data Privacy**:
   - Be aware of sensitive metrics (auth failures, payment data)
   - Restrict dashboard viewing to appropriate teams
   - Use data source permissions for fine-grained control

---

## Advanced Topics

### Custom Panels and Plugins

Optional Grafana plugins for enhanced visualization:

```bash
# ClickHouse plugin (for direct trace queries)
docker exec grafana grafana-cli plugins install grafana-clickhouse-datasource

# Worldmap panel (for geographic distribution)
docker exec grafana grafana-cli plugins install grafana-worldmap-panel

# Clock panel (for time-based displays)
docker exec grafana grafana-cli plugins install ryantxu-clock-panel
```

### Alerting Integration

Dashboards support alert annotations:

```json
{
  "annotations": {
    "list": [
      {
        "name": "AlertName",
        "datasource": "Prometheus",
        "expr": "ALERTS{severity=\"critical\"}",
        "textFormat": "{{ alertname }}"
      }
    ]
  }
}
```

### Recording Rules

For high-volume metrics, use Prometheus recording rules:

```yaml
groups:
  - name: dashboard_recording_rules
    interval: 30s
    rules:
      - record: instance:cpu_usage:5m
        expr: 100 - (rate(node_cpu_seconds_total{mode="idle"}[5m]) * 100)

      - record: instance:memory_usage:5m
        expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

---

## Support and Contact

For dashboard issues:

1. Check this guide's Troubleshooting section
2. Review Grafana logs: `docker logs <grafana>`
3. Verify data sources are healthy
4. Check metric availability in Prometheus UI
5. Open an issue with:
   - Dashboard name and screenshot
   - Error message from logs
   - Steps to reproduce
   - Environment details

---

**Last Updated**: March 12, 2024
**Grafana Version**: 10.x
**Prometheus Version**: Compatible with 2.40+

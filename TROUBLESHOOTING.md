# Infra Health Monitor - Troubleshooting Guide

## Common Issues and Solutions

### Service Start Issues

#### Docker Daemon Not Running

**Symptom**: `Cannot connect to Docker daemon`

**Solution**:
```bash
# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify
docker ps
```

#### Port Already in Use

**Symptom**: Error like `Address already in use` or `port is already allocated`

**Solution**:
```bash
# Find what's using the port
netstat -tulpn | grep :3000

# Either:
# 1. Stop the process
sudo kill -9 <PID>

# 2. Or change the port in .env
GRAFANA_PORT=3001  # Change from 3000

# Then restart
docker-compose up -d
```

#### Insufficient Disk Space

**Symptom**: Docker pull errors or container start failures

**Solution**:
```bash
# Check disk usage
df -h /

# Clean up Docker
docker system prune -a

# Or increase allocation
# Modify /etc/docker/daemon.json
# Add: "data-root": "/mnt/docker-data"

# Remove old volumes (⚠️ DATA LOSS)
docker volume prune -f
```

#### Memory/Resource Constraints

**Symptom**: Services consuming excessive memory or crashing

**Solution**:
```bash
# Check resource usage
docker stats

# Increase Docker desktop resources:
# - Docker Desktop > Settings > Resources > Increase Memory/Swap

# Or modify docker-compose.yml:
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### Prometheus Issues

#### No Targets Available

**Symptom**: Prometheus Status > Targets shows all RED/DOWN

**Solution**:
```bash
# 1. Check service connectivity
docker exec monitoring-prometheus \
  curl -s http://netdata:19999/api/v1/info | head

# 2. Verify scrape config
docker exec monitoring-prometheus \
  cat /etc/prometheus/prometheus.yml

# 3. Check target is accessible from Prometheus container
docker exec monitoring-prometheus \
  curl -v http://target-service:port/metrics

# 4. Fix issues:
#    - Ensure target service is running
#    - Check hostname/IP resolution
#    - Verify port is correct
#    - Check firewall rules

# 5. Reload Prometheus
docker-compose restart prometheus
```

#### High Cardinality / Out of Memory

**Symptom**: Prometheus using excessive memory or OOMKilled

**Solution**:
```bash
# Check current cardinality
docker exec monitoring-prometheus \
  curl -s 'http://localhost:9090/api/v1/query?query=count(count%20by%20(__name__)%20(%7B__name__%21%3D%22%22%7D))' \
  | jq .

# If > 100k: implement metric filtering

# In prometheus.yml metric_relabel_configs:
metric_relabel_configs:
  # Drop high-cardinality metrics
  - source_labels: [__name__]
    regex: '(container_.*|kube_pod_labels)'
    action: drop
  
  # Or drop specific label combinations
  - source_labels: [le]
    regex: '.+'
    action: drop

# Restart
docker-compose restart prometheus
```

#### Queries Slow / Timeouts

**Symptom**: Query responses > 5 seconds or timeouts

**Solution**:
```bash
# Monitor query performance
docker exec monitoring-prometheus \
  curl -s http://localhost:9090/metrics | grep prometheus_tsdb

# Reduce time ranges in dashboards
# - Use shorter retention windows
# - Use lower resolution graphs
# - Implement recording rules

# Add recording rules to reduce query complexity
# In prometheus.yml:
rule_files:
  - /etc/prometheus/recording_rules.yml

# In recording_rules.yml:
groups:
  - name: cpu_rules
    interval: 15s
    rules:
      - record: instance:cpu:rate5m
        expr: rate(node_cpu_seconds_total[5m])
```

### Grafana Issues

#### Grafana Won't Start / Reset Admin Password

**Symptom**: Login fails or forgot admin password

**Solution**:
```bash
# Reset to default (admin/admin)
docker exec monitoring-grafana \
  grafana-cli admin reset-admin-password admin

# Or reset via database
docker exec monitoring-grafana \
  sqlite3 /var/lib/grafana/grafana.db \
  "UPDATE user SET password = '5f4dcc3b5aa765d61d8327deb882cf99' WHERE id = 1;"

# Restart
docker-compose restart grafana
```

#### Datasources Not Connecting

**Symptom**: Red/error status on Prometheus datasource

**Solution**:
```bash
# 1. Test connectivity from Grafana container
docker exec monitoring-grafana \
  curl -v http://prometheus:9090/api/v1/query

# 2. Check datasource configuration
# Grafana UI > Configuration > Data Sources > Edit

# Common issues:
# - URL should be: http://prometheus:9090 (internal name)
# - Not: http://localhost:9090 (from host)
# - Check service name matches docker-compose.yml

# 3. Re-save datasource to trigger test

# 4. Check Grafana logs
docker-compose logs grafana
```

#### Dashboards Not Displaying Data

**Symptom**: Grafana panels show "No data" or error messages

**Solution**:
```bash
# 1. Test metric directly in Prometheus
# Prometheus UI > Graph > Enter metric name
# Example: up{job="prometheus"}

# 2. If metric missing:
#    - Check target is UP in Prometheus targets
#    - Verify label matches dashboard query

# 3. If metric exists but not in dashboard:
#    - Edit panel > Check metric query
#    - Verify labels in query match available labels
#    - Test query in Prometheus UI first

# 4. Check dashboard JSON for syntax errors
# (Some versions have issues with non-standard queries)

# 5. Recreate dashboard if corrupted
docker-compose exec grafana curl -s http://prometheus:9090/api/v1/query?query=up
```

### Alertmanager Issues

#### Alerts Not Firing

**Symptom**: Alert rules exist but never fire

**Solution**:
```bash
# 1. Check rules are loaded
docker exec monitoring-prometheus \
  curl -s http://localhost:9090/rules | jq .

# 2. Verify rules syntax
# Rules should have "state: "firing" if condition met

# 3. Test rule manually
docker exec monitoring-prometheus \
  curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up{job="nonexistent"}'

# If query returns nothing, alert won't fire
# Add label conditions to rule

# 4. Check alert evaluation
# Prometheus UI > Alerts tab
# Should show: FIRING, PENDING, or INACTIVE
```

#### Notifications Not Sent

**Symptom**: Alerts fire but no Slack/email received

**Solution**:
```bash
# 1. Check Alertmanager configuration
docker exec monitoring-alertmanager \
  cat /etc/alertmanager/config.yml

# 2. Test alert routing
# Send test alert:
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "status":"firing",
    "labels":{"alertname":"TestAlert","severity":"critical"},
    "annotations":{"summary":"Test alert"}
  }]'

# 3. Check Alertmanager logs
docker-compose logs alertmanager

# 4. Verify notification settings:
#    - Slack: Test webhook with curl
curl -X POST $SLACK_WEBHOOK_CRITICAL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test message"}'

#    - Email: Check SMTP credentials in .env

# 5. Check silences aren't blocking
# Alertmanager UI > Silences
# Should be empty or not matching alert labels
```

### Netdata Issues

#### No Metrics from Netdata

**Symptom**: Netdata running but no metrics in Prometheus

**Solution**:
```bash
# 1. Check Netdata is running
docker-compose ps netdata

# 2. Test Netdata metrics endpoint
curl http://localhost:19999/api/v1/allmetrics | head -20

# 3. Check if Prometheus is actually scraping
curl http://localhost:9090/api/v1/targets | grep netdata

# 4. Check Prometheus config includes netdata
docker exec monitoring-prometheus \
  grep -A5 "job_name: 'netdata'" /etc/prometheus/prometheus.yml

# 5. If missing, add to scrape config
# Edit configs/prometheus-overrides/prometheus.yml
# Add:
# - job_name: 'netdata'
#   static_configs:
#     - targets: ['netdata:19999']

# 6. Reload Prometheus
docker-compose restart prometheus
```

#### Netdata High CPU Usage

**Symptom**: Netdata consuming excessive CPU

**Solution**:
```bash
# 1. Check collectors running
curl http://localhost:19999/api/v1/collectors | jq .

# 2. Disable expensive collectors
# Edit netdata.conf:
[plugins.cgroups]
  enabled = no

[plugins.tc]
  enabled = no

[plugins.debugfs.plugin]
  enabled = no

# 3. Increase log level
[global]
  log level = error  # Reduce logging overhead

# 4. Restart
docker-compose restart netdata
```

### SigNoz Issues

#### Logs Not Appearing in SigNoz

**Symptom**: ClickHouse running but no logs visible

**Solution**:
```bash
# 1. Check OpenTelemetry Collector
docker-compose logs signoz-otel-collector

# 2. Verify collector configuration
docker exec monitoring-signoz-otel-collector \
  cat /etc/otel-collector-config.yml

# 3. Test OTLP endpoint
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[]},"scopeLogs":[{"scope":{},"logRecords":[{"timeUnixNano":"1000000","body":{"stringValue":"test"}}]}]}]}'

# 4. Check ClickHouse database exists
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q "SHOW DATABASES;" | grep signoz

# 5. Check tables created
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q "SHOW TABLES FROM signoz;"
```

#### ClickHouse Out of Disk Space

**Symptom**: ClickHouse errors or ingest failures

**Solution**:
```bash
# 1. Check table sizes
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q \
  "SELECT table, formatReadableSize(total_bytes) FROM system.tables WHERE database='signoz';"

# 2. Delete old data
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q \
  "DELETE FROM signoz.logs WHERE timestamp < now() - INTERVAL 7 DAY;"

# 3. Implement TTL
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q \
  "ALTER TABLE signoz.logs MODIFY TTL timestamp + INTERVAL 30 DAY;"

# 4. Monitor free space
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -q "SELECT * FROM system.disks;"
```

### Uptime Kuma Issues

#### Monitors Not Checking

**Symptom**: Uptime Kuma running but monitors showing no status

**Solution**:
```bash
# 1. Check Uptime Kuma is accessible
curl http://localhost:3001/

# 2. Verify monitors are created
# Access: http://localhost:3001/

# 3. Check monitor configuration
# Edit monitor > Check URL, interval, etc.

# 4. If monitors won't save, check logs
docker-compose logs uptime-kuma

# 5. Check network connectivity from container
docker exec monitoring-uptime-kuma \
  curl -I https://example.com  # Test target

# 6. If target unreachable from container:
#    - Check firewall rules
#    - Verify DNS resolution
```

#### Metrics Not Exporting to Prometheus

**Symptom**: Uptime Kuma running but no metrics in Prometheus

**Solution**:
```bash
# 1. Check if Uptime Kuma has native Prometheus exporter
# (Depends on version)

# 2. If not native:
#    - Use custom exporter (integration/uptime-kuma-exporter.py)
#    - Or use API polling approach

# 3. Add to Prometheus scrape config
# Edit prometheus.yml
# - job_name: 'uptime-kuma'
#   static_configs:
#     - targets: ['uptime-kuma-exporter:5000']

# 4. Verify exporter running
curl http://localhost:5000/metrics
```

## Health Check Script

Create a comprehensive health check:

```bash
#!/bin/bash
# scripts/health-check.sh

echo "=== Infra Health Monitor Health Check ==="
echo ""

# Check Docker running
echo -n "Docker: "
if docker ps > /dev/null 2>&1; then
  echo "✓"
else
  echo "✗ Docker not running"
  exit 1
fi

# Check all services
for service in prometheus grafana alertmanager netdata signoz-query-service uptime-kuma; do
  echo -n "$service: "
  status=$(docker-compose ps $service | grep "Up" | wc -l)
  if [ $status -gt 0 ]; then
    echo "✓"
  else
    echo "✗"
  fi
done

# Check ports
echo ""
echo "Port Availability:"
for port in 3000 9090 9093 19999 3301 3001; do
  echo -n "  :$port "
  if nc -z localhost $port 2>/dev/null; then
    echo "✓"
  else
    echo "✗"
  fi
done

# Check storage
echo ""
echo "Storage Usage:"
du -sh /var/lib/docker/volumes/infra-monitor-* | awk '{print "  " $0}'

echo ""
echo "=== Health check complete ==="
```

## Getting Help

1. **Check Logs**: `docker-compose logs <service>`
2. **Review Documentation**: Check relevant .md file
3. **Test Connectivity**: Use `curl` from containers
4. **Check Docker Status**: `docker-compose ps`
5. **Review Configuration**: Check mounted files in containers

## Monitoring System Metrics

```bash
# CPU usage by service
docker stats --no-stream

# Disk usage
df -h / /var/lib/docker

# Memory
docker exec monitoring-prometheus free -h
```

---

Last Updated: March 2026
Troubleshooting Guide Version: 1.0

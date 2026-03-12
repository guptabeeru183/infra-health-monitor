# Troubleshooting Integration Issues

Complete troubleshooting guide for common Infra Health Monitor integration problems.

## Table of Contents

1. [Diagnostic Procedures](#diagnostic-procedures)
2. [Metric Collection Issues](#metric-collection-issues)
3. [Prometheus Scraping Issues](#prometheus-scraping-issues)
4. [Alert Issues](#alert-issues)
5. [Performance Issues](#performance-issues)
6. [Network and Connectivity](#network-and-connectivity)
7. [Data and Storage Issues](#data-and-storage-issues)
8. [Common Error Messages](#common-error-messages)

---

## Diagnostic Procedures

### Quick Health Check

Run these checks before deep troubleshooting:

```bash
#!/bin/bash
# Quick diagnostic script

echo "=== Service Status ==="
docker-compose ps

echo -e "\n=== Prometheus Health ==="
curl -s http://prometheus:9090/-/healthy && echo "OK" || echo "FAIL"

echo -e "\n=== Scrape Targets ==="
curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets | length'

echo -e "\n=== Alert Rules ==="
curl -s http://prometheus:9090/api/v1/rules | jq '.data.groups | length'

echo -e "\n=== Alertmanager Status ==="
curl -s http://alertmanager:9093/api/v1/status | jq '.data' && echo "OK" || echo "FAIL"

echo -e "\n=== Grafana Health ==="
curl -s http://grafana:3000/api/health && echo "OK" || echo "FAIL"

echo -e "\n=== Network Connectivity ==="
for service in prometheus alertmanager netdata grafana uptime-kuma uptime-kuma-exporter otel-collector signoz; do
  docker-compose exec $service ping -c 1 localhost >/dev/null 2>&1 && echo "$service: OK" || echo "$service: FAIL"
done
```

### Enabling Debug Logging

Most services support increased logging for troubleshooting:

```yaml
# docker-compose.yml modifications for debugging

services:
  prometheus:
    environment:
      - GOGC=75
    command:
      - '--log.level=debug'  # Add this

  alertmanager:
    environment:
      - LOG_LEVEL=debug

  netdata:
    environment:
      - LOG_LEVEL=debug

  uptime-kuma-exporter:
    environment:
      - LOG_LEVEL=DEBUG
```

Then check logs:

```bash
docker-compose logs -f prometheus | grep -i error
docker-compose logs -f alertmanager | grep -i error
docker-compose logs -f netdata | tail -100
```

---

## Metric Collection Issues

### Netdata Metrics Not Appearing in Prometheus

**Symptom**: Prometheus shows Netdata scrape target DOWN or no metrics

**Root Causes**:

1. **Netdata exporter not enabled**
   ```bash
   # Check Netdata config
   docker-compose exec netdata cat /etc/netdata/netdata.conf | grep -A5 "\[prometheus\]"
   
   # Should output:
   # [prometheus]
   #    enabled = yes
   
   # If missing or "enabled = no", restart with correct config
   docker-compose restart netdata
   ```

2. **Port 19999 not accessible**
   ```bash
   # Check if port is listening
   docker-compose exec netdata netstat -tlnp | grep 19999
   
   # Test from Prometheus container
   docker-compose exec prometheus curl -s http://netdata:19999/api/v1/info | jq '.version'
   
   # If connection refused, check network
   docker-compose exec prometheus ping -c 3 netdata
   ```

3. **Metrics format invalid**
   ```bash
   # Get raw exporter output
   curl http://netdata:19999/api/v1/allmetrics?format=prometheus | head -20
   
   # Should show proper Prometheus format:
   # netdata_system_cpu_usage{dimension="user"} 45.2
   # netdata_system_ram_used_bytes 8589934592
   
   # If not, Netdata is misconfigured
   ```

**Solution**:

```yaml
# configs/netdata-overrides/netdata.conf
[prometheus]
    enabled = yes
    
[global]
    memory mode = dbengine
    
[web]
    bind to = 0.0.0.0:19999
```

Then:
```bash
docker-compose restart netdata
sleep 10  # Wait for startup
curl http://localhost:19999/api/v1/allmetrics?format=prometheus | head -5
```

### Metrics Disappearing After Collection

**Symptom**: Metrics appear briefly in Prometheus, then disappear

**Root Causes**:

1. **High cardinality (too many label combinations)**
   ```bash
   # Count unique series
   curl 'http://prometheus:9090/api/v1/query?query=count(netdata_)' | jq '.data.result[].value[1]'
   
   # If > 10,000 for single job, investigate
   curl 'http://prometheus:9090/api/v1/query?query=count(netdata_) by (__name__)' | \
     jq '.data.result | sort_by(.[0][1] | tonumber) | reverse[0:5]'
   ```
   
   **Fix**: Update Prometheus scrape config to limit cardinality:
   ```yaml
   scrape_configs:
     - job_name: 'netdata'
       targets: ['netdata:19999']
       metric_relabel_configs:
         # Keep only important metrics
         - source_labels: [__name__]
           regex: 'netdata_(system|memory|disk|network|processes)_.*'
           action: keep
         # Drop high-cardinality process metrics
         - source_labels: [__name__]
           regex: 'netdata_.*_processes_.*'
           action: drop
   ```

2. **Prometheus storage full**
   ```bash
   # Check disk usage
   du -sh ./prometheus
   
   # If > 30GB, reduce retention
   docker-compose restart prometheus --arg='--storage.tsdb.retention.time=7d'
   
   # Check WAL directory
   du -sh ./prometheus/wal
   
   # If > 5GB, Prometheus is slow
   ```

3. **Network/scrape timeout**
   ```bash
   # Check scrape duration in Prometheus UI
   curl 'http://prometheus:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="netdata") | .scrapePool'
   
   # If scrape_duration > 10s, increase timeout
   scrape_timeout: 30s  # Increase from default 10s
   ```

**Solution**:

```bash
# Fix likely largest issue first:
1. Reload Prometheus with updated config:
   curl -X POST http://prometheus:9090/-/reload

2. Monitor for 5 minutes:
   watch -n 5 'curl -s http://prometheus:9090/api/v1/query?query=up{job=\"netdata\"}'

3. If still missing, check logs:
   docker-compose logs prometheus | grep -i error | tail -20
```

---

## Prometheus Scraping Issues

### Target Shows DOWN in Prometheus

**Symptom**: `http://prometheus:9090/targets` shows target with state = DOWN

**Investigation Steps**:

```bash
# 1. Get target details
curl -s http://prometheus:9090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.labels.instance=="target:port")'

# 2. Output shows: "labels", "health" (UP/DOWN), "lastError", "lastScrapeTime"
# Check lastError field:

curl -s http://prometheus:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {instance: .labels.instance, health: .health, error: .lastError}'

# 3. Based on error, troubleshoot:
```

**Common Errors and Solutions**:

#### A. "Get http://target:port: dial tcp: connection refused"

```bash
# Step 1: Check if target service is running
docker-compose ps netdata
# Should show "Up"

# Step 2: Check if port is listening
docker-compose exec netdata netstat -tlnp | grep 19999
# Should show "0.0.0.0:19999  LISTEN"

# Step 3: Test directly
curl http://netdata:19999/api/v1/info
# Should return JSON, not connection refused

# Step 4: Check network connectivity
docker-compose exec prometheus ping -c 2 netdata
# Should succeed

# Solutions:
# - Restart service: docker-compose restart netdata
# - Check network: docker network ls and verify services on same network
# - Verify port in Prometheus config matches actual port
```

#### B. "Get http://target:port: i/o timeout"

```bash
# Step 1: Check service responsiveness
timeout 5 curl http://netdata:19999/api/v1/allmetrics?format=prometheus | wc -l
# If timeout, service is too slow

# Step 2: Check network latency
docker-compose exec prometheus ping netdata
# PING should show < 10ms

# Step 3: Increase Prometheus timeout
# In prometheus.yml:
scrape_timeout: 30s  # Increase from 10s

# Step 4: Restart Prometheus
docker-compose restart prometheus

# Permanent fix: Optimize target or increase resources
```

#### C. "unexpected end of JSON input" or "invalid character"

```bash
# Step 1: Check exporter output format
curl -s http://netdata:19999/api/v1/allmetrics?format=prometheus | head -10
# Must show Prometheus format (not JSON)

# Step 2: Verify metrics_path
# In prometheus.yml for netdata job:
metrics_path: '/api/v1/allmetrics'
params:
  format: ['prometheus']

# Step 3: Test manually
curl -I http://netdata:19999/api/v1/allmetrics?format=prometheus
# Should get 200 OK, Content-Type: text/plain

# Fix: Verify Netdata is properly configured for Prometheus export
```

### All Targets DOWN

**Symptom**: All Prometheus scrape targets show DOWN

**Quick Checks**:

```bash
# 1. Is Prometheus running?
docker-compose ps prometheus

# 2. Basic connectivity
docker-compose exec prometheus curl -s http://localhost:9090/-/healthy

# 3. Check Prometheus logs
docker-compose logs prometheus --tail=50 | grep -i error

# 4. Check network
docker network ls
docker network inspect monitoring-net  # Verify all services are connected
```

**Solutions**:

```bash
# Restart all services in order:
docker-compose down
sleep 5
docker-compose up -d --wait

# Wait for services to be healthy (slow startup for SigNoz, ClickHouse)
sleep 30
docker-compose ps

# Verify targets:
curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets | length'
curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | {job, instance, health}' | head -20
```

---

## Alert Issues

### Alert Rules Not Loaded

**Symptom**: `curl http://prometheus:9090/api/v1/rules` returns empty or fewer rules than expected

**Investigation**:

```bash
# Check if alert file is referenced
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml | grep rule_files

# Should show:
# rule_files:
#   - /etc/prometheus/alert-rules.yml

# Check file exists
docker-compose exec prometheus ls -l /etc/prometheus/alert-rules.yml

# Check file syntax
docker-compose exec prometheus curl -s http://prometheus:9090/api/v1/rules | \
  jq '.data.groups | length'
# Should show > 0
```

**Solutions**:

```bash
# 1. Verify ruler volume mount
# In docker-compose.yml:
volumes:
  - ./configs/prometheus-overrides/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro

# 2. Create alert-rules.yml if missing
# Copy from repo to configs/prometheus-overrides/alert-rules.yml

# 3. Validate YAML syntax
docker-compose exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# 4. Reload Prometheus
curl -X POST http://prometheus:9090/-/reload

# 5. Verify loaded
curl -s http://prometheus:9090/api/v1/rules | jq '.data.groups[] | {file: .file, rules: .rules | length}'
```

### Alerts Not Firing

**Symptom**: Rules exist but no alerts are firing

**Investigation**:

```bash
# Check rule state
curl -s http://prometheus:9090/api/v1/rules | \
  jq '.data.groups[] | .rules[] | {name: .name, state: .state}'

# States: inactive (no match), pending (matched < for duration), firing (matched >= for duration)

# Test rule query directly
# Get example rule
QUERY=$(curl -s http://prometheus:9090/api/v1/rules | jq -r '.data.groups[0].rules[0].query')

# Execute query
curl -s "http://prometheus:9090/api/v1/query?query=$QUERY" | jq '.data'

# If query returns [] (empty), condition is false - expected if system is healthy
# If query returns results, should transition to firing after "for" duration

# Check "for" duration
curl -s http://prometheus:9090/api/v1/rules | \
  jq '.data.groups[] | .rules[] | {name: .name, for: .duration}'
# Example: "for": "300000000000" = 5 minutes
```

**Common Causes and Solutions**:

1. **Condition never true (query returns no matches)**
   - Expected behavior - metrics don't meet condition
   - Verify metrics exist: `curl 'http://prometheus:9090/api/v1/query?query=metric_name'`

2. **Waiting for "for" duration**
   - Default: 5 minutes before firing
   - To test, reduce "for" to 30s, then incre back to 5m

3. **Not sending to Alertmanager**
   ```bash
   # Check Alertmanager config
   curl -s http://prometheus:9090/api/v1/rules | jq '.data.groups[] | .rules[]'
   
   # Verify alertmanager receiver is configured
   grep -A5 "alerting:" /etc/prometheus/prometheus.yml
   
   # Check connectivity
   docker-compose exec prometheus curl -s http://alertmanager:9093/api/v1/status
   ```

### Alertmanager Not Receiving Alerts

**Symptom**: Alerts fire in Prometheus but not reaching Alertmanager

**Investigation**:

```bash
# Check Alertmanager is receiving
curl -s http://alertmanager:9093/api/v1/alerts | jq '.data | length'
# If 0, no alerts received

# Check Prometheus is configured to send
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml | grep -A3 alerting:

# Should show:
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: ['alertmanager:9093']

# Test connectivity from Prometheus
docker-compose exec prometheus curl -s http://alertmanager:9093/api/v1/status | jq '.data'

# Check Alertmanager logs
docker-compose logs alertmanager --tail=50 | grep -E '(error|alert|receive)'
```

**Solutions**:

```bash
# 1. Verify Prometheus alerting config
# In prometheus.yml:
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

# 2. Reload Prometheus
curl -X POST http://prometheus:9090/-/reload

# 3. Monitor Alertmanager API
# Keep one terminal open:
watch -n 2 'curl -s http://alertmanager:9093/api/v1/alerts | jq ".data | length"'

# 4. Trigger test alert manually
# Reduce alert "for" duration to 30s and see if fires within 30s
```

### Alert Rules Syntax Errors

**Symptom**: Rules not loading, error in Prometheus logs

**Investigation**:

```bash
# Use promtool to validate
docker-compose exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# Output shows:
# - Passed validation
# OR
# - Error: <specific error>: line XXX

# Common errors:
# 1. Indent error (YAML requires 2 spaces, not tabs)
# 2. Quote error (strings need quotes)
# 3. Invalid PromQL (metric doesn't exist yet)
```

**Solutions**:

```bash
# Example: Fix "error in alert evaluation" for alert "AlertName"

# 1. Check YAML structure
cat -A /etc/prometheus/alert-rules.yml | grep -A5 AlertName
# Check for mixed spaces/tabs (^ = tabs)

# 2. Fix common issues
# ❌ alert: AlertName        # Wrong: needs quotes if special chars
# ✅ alert: "AlertName"

# ❌ for: 5m                # Standalone number
# ✅ for: "5m"              # String

# 3. Test rule query in Prometheus UI
# Go to: http://prometheus:9090/graph
# Paste rule expr: node_cpu_seconds > 1000
# If "Executing" never completes, metric doesn't exist (wait for more data)

# 4. Reload after fix
curl -X POST http://prometheus:9090/-/reload
```

---

## Performance Issues

### High Memory Usage

**Symptom**: Prometheus/Alertmanager using > 4GB RAM, or OOM errors

**Investigation**:

```bash
# Check memory usage
docker-compose stats prometheus alertmanager

# If Prometheus > 2GB:
# Likely cause 1: High cardinality metrics
curl 'http://prometheus:9090/api/v1/query?query=count(count by (__name__) ())' | \
  jq '.data.result[0].value[1]'  # Total series count
# If > 100,000, too high!

# Likely cause 2: Long retention period
docker-compose ps prometheus | grep retention
# Check if running with large retention

# Likely cause 3: Large queries
# Watch for slow queries in logs:
docker-compose logs prometheus | grep "instant queries" | tail -5
```

**Solutions**:

```bash
# 1. Reduce cardinality (best solution)
# In prometheus.yml, add relabel_configs:
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'netdata_(system|memory|disk|network)_.*'
    action: keep  # Keep only essential metrics

docker-compose restart prometheus

# 2. Reduce retention period
# In docker-compose.yml command:
command:
  - '--storage.tsdb.retention.time=7d'  # Was 30d
  - '--storage.tsdb.retention.size=10GB'  # Add max size limit

docker-compose restart prometheus

# 3. Increase available memory
# In docker-compose.yml:
services:
  prometheus:
    mem_limit: 4g  # Physical limit

# 4. Monitor going forward
watch -n 10 'docker-compose stats prometheus | tail -1'
```

### Slow Queries

**Symptom**: Grafana dashboards take > 5 seconds to load

**Investigation**:

```bash
# Check slow query log
docker-compose logs prometheus | grep "query took" | tail -10

# It shows query duration:
# query took 2.345s  (too slow)

# Check which queries are slow
# In Prometheus UI: Status → TSDB → Query metadata
# Look for longest queries

# Check scrape duration
curl -s http://prometheus:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {instance: .labels.instance, duration: .scrapePool}'
# If scrapePool > 10s, scraper is slow
```

**Solutions**:

```bash
# 1. Reduce time range in Grafana queries
# Edit dashboard panels:
# Change: Last 7 days → Last 1 day
# Change: 1 minute granularity → 5 minute granularity

# 2. Reduce cardinality (most effective)
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'netdata_.*'
    action: keep

# 3. Increase Prometheus resources
docker-compose.yml:
  prometheus:
    mem_limit: 4g  # Increase from 2g
    cpus: "2.0"    # Increase from 1.0

# 4. Add query recording rules (pre-compute common queries)
# In alert-rules.yml:
groups:
  - name: recording_rules
    interval: 30s
    rules:
      - record: node:cpu:rate5m
        expr: rate(node_cpu_seconds_total[5m]) * 100
      - record: node:memory:used:pct
        expr: 100 * (1 - node_memory_MemFree_bytes / node_memory_MemTotal_bytes)

# Then use pre-computed in Grafana:
# Instead of: rate(node_cpu_seconds_total[5m])
# Use:        node:cpu:rate5m
```

### Uptime Kuma Exporter Slow

**Symptom**: Uptime Kuma exporter scrape takes 20+ seconds

**Investigation**:

```bash
# Time the exporter
time curl -s http://uptime-kuma-exporter:5000/metrics | wc -l

# Check Uptime Kuma API responsiveness
docker-compose exec uptime-kuma-exporter curl -w "Time: %{time_total}s\n" \
  -s http://uptime-kuma:3001/api/status/pages >/dev/null

# If > 5 seconds, Uptime Kuma API is slow
```

**Solutions**:

```bash
# 1. Reduce Prometheus scrape frequency
# In prometheus.yml:
scrape_configs:
  - job_name: 'uptime-kuma'
    scrape_interval: 60s  # Increase from 30s
    scrape_timeout: 30s   # Increase from 10s

# 2. Optimize Uptime Kuma API (outside scope)
# - Reduce number of monitors
# - Scale Uptime Kuma resources

docker-compose restart prometheus
```

---

## Network and Connectivity

### DNS Resolution Issues

**Symptom**: "unknown host" or "Name or service not known" errors

**Investigation**:

```bash
# Check Docker network
docker network ls | grep monitoring

# Verify services are on same network
docker-compose exec prometheus getent hosts netdata
# Should resolve to internal IP (e.g., 172.20.0.3)

# Test DNS from container
docker-compose exec prometheus ping -c 1 netdata
# Should work

docker-compose exec prometheus nslookup netdata
# Should resolve
```

**Solutions**:

```bash
# 1. Verify docker-compose network configuration
# In docker-compose.yml:
networks:
  monitoring-net:
    driver: bridge

services:
  prometheus:
    networks:
      - monitoring-net
  netdata:
    networks:
      - monitoring-net

# 2. Restart Docker network
docker network prune -f  # WARNING: removes unused networks

# 3. Recreate containers with network
docker-compose down
docker-compose up -d

# 4. Test again
docker-compose exec prometheus ping netdata
```

### Port Already in Use

**Symptom**: "Address already in use" or "bind: permission denied" when starting

**Investigation**:

```bash
# Check which process is using the port
lsof -i :9090  # Prometheus
lsof -i :3000  # Grafana
lsof -i :9093  # Alertmanager
lsof -i :19999 # Netdata

# Or use netstat
netstat -tlnp | grep :9090
```

**Solutions**:

```bash
# Option 1: Kill existing process
kill -9 <PID>

# Option 2: Change port in docker-compose.yml
services:
  prometheus:
    ports:
      - "9091:9090"  # External:Internal, changed from 9090:9090

# Option 3: Check for zombie containers
docker container ls -a | grep exited
docker container prune -f  # Remove stopped containers

# Then restart
docker-compose up -d
```

---

## Data and Storage Issues

### Prometheus Disk Full

**Symptom**: Disk space errors, Prometheus crashes, data loss

**Investigation**:

```bash
# Check disk usage
du -sh ./prometheus*
df -h ./prometheus

# Check specific directories
du -sh ./prometheus/{wal,blocks}

# Watch for growth
watch -n 5 'du -sh ./prometheus'
```

**Solutions**:

```bash
# Quick fix: Reduce retention
docker-compose down
rm -rf ./prometheus/wal ./prometheus/blocks

docker-compose up -d prometheus
# Prometheus will rebuild TSDB

# Better: Reduce retention time
# In docker-compose.yml:
command:
  - '--storage.tsdb.retention.time=7d'  # Reduce from 30d
  - '--storage.tsdb.retention.size=15GB'  # Add size limit

docker-compose restart prometheus

# Monitor going forward
watch -n 60 'du -sh ./prometheus'
```

### Data Gaps in Metrics

**Symptom**: Metrics missing for certain time ranges

**Investigation**:

```bash
# Check scrape logs
docker-compose logs prometheus | grep -E "error|failed|unreachable" | tail -20

# Check target availability during gap time
curl -s 'http://prometheus:9090/api/v1/targets' | \
  jq '.data.activeTargets[] | {instance, health, lastError}'

# Check metric coverage
curl -s 'http://prometheus:9090/api/v1/query?query=netdata_system_cpu_usage' | \
  jq '.data.result[].values | first, last'
# Shows first and last timestamps
```

**Solutions**:

```bash
# 1. Check what was happening at that time
docker-compose logs prometheus --since "2024-01-10T10:00:00Z" --until "2024-01-10T11:00:00Z" | \
  grep -i error

# 2. Common causes:
#    - Target was down: Check service logs
#    - Network issue: Check docker network
#    - Prometheus crashed: Check Prometheus logs
#    - Disk full: Check disk usage

# 3. Recover by:
#    - Restart affected service
#    - Increase target timeout if intermittent
#    - Scale resources if under capacity
```

---

## Common Error Messages

### "TSDB append sample: cannot create append iterator"

**Cause**: Prometheus WAL (Write-Ahead Log) corruption

**Solution**:
```bash
docker-compose down
rm -rf ./prometheus/wal
docker-compose up -d prometheus
# Data is safe in blocks/ directory, WAL is rebuilt
```

### "error sending alert: no valid targets"

**Cause**: Alertmanager not configured with receivers

**Solution**:
```bash
# Ensure alertmanager.yml has receivers defined:
cat > configs/alertmanager-overrides/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'ops-team@company.com'
EOF

docker-compose restart alertmanager
```

### "Get context deadline exceeded"

**Cause**: Query timeout, service too slow

**Solution**:
```bash
# Increase query timeout
# In docker-compose.yml, Prometheus command:
- '--query.timeout=2m'  # Increase from 30s default

docker-compose restart prometheus

# Or reduce query range in Grafana
```

### "Compaction failed: persistence error"

**Cause**: Prometheus storage corruption or permission issue

**Solution**:
```bash
# Check permissions
ls -la ./prometheus | head -5
# Should be readable by docker user

# Fix permissions
chmod 755 ./prometheus

# Or rebuild
docker-compose down
rm -rf ./prometheus/wal ./prometheus/blocks
docker-compose up -d
```

### "parse error: expected ':' but got '\\n'"

**Cause**: Alert rules YAML syntax error

**Solution**:
```bash
# Validate YAML
docker-compose exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# Fix common issues:
# - Use 2-space indentation (no tabs)
# - Quote string values
# - Check line numbers from error message

# Validate and reload
curl -X POST http://prometheus:9090/-/reload
```

---

## Quick Troubleshooting Matrix

| Problem | Quick Check | Likely Cause | Solution |
|---------|------------|--------------|----------|
| Netdata not in Prometheus | `curl http://netdata:19999/api/v1/info` | Service down or port wrong | Restart service, verify port |
| No metrics | `curl 'http://prometheus:9090/api/v1/query?query=up'` | Scrape failing | Check target health |
| Alerts not firing | `curl http://prometheus:9090/api/v1/rules` | No metrics or rules | Load rules, wait for metrics |
| Slow dashboards | `curl http://prometheus:9090/api/v1/targets` | Slow query or scrape | Reduce time range, cardinality |
| High memory | `docker-compose stats` | High cardinality | Add relabel_configs to limit |
| Port in use | `lsof -i :9090` | Zombie container | Kill process or change port |
| Disk full | `df -h ./prometheus` | Retention too long | Reduce retention time |

---

## Related Documentation

- [Integration Guide](INTEGRATION_GUIDE.md) - Configuration and setup
- [Data Flow Architecture](DATA_FLOW.md) - How data flows through system
- [Metric Naming](METRIC_NAMING.md) - Metric conventions
- [Testing Scripts](../scripts/) - Automated validation

## Getting Help

If issues persist:

1. **Collect diagnostics**:
   ```bash
   docker-compose ps > diagnostics.txt
   docker-compose logs --tail=100 >> diagnostics.txt
   curl -s http://prometheus:9090/api/v1/targets >> diagnostics.txt
   du -sh * >> diagnostics.txt
   ```

2. **Search documentation**:
   - Official Prometheus: https://prometheus.io/docs/
   - Netdata: https://learn.netdata.cloud/
   - Grafana: https://grafana.com/docs/

3. **Check container logs**:
   ```bash
   docker-compose logs <service> --tail=100 | grep -i error
   ```


# Infra Health Monitor - Deployment Guide

This guide covers deploying the Infra Health Monitor platform in development, staging, and production environments.

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, or similar)
- **Docker**: Version 20.10 or newer
- **Docker Compose**: Version 1.29 or newer
- **Disk Space**: Minimum 100GB (configurable based on retention)
- **RAM**: Minimum 8GB, 16GB+ recommended
- **Network**: Outbound HTTPS for notifications

### Verify Installation

```bash
# Check Docker
docker --version
# Expected: Docker version 20.10.0 or newer

# Check Docker Compose
docker-compose --version
# Expected: docker-compose version 1.29.0 or newer

# Check disk space
df -h /
# Needed: 100GB+ free space

# Check memory
free -h
# Needed: 8GB+ available
```

## Deployment Steps

### Step 1: Clone the Repository

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/your-org/infra-health-monitor.git
cd infra-health-monitor

# Or if already cloned without submodules
git submodule update --init --recursive
```

### Step 2: Initialize Environment

```bash
# Create configuration from template
cp .env.example .env

# Edit configuration for your environment
nano .env

# Critical variables to customize:
# - GRAFANA_ADMIN_PASSWORD
# - PROMETHEUS_RETENTION_TIME/SIZE
# - SMTP settings for email alerts
# - Slack webhook URL
# - Service ports (if conflicts)
```

### Step 3: Verify Docker Compose Configuration

```bash
# Validate syntax
docker-compose config

# Should complete without errors
```

### Step 4: Start the Stack

```bash
# Development: One-off startup
docker-compose up -d

# Or using Makefile
make up

# Verify services starting
docker-compose ps
```

### Step 5: Wait for Services to be Healthy

```bash
# Check health status
docker-compose ps

# Services should show:
# - monitoring-prometheus       (Up, healthy)
# - monitoring-grafana          (Up, healthy)
# - monitoring-alertmanager     (Up, healthy)
# - monitoring-netdata          (Up, healthy)
# - monitoring-signoz-*         (Up, healthy)
# - monitoring-uptime-kuma      (Up, healthy)

# Watch logs for startup issues
docker-compose logs -f

# Typical startup time: 2-5 minutes
```

### Step 6: Access Services

Once healthy, services are available at:

```
Grafana:       http://localhost:3000
  Username:    admin
  Password:    (from GRAFANA_ADMIN_PASSWORD in .env)

Prometheus:    http://localhost:9090
  (Metrics queries)

Alertmanager:  http://localhost:9093
  (Alert management)

Netdata:       http://localhost:19999
  (Real-time metrics)

SigNoz:        http://localhost:3301
  (Logs & Observability)

Uptime Kuma:   http://localhost:3001
  (Uptime Monitoring)
```

## Environment-Specific Configuration

### Development Deployment

```bash
# 1. Use .env.example defaults (minimal customization needed)
cp .env.example .env

# 2. Reduce retention for faster iteration
# Edit .env:
PROMETHEUS_RETENTION_TIME=3d
PROMETHEUS_RETENTION_SIZE=10GB

# 3. Enable debug logging
LOG_LEVEL=DEBUG

# 4. Start
docker-compose up -d
```

### Staging Deployment

```bash
# 1. Create staging-specific config
cp .env.example .env.staging

# 2. Customize for staging resources
GRAFANA_ADMIN_PASSWORD=<strong_password>
PROMETHEUS_RETENTION_TIME=7d
PROMETHEUS_RETENTION_SIZE=50GB
LOG_LEVEL=INFO

# 3. Start with override file
docker-compose -f docker-compose.yml up -d

# 4. Test full monitoring workflow
make test
```

### Production Deployment

```bash
# 1. Create production-specific config
cp .env.example .env.production

# 2. Customize for production
GRAFANA_ADMIN_PASSWORD=<VERY_STRONG_PASSWORD>
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_RETENTION_SIZE=500GB
LOG_LEVEL=WARN
SLACK_WEBHOOK_CRITICAL=<production_webhook>
SMTP_PASSWORD=<production_smtp_password>

# 3. Review all settings
grep -v "^#" .env.production | grep -v "^$"

# 4. Start services
docker-compose up -d

# 5. Verify all services healthy
make health

# 6. Run full validation
make test

# 7. Verify backups configured
scripts/backup.sh --dry-run
```

## Post-Deployment Configuration

### Configure Prometheus Scrape Targets

Edit `configs/prometheus-overrides/prometheus.yml` and add scrape jobs:

```yaml
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Netdata parent instance
  - job_name: 'netdata'
    static_configs:
      - targets: ['netdata:19999']

  # Netdata child agents (distributed monitoring)
  # - job_name: 'netdata-child-1'
  #   static_configs:
  #     - targets: ['netdata-child1.example.com:19999']

  # Add your application metrics
  # - job_name: 'my-app'
  #   static_configs:
  #     - targets: ['app.example.com:9100']
```

### Configure Grafana Datasources

Datasources are auto-provisioned from `configs/grafana-provisioning/datasources/datasources.yaml`.

To add custom datasources:

1. Edit the datasources file
2. Restart Grafana:
   ```bash
   docker-compose restart grafana
   ```

### Configure Alert Routing

Edit `configs/alertmanager-overrides/alertmanager.yml`:

```yaml
receivers:
  - name: 'slack-critical'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_CRITICAL}'
        channel: '#alerts'

  - name: 'email-ops'
    email_configs:
      - to: 'ops-team@example.com'
        from: '${SMTP_FROM}'
        smarthost: '${SMTP_HOST}:${SMTP_PORT}'
        auth_username: '${SMTP_USERNAME}'
        auth_password: '${SMTP_PASSWORD}'
```

## Operational Procedures

### Daily Checks

```bash
# Check service health
docker-compose ps

# Check system metrics
docker stats

# Review recent alerts
# (Access Alertmanager: http://localhost:9093)

# Check disk usage
df -h /var/lib/docker/volumes/
```

### Weekly Maintenance

```bash
# Update submodules (check for updates)
scripts/submodule-status.sh

# Review retention and disk usage
docker exec monitoring-prometheus du -sh /prometheus

# Backup configuration and dashboards
scripts/dashboard-backup.sh
```

### Monthly Tasks

```bash
# Check for upstream updates
git submodule update --remote

# Test disaster recovery
scripts/test-backup-restore.sh

# Review and optimize alert rules
# (Check Prometheus Rules: http://localhost:9090/rules)

# Analyze disk usage and plan capacity
du -sh /var/lib/docker/volumes/infra-monitor-*
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Check Docker daemon
sudo systemctl status docker

# Verify port availability
netstat -tulpn | grep -E ':(3000|9090|9093|19999|3301|3001)'

# Check disk space
df -h /
```

### Services Crash After Starting

```bash
# Check service logs
docker-compose logs <service_name>

# Common issues:
# - Port conflicts: Change ports in .env
# - Insufficient memory: Increase Docker resource limits
# - Volume permission issues: Fix with: docker-compose down -v && docker-compose up

# Restart service with debugging
docker-compose restart <service_name>
docker-compose logs -f <service_name>
```

### No Metrics Appearing

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq .

# Check Netdata endpoint
curl http://localhost:19999/api/v1/allmetrics | head -20

# Test scrape manually
docker exec monitoring-prometheus \
  curl -X GET 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up'
```

### Elevated Memory/CPU Usage

```bash
# Identify resource-heavy service
docker stats

# Check service logs for errors
docker-compose logs <heavy_service>

# Reduce retention (short-term fix)
# PROMETHEUS_RETENTION_SIZE=10GB

# Scale container resources
# Edit docker-compose.yml services.<service>.deploy.resources
```

## Upgrading Components

### Add a New Monitoring Target

1. Add Prometheus scrape job to prometheus.yml:
   ```yaml
   - job_name: 'my-new-target'
     static_configs:
       - targets: ['host.example.com:9100']
   ```

2. Reload Prometheus:
   ```bash
   docker-compose restart prometheus
   ```

3. Verify metrics appear in Prometheus UI

### Update Submodule Version

```bash
# Check current versions
cat SUBMODULE_VERSIONS.txt

# Update specific submodule
cd stack/dockprom
git fetch origin
git checkout v1.5.0  # or latest tag

# Return to root
cd ../..

# Commit the change
git add stack/dockprom
git commit -m "Update dockprom to v1.5.0"

# Test in staging
docker-compose down
docker-compose up -d

# Verify services start correctly
make health
```

### Scale Disk Storage

```bash
# Current size
docker volume inspect infra-monitor-prometheus-storage

# To migrate to larger volume:
# 1. Backup current data
docker exec monitoring-prometheus tar -cz -f /tmp/prometheus-backup.tar.gz /prometheus

# 2. Create new larger volume (docker doesn't resize in-place)
# 3. Restore data to new volume

# Easier: Modify retention settings in .env
PROMETHEUS_RETENTION_SIZE=100GB
docker-compose restart prometheus
```

## Backup and Recovery

### Automatic Backups

Configure periodic backups via cron (Linux):

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /path/to/infra-health-monitor/scripts/backup.sh
```

### Manual Backup

```bash
# Backup all volumes
scripts/backup.sh

# Output location
ls -lah backups/
```

### Recovery Procedure

```bash
# 1. Stop services
docker-compose down

# 2. Remove corrupted volumes (⚠️ DATA LOSS)
docker volume rm infra-monitor-prometheus-storage
docker volume rm infra-monitor-grafana-storage

# 3. Restore from backup
scripts/backup-restore.sh backups/latest/

# 4. Start services
docker-compose up -d

# 5. Verify data restored
make health
```

## Performance Tuning

### Prometheus Optimization

```bash
# Reduce cardinality of metrics
# In prometheus.yml, add metric_relabel_configs:

metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'container_.*'
    action: drop

# Increase scrape timeout for slow targets
scrape_timeout: 30s
```

### Grafana Dashboard Optimization

- Use appropriate time ranges in queries
- Implement dashboard folder organization
- Archive unused dashboards
- Use templating for variable panels

### ClickHouse (SigNoz) Optimization

```bash
# Monitor table sizes
docker exec monitoring-signoz-clickhouse \
  clickhouse-client -h 127.0.0.1 \
  -q "SELECT table, formatReadableSize(total_bytes) \
      FROM system.tables WHERE database='signoz' ORDER BY total_bytes DESC"

# Implement TTL for old data
ALTER TABLE signoz.logs TTL timestamp + INTERVAL 30 DAY;
```

## Monitoring the Monitoring System

It's crucial to monitor the monitoring platform itself:

```bash
# Set up alerts for monitoring system health
# In prometheus.yml alert rules:

- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 2m
  annotations:
    summary: "Prometheus is down!"

- alert: GrafanaDown
  expr: up{job="grafana"} == 0
  for: 2m
  annotations:
    summary: "Grafana is down!"
```

## Deployment Checklist

- [ ] Docker and Docker Compose installed and tested
- [ ] Repository cloned with submodules
- [ ] Environment file created and customized
- [ ] docker-compose.yml validates without errors
- [ ] All services start and reach healthy state
- [ ] Grafana accessible and datasources configured
- [ ] Prometheus scraping all configured targets
- [ ] Alertmanager routing configured for team
- [ ] Netdata agents deployed to monitored systems
- [ ] Backup scripts configured and tested
- [ ] Team trained on accessing and using platform
- [ ] SLA and runbooks documented
- [ ] Monitoring of monitoring system configured

---

Last Updated: March 2026
Deployment Guide Version: 1.0

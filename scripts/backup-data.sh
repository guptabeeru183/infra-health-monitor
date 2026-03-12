#!/bin/bash
# backup-data.sh
# ==============
# Simple wrapper to snapshot key data volumes used by the monitoring stack.
# Adjust paths/volumes according to your environment.

set -e

BACKUP_DIR="${1:-./backups}"
mkdir -p "$BACKUP_DIR"

echo "Backing up monitoring data to $BACKUP_DIR"

timestamp=$(date +%Y%m%d-%H%M%S)

# Prometheus TSDB
if [ -d "./prometheus-data" ]; then
    echo "  - Prometheus..."
    tar -czf "$BACKUP_DIR/prometheus-$timestamp.tar.gz" prometheus-data
fi

# Netdata DB
if [ -d "./netdata-data" ]; then
    echo "  - Netdata..."
    tar -czf "$BACKUP_DIR/netdata-$timestamp.tar.gz" netdata-data
fi

# ClickHouse (logs/traces)
if [ -d "./clickhouse-data" ]; then
    echo "  - ClickHouse..."
    tar -czf "$BACKUP_DIR/clickhouse-$timestamp.tar.gz" clickhouse-data
fi

# Grafana dashboards (as JSON export)
if [ -d "./dashboards" ]; then
    echo "  - Grafana dashboards..."
    tar -czf "$BACKUP_DIR/dashboards-$timestamp.tar.gz" dashboards
fi

# Uptime Kuma config
if [ -d "./stack/uptime-kuma/data" ]; then
    echo "  - Uptime Kuma data..."
    tar -czf "$BACKUP_DIR/uptime-kuma-$timestamp.tar.gz" stack/uptime-kuma/data
fi

echo "Backup complete."

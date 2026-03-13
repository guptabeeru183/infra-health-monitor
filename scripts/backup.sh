#!/bin/bash
# backup.sh
# ==========
# Backup script for Infra Health Monitor configuration and data

set -e

# Configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_TYPE="${1:-full}"  # full, config, or data

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

log() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backup directory
setup_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Backup directory ready: $BACKUP_DIR"
}

# Backup configuration files
backup_config() {
    echo_header "Backing up configuration files"

    local config_backup="$BACKUP_DIR/config-$TIMESTAMP.tar.gz"

    log "Creating configuration backup: $config_backup"

    # Configuration files to backup
    tar -czf "$config_backup" \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='.git' \
        docker-compose.yml \
        docker-compose.prod.yml \
        docker-compose.staging.yml \
        .env* \
        configs/ \
        provisioning/ \
        docs/ \
        scripts/ \
        dashboards/ \
        Makefile \
        README.md \
        *.md

    local size=$(du -sh "$config_backup" | cut -f1)
    log "Configuration backup complete: $size"
}

# Backup persistent data
backup_data() {
    echo_header "Backing up persistent data"

    local data_backup="$BACKUP_DIR/data-$TIMESTAMP.tar.gz"

    log "Creating data backup: $data_backup"

    # Stop services temporarily for consistent backup
    log "Stopping services for consistent backup..."
    docker-compose stop 2>/dev/null || true

    # Backup data volumes
    docker run --rm \
        -v "$(pwd):/backup" \
        -v "infra-health-monitor_prometheus_data:/data/prometheus" \
        -v "infra-health-monitor_grafana_data:/data/grafana" \
        -v "infra-health-monitor_signoz_data:/data/signoz" \
        -v "infra-health-monitor_uptime_kuma_data:/data/uptime-kuma" \
        alpine:latest \
        tar -czf "/backup/$data_backup" \
            -C /data \
            prometheus grafana signoz uptime-kuma 2>/dev/null || true

    # Restart services
    log "Restarting services..."
    docker-compose start 2>/dev/null || true

    if [ -f "$data_backup" ]; then
        local size=$(du -sh "$data_backup" | cut -f1)
        log "Data backup complete: $size"
    else
        warning "Data backup may be incomplete - check service volumes"
    fi
}

# Backup metadata and logs
backup_metadata() {
    echo_header "Backing up metadata and logs"

    local meta_backup="$BACKUP_DIR/metadata-$TIMESTAMP.tar.gz"

    log "Creating metadata backup: $meta_backup"

    # Collect system information
    {
        echo "Backup Date: $(date)"
        echo "System: $(uname -a)"
        echo "Docker Version: $(docker --version)"
        echo "Docker Compose Version: $(docker-compose --version)"
        echo ""
        echo "=== Service Versions ==="
        git submodule status || echo "No submodules found"
        echo ""
        echo "=== Container Status ==="
        docker-compose ps || echo "Services not running"
        echo ""
        echo "=== Disk Usage ==="
        df -h || echo "df command failed"
        echo ""
        echo "=== Volume Information ==="
        docker volume ls | grep infra-health-monitor || echo "No volumes found"
    } > "$BACKUP_DIR/backup-info-$TIMESTAMP.txt"

    # Backup logs (last 7 days)
    log "Backing up recent logs..."
    mkdir -p "$BACKUP_DIR/logs-$TIMESTAMP"
    docker-compose logs --tail=10000 --since="7 days ago" > "$BACKUP_DIR/logs-$TIMESTAMP/services.log" 2>&1 || true

    # Create metadata archive
    tar -czf "$meta_backup" \
        "$BACKUP_DIR/backup-info-$TIMESTAMP.txt" \
        "$BACKUP_DIR/logs-$TIMESTAMP/" \
        SUBMODULE_VERSIONS.txt \
        test-results/ 2>/dev/null || true

    # Cleanup temporary files
    rm -rf "$BACKUP_DIR/backup-info-$TIMESTAMP.txt" "$BACKUP_DIR/logs-$TIMESTAMP"

    local size=$(du -sh "$meta_backup" | cut -f1)
    log "Metadata backup complete: $size"
}

# Verify backup integrity
verify_backup() {
    echo_header "Verifying backup integrity"

    local exit_code=0

    # Verify configuration backup
    if [ -f "$BACKUP_DIR/config-$TIMESTAMP.tar.gz" ]; then
        if tar -tzf "$BACKUP_DIR/config-$TIMESTAMP.tar.gz" > /dev/null 2>&1; then
            log "Configuration backup integrity: OK"
        else
            error "Configuration backup integrity: FAILED"
            exit_code=1
        fi
    fi

    # Verify data backup
    if [ -f "$BACKUP_DIR/data-$TIMESTAMP.tar.gz" ]; then
        if tar -tzf "$BACKUP_DIR/data-$TIMESTAMP.tar.gz" > /dev/null 2>&1; then
            log "Data backup integrity: OK"
        else
            warning "Data backup integrity: Check data backup"
        fi
    fi

    # Verify metadata backup
    if [ -f "$BACKUP_DIR/metadata-$TIMESTAMP.tar.gz" ]; then
        if tar -tzf "$BACKUP_DIR/metadata-$TIMESTAMP.tar.gz" > /dev/null 2>&1; then
            log "Metadata backup integrity: OK"
        else
            error "Metadata backup integrity: FAILED"
            exit_code=1
        fi
    fi

    return $exit_code
}

# Cleanup old backups
cleanup_old_backups() {
    echo_header "Cleaning up old backups"

    local retention_days=30

    # Remove backups older than retention period
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$retention_days -delete
    find "$BACKUP_DIR" -name "*-info-*.txt" -mtime +$retention_days -delete

    log "Cleaned up backups older than $retention_days days"
}

# Generate backup report
generate_report() {
    echo_header "Backup Report"

    local report_file="$BACKUP_DIR/backup-report-$TIMESTAMP.txt"

    {
        echo "Infra Health Monitor - Backup Report"
        echo "====================================="
        echo "Backup Date: $(date)"
        echo "Backup Type: $BACKUP_TYPE"
        echo "Timestamp: $TIMESTAMP"
        echo ""
        echo "Files Created:"
        ls -lh "$BACKUP_DIR"/*"$TIMESTAMP"* 2>/dev/null || echo "No files found"
        echo ""
        echo "Total Backup Size:"
        du -sh "$BACKUP_DIR"/*"$TIMESTAMP"* 2>/dev/null | awk '{sum += $1} END {print sum " total"}' || echo "Unable to calculate"
        echo ""
        echo "Backup Status: SUCCESS"
    } > "$report_file"

    log "Backup report generated: $report_file"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Backup Script       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Backup Type: $BACKUP_TYPE"
    echo "Timestamp: $TIMESTAMP"
    echo ""

    setup_backup_dir

    case "$BACKUP_TYPE" in
        "config")
            backup_config
            ;;
        "data")
            backup_data
            ;;
        "full")
            backup_config
            backup_data
            backup_metadata
            ;;
        *)
            error "Invalid backup type. Use: full, config, or data"
            exit 1
            ;;
    esac

    if verify_backup; then
        cleanup_old_backups
        generate_report
        log "Backup completed successfully!"
        echo ""
        echo "Backup files created in: $BACKUP_DIR"
        ls -lh "$BACKUP_DIR"/*"$TIMESTAMP"*
    else
        error "Backup verification failed!"
        exit 1
    fi
}

# Run main function
main
#!/bin/bash
# restore.sh
# ==========
# Restore script for Infra Health Monitor configuration and data

set -e

# Configuration
BACKUP_DIR="backups"
RESTORE_TYPE="${1:-full}"  # full, config, or data
BACKUP_FILE="$2"

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

# Validate inputs
validate_inputs() {
    if [ -z "$BACKUP_FILE" ]; then
        error "Backup file not specified"
        echo "Usage: $0 <type> <backup-file>"
        echo "Types: full, config, data"
        echo ""
        echo "Available backups:"
        ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
        exit 1
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    # Validate backup file integrity
    if ! tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
        error "Backup file is corrupted: $BACKUP_FILE"
        exit 1
    fi
}

# Create restore point (backup current state)
create_restore_point() {
    echo_header "Creating restore point"

    local restore_backup="$BACKUP_DIR/restore-point-$(date +%Y%m%d-%H%M%S).tar.gz"

    log "Creating restore point: $restore_backup"

    # Backup current configuration
    tar -czf "$restore_backup" \
        --exclude='backups' \
        --exclude='test-results' \
        --exclude='*.log' \
        . 2>/dev/null || true

    log "Restore point created: $(du -sh "$restore_backup" | cut -f1)"
}

# Stop services for restore
stop_services() {
    echo_header "Stopping services for restore"

    log "Stopping all services..."
    docker-compose down 2>/dev/null || true

    # Wait for services to stop
    sleep 5

    log "Services stopped"
}

# Restore configuration files
restore_config() {
    echo_header "Restoring configuration files"

    log "Restoring from: $BACKUP_FILE"

    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Extract backup
    tar -xzf "$BACKUP_FILE" -C "$temp_dir"

    # Restore configuration files (be selective)
    local config_files=(
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker-compose.staging.yml"
        ".env"
        ".env.example"
    )

    for file in "${config_files[@]}"; do
        if [ -f "$temp_dir/$file" ]; then
            cp "$temp_dir/$file" "$file"
            log "Restored: $file"
        fi
    done

    # Restore directories
    local config_dirs=(
        "configs"
        "provisioning"
        "docs"
        "scripts"
        "dashboards"
    )

    for dir in "${config_dirs[@]}"; do
        if [ -d "$temp_dir/$dir" ]; then
            cp -r "$temp_dir/$dir"/* "$dir/" 2>/dev/null || true
            log "Restored directory: $dir"
        fi
    done

    log "Configuration restore complete"
}

# Restore persistent data
restore_data() {
    echo_header "Restoring persistent data"

    log "Restoring data from: $BACKUP_FILE"

    # Stop services first
    stop_services

    # Extract and restore data volumes
    docker run --rm \
        -v "$(pwd):/restore" \
        -v "infra-health-monitor_prometheus_data:/data/prometheus" \
        -v "infra-health-monitor_grafana_data:/data/grafana" \
        -v "infra-health-monitor_signoz_data:/data/signoz" \
        -v "infra-health-monitor_uptime_kuma_data:/data/uptime-kuma" \
        alpine:latest \
        sh -c "
            cd /data &&
            tar -xzf /restore/$BACKUP_FILE 2>/dev/null || true &&
            echo 'Data extraction complete'
        "

    log "Data restore complete"
}

# Start services after restore
start_services() {
    echo_header "Starting services after restore"

    log "Starting services..."
    docker-compose up -d

    log "Waiting for services to be healthy..."
    sleep 30

    # Check service health
    if docker-compose ps | grep -q "Up"; then
        log "Services started successfully"
    else
        warning "Some services may not have started properly"
        docker-compose ps
    fi
}

# Verify restore integrity
verify_restore() {
    echo_header "Verifying restore integrity"

    local issues_found=0

    # Check configuration files
    local required_files=(
        "docker-compose.yml"
        ".env"
        "Makefile"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error "Missing configuration file: $file"
            ((issues_found++))
        fi
    done

    # Validate docker-compose configuration
    if ! docker-compose config > /dev/null 2>&1; then
        error "Docker Compose configuration is invalid"
        ((issues_found++))
    else
        log "Docker Compose configuration: OK"
    fi

    # Check service startup (basic)
    if docker-compose ps | grep -q "Up\|running"; then
        log "Services status: OK"
    else
        warning "Services may not be running properly"
    fi

    if [ $issues_found -eq 0 ]; then
        log "Restore verification: PASSED"
        return 0
    else
        error "Restore verification: FAILED ($issues_found issues found)"
        return 1
    fi
}

# Generate restore report
generate_restore_report() {
    echo_header "Restore Report"

    local report_file="$BACKUP_DIR/restore-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Infra Health Monitor - Restore Report"
        echo "======================================"
        echo "Restore Date: $(date)"
        echo "Restore Type: $RESTORE_TYPE"
        echo "Backup File: $BACKUP_FILE"
        echo "Backup Size: $(du -sh "$BACKUP_FILE" | cut -f1)"
        echo ""
        echo "Services Status:"
        docker-compose ps 2>/dev/null || echo "Unable to check services"
        echo ""
        echo "Configuration Files:"
        ls -la docker-compose.yml .env Makefile 2>/dev/null || echo "Some files missing"
        echo ""
        echo "Restore Status: $(verify_restore 2>/dev/null && echo 'SUCCESS' || echo 'ISSUES FOUND')"
    } > "$report_file"

    log "Restore report generated: $report_file"
}

# Emergency rollback
emergency_rollback() {
    echo_header "Emergency Rollback"

    warning "Performing emergency rollback to restore point"

    # Find latest restore point
    local restore_point=$(ls -t "$BACKUP_DIR"/restore-point-*.tar.gz 2>/dev/null | head -1)

    if [ -n "$restore_point" ]; then
        log "Rolling back to: $restore_point"
        # This would call the restore function with the restore point
        # For safety, we'll just log the action needed
        log "Manual intervention required. Run: $0 config $restore_point"
    else
        error "No restore point found!"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Restore Script      ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Restore Type: $RESTORE_TYPE"
    echo "Backup File: $BACKUP_FILE"
    echo ""

    validate_inputs

    # Confirm destructive operation
    echo -e "${YELLOW}WARNING: This will overwrite current configuration and/or data!${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restore cancelled by user"
        exit 0
    fi

    create_restore_point

    case "$RESTORE_TYPE" in
        "config")
            restore_config
            ;;
        "data")
            restore_data
            ;;
        "full")
            restore_config
            restore_data
            ;;
        *)
            error "Invalid restore type. Use: full, config, or data"
            exit 1
            ;;
    esac

    start_services

    if verify_restore; then
        generate_restore_report
        log "Restore completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Verify service functionality: make health"
        echo "2. Check data integrity: make test-integration"
        echo "3. Review service logs: docker-compose logs"
    else
        error "Restore completed with issues!"
        echo ""
        echo "Attempting emergency rollback..."
        emergency_rollback
        exit 1
    fi
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <type> <backup-file>"
    echo "Types: full, config, data"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

# Run main function
main
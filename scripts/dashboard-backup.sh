#!/bin/bash
#
# Dashboard Backup Script for Grafana
# Exports all dashboards from Grafana instance to local JSON files
#
# Usage: ./dashboard-backup.sh [grafana_url] [api_token] [output_dir]
# Example: ./dashboard-backup.sh http://localhost:3000 glsa_xxxxx ./backups/2024-03-12
#
# Environment Variables:
#   GRAFANA_URL - Grafana base URL (default: http://localhost:3000)
#   GRAFANA_TOKEN - API token with Editor/Admin role
#   BACKUP_DIR - Output directory for backup files (default: ./backups)
#

set -e

# Configuration
GRAFANA_URL="${1:-${GRAFANA_URL:-http://localhost:3000}}"
GRAFANA_TOKEN="${2:-${GRAFANA_TOKEN}}"
BACKUP_DIR="${3:-${BACKUP_DIR:-./backups}}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/backup_${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validation
if [ -z "$GRAFANA_TOKEN" ]; then
    echo -e "${RED}ERROR: GRAFANA_TOKEN is required${NC}"
    echo "Usage: GRAFANA_TOKEN=your_token $0 [grafana_url] [output_dir]"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}ERROR: curl is required${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required for JSON processing${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo -e "${YELLOW}Starting Grafana Dashboard Backup${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo "Backup Path: $BACKUP_PATH"
echo ""

# Function to fetch dashboards
fetch_dashboards() {
    local page=1
    local per_page=1000
    local total_dashboards=0
    
    echo -e "${YELLOW}Fetching dashboard list from Grafana...${NC}"
    
    # Get all dashboards
    local response=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "$GRAFANA_URL/api/search?query=&type=dash-db&per_page=$per_page&page=$page")
    
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to fetch dashboards. Check GRAFANA_TOKEN and URL.${NC}"
        exit 1
    fi
    
    local dashboard_count=$(echo "$response" | jq 'length')
    total_dashboards=$dashboard_count
    
    echo -e "${GREEN}Found $dashboard_count dashboards${NC}"
    echo ""
    
    # Export each dashboard
    local exported=0
    while IFS= read -r dashboard; do
        local id=$(echo "$dashboard" | jq -r '.id')
        local title=$(echo "$dashboard" | jq -r '.title')
        local slug=$(echo "$dashboard" | jq -r '.slug')
        
        # Sanitize filename
        local filename=$(echo "$slug" | sed 's/[^a-zA-Z0-9_-]/-/g')
        local filepath="$BACKUP_PATH/${id}_${filename}.json"
        
        # Fetch full dashboard with variables and annotations
        local dashboard_json=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "$GRAFANA_URL/api/dashboards/uid/$slug")
        
        if echo "$dashboard_json" | jq empty 2>/dev/null; then
            echo "$dashboard_json" | jq '.dashboard' > "$filepath"
            echo -e "${GREEN}✓${NC} Exported: $title (ID: $id)"
            ((exported++))
        else
            echo -e "${RED}✗${NC} Failed to export: $title (ID: $id)"
        fi
    done < <(echo "$response" | jq -r '.[] | @json')
    
    return $exported
}

# Function to generate backup metadata
generate_metadata() {
    local metadata_file="$BACKUP_PATH/backup-metadata.json"
    
    cat > "$metadata_file" <<EOF
{
  "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "grafana_url": "$GRAFANA_URL",
  "dashboard_count": $(ls -1 "$BACKUP_PATH"/*.json 2>/dev/null | wc -l),
  "backup_format": "grafana",
  "grafana_version_api": "$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL/api/health" | jq -r '.version // "unknown"')",
  "backup_script_version": "1.0"
}
EOF
    
    echo "Metadata saved to: $metadata_file"
}

# Main execution
fetch_dashboards
exported=$?

if [ $exported -ge 0 ]; then
    echo ""
    echo -e "${YELLOW}Creating backup metadata...${NC}"
    generate_metadata
    
    # Create archive
    echo -e "${YELLOW}Creating backup archive...${NC}"
    tar -czf "${BACKUP_PATH}.tar.gz" "$BACKUP_PATH"
    
    echo ""
    echo -e "${GREEN}✓ Backup completed successfully!${NC}"
    echo "Backup saved to: $BACKUP_PATH"
    echo "Archive: ${BACKUP_PATH}.tar.gz"
    echo ""
    echo "Show backup contents:"
    echo "  ls -lh $BACKUP_PATH/"
    echo ""
    echo "Restore from backup:"
    echo "  ./dashboard-restore.sh $BACKUP_PATH"
else
    echo -e "${RED}✗ Backup failed: No dashboards exported${NC}"
    exit 1
fi

#!/bin/bash
#
# Dashboard Restore Script for Grafana
# Imports dashboard JSON files into Grafana instance
#
# Usage: ./dashboard-restore.sh <backup_dir> [grafana_url] [api_token]
# Example: ./dashboard-restore.sh ./backups/backup_20240312_120000 http://localhost:3000 glsa_xxxxx
#
# Environment Variables:
#   GRAFANA_URL - Grafana base URL (default: http://localhost:3000)
#   GRAFANA_TOKEN - API token with Editor/Admin role
#

set -e

# Configuration
BACKUP_DIR="$1"
GRAFANA_URL="${2:-${GRAFANA_URL:-http://localhost:3000}}"
GRAFANA_TOKEN="${3:-${GRAFANA_TOKEN}}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validation
if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}ERROR: Backup directory not found: $BACKUP_DIR${NC}"
    echo "Usage: $0 <backup_dir> [grafana_url] [api_token]"
    exit 1
fi

if [ -z "$GRAFANA_TOKEN" ]; then
    echo -e "${RED}ERROR: GRAFANA_TOKEN is required${NC}"
    echo "Usage: GRAFANA_TOKEN=your_token $0 <backup_dir>"
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

echo -e "${YELLOW}Starting Grafana Dashboard Restore${NC}"
echo "Backup Directory: $BACKUP_DIR"
echo "Grafana URL: $GRAFANA_URL"
echo ""

# Verify Grafana connectivity
if ! curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL/api/health" > /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Grafana at $GRAFANA_URL${NC}"
    echo "Check GRAFANA_TOKEN and URL."
    exit 1
fi

echo -e "${GREEN}✓${NC} Connected to Grafana"
echo ""

# Function to restore dashboards
restore_dashboards() {
    local dashboard_files=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f | sort)
    local total=$(echo "$dashboard_files" | wc -l)
    local imported=0
    local failed=0
    
    echo -e "${YELLOW}Importing $total dashboards...${NC}"
    echo ""
    
    while IFS= read -r dashboard_file; do
        if [ -z "$dashboard_file" ]; then
            continue
        fi
        
        local filename=$(basename "$dashboard_file")
        
        # Skip metadata file
        if [ "$filename" = "backup-metadata.json" ]; then
            continue
        fi
        
        # Prepare dashboard for import
        local dashboard_json=$(jq '.' "$dashboard_file" 2>/dev/null)
        local title=$(echo "$dashboard_json" | jq -r '.title // "Unknown"')
        
        # Wrap in import format if needed
        if ! echo "$dashboard_json" | jq -e '.panels' >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} Invalid dashboard format: $filename"
            ((failed++))
            continue
        fi
        
        # Import dashboard
        local response=$(curl -s -X POST \
            -H "Authorization: Bearer $GRAFANA_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"dashboard\": $dashboard_json, \"overwrite\": true}" \
            "$GRAFANA_URL/api/dashboards/db")
        
        # Check if import was successful
        if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
            local id=$(echo "$response" | jq -r '.id')
            local url=$(echo "$response" | jq -r '.url // ""')
            echo -e "${GREEN}✓${NC} Imported: $title (ID: $id)"
            ((imported++))
        else
            local error=$(echo "$response" | jq -r '.message // "Unknown error"')
            echo -e "${RED}✗${NC} Failed to import: $title"
            echo "   Error: $error"
            ((failed++))
        fi
    done < <(echo "$dashboard_files")
    
    return $failed
}

# Execute restore
restore_dashboards
failed=$?

echo ""
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All dashboards restored successfully!${NC}"
    echo ""
    echo "Access Grafana dashboards at:"
    echo "  $GRAFANA_URL/dashboards"
else
    echo -e "${YELLOW}Restore completed with $failed error(s)${NC}"
    echo "Check dashboard validity and Grafana logs for details"
fi

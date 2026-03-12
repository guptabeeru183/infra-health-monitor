#!/bin/bash
#
# Dashboard Export Script for Grafana
# Exports all currently visible dashboards from Grafana to provision files
# Used to capture dashboard changes made in Grafana UI back to code
#
# Usage: ./export-dashboards.sh [grafana_url] [api_token] [output_dir]
# Example: ./export-dashboards.sh http://localhost:3000 glsa_xxxxx ./provisioning/dashboards
#

set -e

# Configuration
GRAFANA_URL="${1:-${GRAFANA_URL:-http://localhost:3000}}"
GRAFANA_TOKEN="${2:-${GRAFANA_TOKEN}}"
OUTPUT_DIR="${3:-${OUTPUT_DIR:-./provisioning/dashboards}}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Grafana Dashboard Export${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Grafana URL: $GRAFANA_URL"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Verify Grafana connectivity
if ! curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL/api/health" > /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Grafana at $GRAFANA_URL${NC}"
    echo "Check GRAFANA_TOKEN and URL."
    exit 1
fi

echo -e "${GREEN}✓ Connected to Grafana${NC}"
echo ""

# Fetch all dashboards
echo -e "${YELLOW}Fetching dashboard list...${NC}"
dashboards=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
    "$GRAFANA_URL/api/search?query=&type=dash-db&per_page=1000")

if ! echo "$dashboards" | jq empty 2>/dev/null; then
    echo -e "${RED}ERROR: Failed to fetch dashboards${NC}"
    exit 1
fi

dashboard_count=$(echo "$dashboards" | jq 'length')
echo -e "${GREEN}Found $dashboard_count dashboards${NC}"
echo ""

# Export each dashboard
exported=0
failed=0

while IFS= read -r dashboard; do
    local id=$(echo "$dashboard" | jq -r '.id')
    local title=$(echo "$dashboard" | jq -r '.title')
    local slug=$(echo "$dashboard" | jq -r '.slug')
    
    # Determine output filename
    # Use existing filename if available to preserve naming convention
    local filename=""
    if [ -f "$OUTPUT_DIR"/*"$id"*.json ]; then
        filename=$(ls "$OUTPUT_DIR"/*"$id"*.json | head -1 | xargs basename)
    else
        # Create new filename based on pattern
        filename=$(printf "%02d-%s.json" "$id" "$(echo "$slug" | sed 's/[^a-z0-9-]//g')")
    fi
    
    local filepath="$OUTPUT_DIR/$filename"
    
    # Fetch full dashboard
    dashboard_json=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "$GRAFANA_URL/api/dashboards/uid/$slug")
    
    if ! echo "$dashboard_json" | jq -e '.dashboard' >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Failed to export: $title (ID: $id)"
        ((failed++))
        continue
    fi
    
    # Extract dashboard object (remove metadata)
    echo "$dashboard_json" | jq '.dashboard' > "$filepath"
    
    # Verify export
    if [ -f "$filepath" ] && jq empty "$filepath" 2>/dev/null; then
        local panels=$(jq '.panels | length' "$filepath")
        echo -e "${GREEN}✓${NC} Exported: $title (ID: $id, $panels panels)"
        ((exported++))
    else
        echo -e "${RED}✗${NC} Failed to verify: $title"
        rm -f "$filepath"
        ((failed++))
    fi
done < <(echo "$dashboards" | jq -r '.[] | @json')

# Generate index file
echo ""
echo -e "${YELLOW}Generating dashboard index...${NC}"

index_file="$OUTPUT_DIR/INDEX.md"
cat > "$index_file" <<EOF
# Grafana Dashboards Index

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Total Dashboards: $exported

## Exported Dashboards

EOF

while IFS= read -r dashboard; do
    local id=$(echo "$dashboard" | jq -r '.id')
    local title=$(echo "$dashboard" | jq -r '.title')
    local description=$(echo "$dashboard" | jq -r '.description // ""')
    local tags=$(echo "$dashboard" | jq -r '.tags // []' | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
    
    if [ -f "$OUTPUT_DIR"/*"$id"*.json ]; then
        local filename=$(ls "$OUTPUT_DIR"/*"$id"*.json | head -1 | xargs basename)
        echo "### [$title]($filename)" >> "$index_file"
        if [ -n "$description" ]; then
            echo "**Description:** $description" >> "$index_file"
        fi
        echo "" >> "$index_file"
    fi
done < <(echo "$dashboards" | jq -r '.[] | @json')

echo -e "${GREEN}✓${NC} Index generated: $index_file"

# Summary
echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Export Summary${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""
printf "Total Dashboards:    %d\n" "$dashboard_count"
printf "Successfully Exported: ${GREEN}%d${NC}\n" "$exported"

if [ $failed -gt 0 ]; then
    printf "Failed: ${RED}%d${NC}\n" "$failed"
fi

echo ""
echo "Exported dashboards are ready to commit to git:"
echo "  cd $(dirname "$OUTPUT_DIR")"
echo "  git add -A"
echo "  git commit -m 'Export dashboards from Grafana UI'"
echo ""

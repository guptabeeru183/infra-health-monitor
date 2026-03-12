#!/bin/bash
#
# Dashboard Validation Script for Grafana
# Validates JSON syntax and Grafana schema compliance for dashboard files
#
# Usage: ./dashboard-validate.sh [dashboard_dir]
# Example: ./dashboard-validate.sh ./provisioning/dashboards
#

set -e

# Configuration
DASHBOARD_DIR="${1:-.provisioning/dashboards}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation
if [ ! -d "$DASHBOARD_DIR" ]; then
    echo -e "${RED}ERROR: Dashboard directory not found: $DASHBOARD_DIR${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required for JSON validation${NC}"
    exit 1
fi

# Counters
total_files=0
valid_files=0
invalid_files=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Grafana Dashboard Validation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Checking dashboards in: $DASHBOARD_DIR"
echo ""

# Function to validate individual dashboard
validate_dashboard() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    
    ((total_files++))
    
    # Skip non-JSON files
    if [[ ! "$filename" =~ \.json$ ]]; then
        return 0
    fi
    
    # Check if file is valid JSON
    if ! jq empty "$filepath" 2>/dev/null; then
        echo -e "${RED}✗ INVALID JSON${NC}    $filename"
        ((invalid_files++))
        return 1
    fi
    
    # Get dashboard info
    local title=$(jq -r '.title // .dashboard.title // "Unknown"' "$filepath" 2>/dev/null || echo "Unknown")
    local dashboard_obj=$(jq '.dashboard // .' "$filepath" 2>/dev/null)
    
    # Validate required fields
    local required_fields=("title" "panels")
    local has_errors=0
    
    # Check for dashboard vs wrapped format
    if jq -e '.dashboard' "$filepath" >/dev/null 2>&1; then
        dashboard_obj=$(jq '.dashboard' "$filepath")
    fi
    
    # Validate title
    if ! echo "$dashboard_obj" | jq -e '.title' >/dev/null 2>&1; then
        echo -e "${YELLOW}! WARNING${NC}   $filename - Missing 'title' field"
        has_errors=1
    fi
    
    # Validate panels
    if ! echo "$dashboard_obj" | jq -e '.panels | length > 0' >/dev/null 2>&1; then
        echo -e "${YELLOW}! WARNING${NC}   $filename - No panels defined"
        has_errors=1
    fi
    
    # Validate panel types
    local panel_count=$(echo "$dashboard_obj" | jq '.panels | length' 2>/dev/null || echo 0)
    for ((i=0; i<panel_count; i++)); do
        local panel=$(echo "$dashboard_obj" | jq ".panels[$i]" 2>/dev/null)
        local panel_type=$(echo "$panel" | jq -r '.type // "unknown"' 2>/dev/null)
        
        # List of valid Grafana panel types
        local valid_types=("graph" "singlestat" "stat" "gauge" "bargauge" "timeseries" "piechart" "table" "heatmap" "nodeGraph" "text" "alertlist" "dashlist" "pluginlist" "state-timeline" "status-history" "canvas" "geomap" "logsvolhist" "traces" "flame-graph")
        
        if [[ ! " ${valid_types[@]} " =~ " ${panel_type} " ]]; then
            echo -e "${YELLOW}! WARNING${NC}   $filename - Panel #$(($i+1)) has unknown type: $panel_type"
            has_errors=1
        fi
    done
    
    # Validate templating variables if present
    if echo "$dashboard_obj" | jq -e '.templating.list | length > 0' >/dev/null 2>&1; then
        local var_count=$(echo "$dashboard_obj" | jq '.templating.list | length')
        for ((i=0; i<var_count; i++)); do
            local var=$(echo "$dashboard_obj" | jq ".templating.list[$i]" 2>/dev/null)
            local var_name=$(echo "$var" | jq -r '.name // "unknown"')
            local var_type=$(echo "$var" | jq -r '.type // "unknown"')
            
            if [ -z "$var_name" ] || [ "$var_name" = "unknown" ]; then
                echo -e "${YELLOW}! WARNING${NC}   $filename - Variable #$(($i+1)) missing name"
                has_errors=1
            fi
        done
    fi
    
    if [ $has_errors -eq 0 ]; then
        echo -e "${GREEN}✓ VALID${NC}         $filename ($panel_count panels)"
        ((valid_files++))
    else
        ((invalid_files++))
    fi
}

# Main validation loop
while IFS= read -r dashboard_file; do
    validate_dashboard "$dashboard_file"
done < <(find "$DASHBOARD_DIR" -maxdepth 1 -type f | sort)

# Summary report
echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""
printf "Total Files:      %d\n" "$total_files"
printf "Valid Files:      ${GREEN}%d${NC}\n" "$valid_files"

if [ $invalid_files -gt 0 ]; then
    printf "Invalid Files:    ${RED}%d${NC}\n" "$invalid_files"
else
    printf "Invalid Files:    ${GREEN}%d${NC}\n" "$invalid_files"
fi

success_rate=$((valid_files * 100 / total_files))
printf "Success Rate:     %d%%\n" "$success_rate"
echo ""

# Additional checks
echo -e "${BLUE}Additional Checks${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""

# Check for provisioning configuration
if [ -f "$(dirname "$DASHBOARD_DIR")/provider.yaml" ]; then
    echo -e "${GREEN}✓${NC} Provisioning configuration found (provider.yaml)"
else
    echo -e "${YELLOW}!${NC} No provisioning configuration (provider.yaml) found"
fi

# Check for datasources configuration
if [ -f "$(dirname "$DASHBOARD_DIR")/../datasources/datasources.yaml" ]; then
    echo -e "${GREEN}✓${NC} Datasources configuration found"
else
    echo -e "${YELLOW}!${NC} Datasources configuration not found"
fi

# Validate datasources.yaml if it exists
if [ -f "$(dirname "$DASHBOARD_DIR")/../datasources/datasources.yaml" ]; then
    if command -v yq &>/dev/null; then
        if yq eval '.' "$(dirname "$DASHBOARD_DIR")/../datasources/datasources.yaml" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Datasources YAML syntax valid"
        else
            echo -e "${RED}✗${NC} Datasources YAML syntax invalid"
        fi
    fi
fi

echo ""

# Exit with appropriate code
if [ $invalid_files -gt 0 ]; then
    echo -e "${RED}Validation FAILED${NC} - $invalid_files file(s) have errors"
    exit 1
else
    echo -e "${GREEN}Validation PASSED${NC} - All dashboards are valid"
    exit 0
fi

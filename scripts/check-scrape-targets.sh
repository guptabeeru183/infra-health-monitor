#!/bin/bash
#
# Check Prometheus Scrape Targets Health
# ======================================
# Monitor and display the health status of all Prometheus scrape targets
# Shows which targets are UP/DOWN and their scrape statistics
#
# Usage: ./scripts/check-scrape-targets.sh [--watch] [--json]
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m'

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}
WATCH_MODE=false
JSON_OUTPUT=false

# ============================================================================
# Helper Functions
# ============================================================================

echo_header() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          Prometheus Scrape Targets Health Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Fetch targets from Prometheus
fetch_targets() {
    curl -s "${PROMETHEUS_URL}/api/v1/targets" 2>/dev/null || echo "{}"
}

# Parse and display targets grouped by job
display_targets_grouped() {
    local targets_json=$1
    
    # Extract and display active targets
    echo -e "${BLUE}ACTIVE TARGETS:${NC}"
    echo ""
    
    # Get unique job names
    jobs=$(echo "$targets_json" | grep -oP '"job":"?\K[^"]+' | sort -u)
    
    for job in $jobs; do
        job_status=$(echo "$targets_json" | grep -A 50 "\"job\":\"$job\"" | head -1)
        
        # Count UP/DOWN for this job
        job_up=$(echo "$targets_json" | grep -B 5 "\"job\":\"$job\"" | grep '"health":"up"' | wc -l)
        job_down=$(echo "$targets_json" | grep -B 5 "\"job\":\"$job\"" | grep '"health":"down"' | wc -l)
        
        if [ "$job_down" -eq 0 ]; then
            status_color="${GREEN}"
            status_symbol="✓"
        else
            status_color="${RED}"
            status_symbol="✗"
        fi
        
        printf "%s[%s]%s %-20s %s (%d UP, %d DOWN)%s\n" \
            "$status_color" "$status_symbol" "$NC" \
            "$job" "" "$job_up" "$job_down" ""
        
        # Show individual targets for this job
        echo "$targets_json" | jq -r ".activeTargets[]? | select(.labels.job == \"$job\") | 
            \"  \(.labels.instance // .scrapeUrl) | \(.health) | \(.lastScrape[0:19]) | \(.scrapeDuration|tonumber|.*1000|floor)ms\"" 2>/dev/null | \
            while read line; do
                if [[ $line == *"up"* ]]; then
                    echo -e "  ${GREEN}```$line${NC}"
                else
                    echo -e "  ${YELLOW}```$line${NC}"
                fi
            done
        
        echo ""
    done
}

# Display targets in table format
display_targets_table() {
    local targets_json=$1
    
    echo -e "${BLUE}TARGET DETAILS:${NC}"
    echo ""
    printf "%-25s %-10s %-20s %-15s %-10s\n" \
        "INSTANCE" "HEALTH" "LAST SCRAPE" "DURATION" "LABELS"
    echo -e "${GRAY}$(printf '%.0s─' {1..80})${NC}"
    
    echo "$targets_json" | jq -r '.activeTargets[]? | 
        "\(.labels.instance // .scrapeUrl) | \(.health) | \(.lastScrape[0:19]) | \(.scrapeDuration|tonumber|.*1000|floor)ms | job=\(.labels.job)"' \
        2>/dev/null | while read line; do
        
        instance=$(echo "$line" | cut -d'|' -f1 | xargs)
        health=$(echo "$line" | cut -d'|' -f2 | xargs)
        last_scrape=$(echo "$line" | cut -d'|' -f3 | xargs)
        duration=$(echo "$line" | cut -d'|' -f4 | xargs)
        labels=$(echo "$line" | cut -d'|' -f5 | xargs)
        
        # Color code health status
        if [ "$health" = "up" ]; then
            health_color="${GREEN}${health}${NC}"
        else
            health_color="${RED}${health}${NC}"
        fi
        
        printf "%-25s %-10b %-20s %-15s %-10s\n" \
            "$instance" "$health_color" "$last_scrape" "$duration" "$labels"
    done
    
    echo ""
}

# Display dropped targets
display_dropped_targets() {
    local targets_json=$1
    
    dropped_count=$(echo "$targets_json" | jq '.droppedTargets[]? | .droppedLabels' 2>/dev/null | wc -l)
    
    if [ "$dropped_count" -gt 0 ]; then
        echo -e "${YELLOW}DROPPED TARGETS (${dropped_count}):${NC}"
        echo ""
        
        echo "$targets_json" | jq -r '.droppedTargets[]? | 
            "Job: \(.discoveredLabels.job // "unknown") | Labels: \(.droppedLabels | to_entries | map("\(.key)=\(.value)") | join(", "))"' \
            2>/dev/null | while read line; do
            echo -e "  ${YELLOW}⚠${NC} $line"
        done
        
        echo ""
    fi
}

# Summary statistics
display_summary() {
    local targets_json=$1
    
    total=$(echo "$targets_json" | jq '.activeTargets | length' 2>/dev/null)
    up=$(echo "$targets_json" | jq '[.activeTargets[] | select(.health=="up")] | length' 2>/dev/null)
    down=$(echo "$targets_json" | jq '[.activeTargets[] | select(.health=="down")] | length' 2>/dev/null)
    
    echo -e "${BLUE}SUMMARY:${NC}"
    echo "Total Targets: $total"
    echo -e "  ${GREEN}UP: $up${NC}"
    echo -e "  ${RED}DOWN: $down${NC}"
    
    # Calculate health percentage
    if [ "$total" -gt 0 ]; then
        health_percent=$((up * 100 / total))
        if [ "$health_percent" -ge 80 ]; then
            health_color="${GREEN}"
        elif [ "$health_percent" -ge 50 ]; then
            health_color="${YELLOW}"
        else
            health_color="${RED}"
        fi
        echo -e "Health: ${health_color}${health_percent}%${NC}"
    fi
    
    echo ""
}

# Display in JSON format
display_json() {
    local targets_json=$1
    echo "$targets_json" | jq . 2>/dev/null || echo "$targets_json"
}

# Watch mode - refresh every N seconds
watch_mode() {
    while true; do
        targets=$(fetch_targets)
        
        if [ "$JSON_OUTPUT" = true ]; then
            clear
            display_json "$targets"
        else
            echo_header
            display_summary "$targets"
            display_targets_grouped "$targets"
            display_targets_table "$targets"
            display_dropped_targets "$targets"
        fi
        
        echo "Refreshing in ${REFRESH_INTERVAL}s... (Press Ctrl+C to exit)"
        sleep "$REFRESH_INTERVAL"
    done
}

# Single run mode
single_run() {
    echo_header
    
    targets=$(fetch_targets)
    
    if [ "$JSON_OUTPUT" = true ]; then
        display_json "$targets"
    else
        display_summary "$targets"
        display_targets_grouped "$targets"
        display_targets_table "$targets"
        display_dropped_targets "$targets"
    fi
}

# ============================================================================
# Performance Analysis
# ============================================================================

analyze_performance() {
    local targets_json=$1
    
    echo -e "${BLUE}PERFORMANCE ANALYSIS:${NC}"
    echo ""
    
    # Average scrape duration
    avg_duration=$(echo "$targets_json" | jq '[.activeTargets[]? | .scrapeDuration | tonumber] | add/length * 1000' 2>/dev/null)
    max_duration=$(echo "$targets_json" | jq '[.activeTargets[]? | .scrapeDuration | tonumber] | max * 1000' 2>/dev/null)
    
    if [ -n "$avg_duration" ] && [ "$avg_duration" != "null" ]; then
        printf "Average Scrape Duration: %.2fms\n" "$avg_duration"
        printf "Maximum Scrape Duration: %.2fms\n" "$max_duration"
        
        # Alert if scrape time is too long
        if (( $(echo "$avg_duration > 10000" | bc -l) )); then
            echo -e "${RED}⚠ Warning: Scrape duration exceeds 10s (may impact Prometheus performance)${NC}"
        fi
    fi
    
    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --watch         Continuously monitor targets (refresh every 5s)
    --json          Output in JSON format
    --interval N    Set refresh interval for watch mode (default: 5)
    --help          Show this help message

EXAMPLES:
    # Single run
    $0
    
    # Watch mode (auto-refresh)
    $0 --watch
    
    # JSON output
    $0 --json
    
    # Watch with custom interval
    $0 --watch --interval 10

ENVIRONMENT VARIABLES:
    PROMETHEUS_URL   Prometheus API URL (default: http://localhost:9090)
    REFRESH_INTERVAL Refresh interval in seconds (default: 5)
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --interval)
            REFRESH_INTERVAL=$2
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
if [ "$WATCH_MODE" = true ]; then
    watch_mode
else
    single_run
fi

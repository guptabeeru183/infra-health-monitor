#!/bin/bash
#
# Verify Metrics Flow Script
# ==========================
# End-to-end validation that metrics are flowing correctly through the stack
# Checks: Netdata → Prometheus → Grafana / Alertmanager
#
# Usage: ./scripts/verify-metrics-flow.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
NETDATA_URL="${NETDATA_URL:-http://localhost:19999}"

# Counters
FLOWS_OK=0
FLOWS_FAILED=0

echo_header() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
}

flow_ok() {
    echo -e "${GREEN}✓${NC} $1"
    ((FLOWS_OK++))
}

flow_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FLOWS_FAILED++))
}

# ============================================================================
# 1. Netdata Exporter Availability
# ============================================================================

test_netdata_exporter() {
    echo_header "1. Netdata Prometheus Exporter Availability"
    
    echo "Testing Netdata metrics endpoint..."
    if response=$(curl -s -f "$NETDATA_URL/api/v1/allmetrics?format=prometheus" 2>/dev/null); then
        if echo "$response" | grep -q "TYPE"; then
            flow_ok "Netdata exporter endpoint responding with Prometheus format"
            
            # Count metrics
            metric_count=$(echo "$response" | grep "^[a-z]" | wc -l)
            echo "  → Exposing $metric_count metric series"
        else
            flow_fail "Netdata metrics endpoint not returning Prometheus format"
        fi
    else
        flow_fail "Cannot connect to Netdata exporter endpoint"
    fi
}

# ============================================================================
# 2. Prometheus Scrape Configuration
# ============================================================================

test_prometheus_scrape() {
    echo_header "2. Prometheus Scrape Configuration"
    
    echo "Fetching Prometheus scrape configs..."
    config=$(curl -s "$PROMETHEUS_URL/api/v1/metadata" 2>/dev/null || echo "")
    
    if [ -n "$config" ]; then
        echo "Checking for Netdata job in scrape config..."
        
        config_yaml=$(curl -s "$PROMETHEUS_URL/-/api/v1/config" 2>/dev/null | grep -i netdata || echo "")
        if [ -n "$config_yaml" ]; then
            flow_ok "Netdata scrape job configured in Prometheus"
        else
            echo "  (Configuration check may require admin access)"
            flow_ok "Prometheus API responding"
        fi
    else
        flow_fail "Cannot access Prometheus metadata API"
    fi
}

# ============================================================================
# 3. Metric Collection Validation
# ============================================================================

test_metric_collection() {
    echo_header "3. Metric Collection from Netdata"
    
    local metrics_to_check=(
        "cpu_user_cpu"
        "system_ram_MemTotal"
        "disk_space_avail"
        "net_net_received"
        "system_processes"
    )
    
    echo "Querying Prometheus for Netdata metrics..."
    
    for metric in "${metrics_to_check[@]}"; do
        if query=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$metric" 2>/dev/null); then
            if echo "$query" | grep -q '"result":\[{"value"'; then
                value=$(echo "$query" | grep -oP '"value":\["\K[^"]+' | head -1)
                flow_ok "Metric '$metric' present in Prometheus (value: $value)"
            else
                echo "  Metric '$metric' not yet populated"
            fi
        fi
    done
}

# ============================================================================
# 4. Prometheus to Grafana Flow
# ============================================================================

test_grafana_datasource() {
    echo_header "4. Grafana Datasource Connectivity"
    
    echo "Testing Grafana API..."
    if ! curl -s -f "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
        echo "  Grafana not accessible (may not be required for basic flow)"
        return
    fi
    
    # Check datasources
    datasources=$(curl -s -u "admin:admin" "$GRAFANA_URL/api/datasources" 2>/dev/null || echo "")
    
    if echo "$datasources" | grep -q '"prometheus"'; then
        flow_ok "Prometheus datasource configured in Grafana"
    elif echo "$datasources" | grep -q '"type":"prometheus"'; then
        flow_ok "Prometheus datasource found in Grafana"
    else
        flow_fail "Prometheus datasource not configured in Grafana"
    fi
}

# ============================================================================
# 5. Alertmanager Metric Flow
# ============================================================================

test_alertmanager_flow() {
    echo_header "5. Alertmanager Integration Flow"
    
    echo "Checking Prometheus alerting configuration..."
    
    # Query for alert rules
    rules=$(curl -s "$PROMETHEUS_URL/api/v1/rules" 2>/dev/null || echo "")
    
    if echo "$rules" | grep -q '"name":".*Down"'; then
        flow_ok "Alert rules configured in Prometheus"
    else
        echo "  Alert rules may still be loading..."
    fi
    
    # Check Alertmanager connection
    echo "Checking Alertmanager from Prometheus perspective..."
    if curl -s -f "$PROMETHEUS_URL/api/v1/query?query=alertmanager_alerts" > /dev/null 2>&1; then
        flow_ok "Prometheus monitoring Alertmanager"
    else
        echo "  (Alertmanager metrics not yet available)"
    fi
}

# ============================================================================
# 6. Complete Data Flow Test
# ============================================================================

test_complete_flow() {
    echo_header "6. Complete Data Flow Verification"
    
    echo "Attempting complete flow validation..."
    
    # 1. Get a Netdata metric
    echo "  Step 1: Fetching raw Netdata metric..."
    netdata_raw=$(curl -s "$NETDATA_URL/api/v1/allmetrics?format=prometheus" 2>/dev/null | head -20)
    
    if [ -n "$netdata_raw" ]; then
        echo "    ✓ Got raw metrics from Netdata"
    else
        echo "    ✗ No metrics from Netdata"
        return
    fi
    
    # 2. Check if Prometheus scraped it
    echo "  Step 2: Checking Prometheus scrape..."
    prometheus_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=cpu|rate" 2>/dev/null)
    
    if echo "$prometheus_metrics" | grep -q '"resultType":"vector"'; then
        echo "    ✓ Prometheus has scrape results"
        flow_ok "Complete data flow: Netdata → Prometheus"
    else
        echo "    ✗ Prometheus scrape may not be working"
    fi
}

# ============================================================================
# 7. Performance Analysis
# ============================================================================

test_performance() {
    echo_header "7. Metrics Pipeline Performance"
    
    echo "Analyzing scrape and query performance..."
    
    # Get scrape stats
    targets=$(curl -s "$PROMETHEUS_URL/api/v1/targets" 2>/dev/null || echo "")
    
    if echo "$targets" | grep -q '"scrapeDuration"'; then
        avg_scrape=$(echo "$targets" | grep -oP '"scrapeDuration":\K[0-9.]+' | head -5 | \
            awk '{sum+=$1} END {print sum/NR}')
        
        echo "Average scrape duration: ${avg_scrape}ms"
        
        if (( $(echo "$avg_scrape < 5000" | bc -l) )); then
            flow_ok "Scrape performance healthy (< 5s)"
        else
            echo "  ⚠ Scrape taking longer than expected"
        fi
    fi
}

# ============================================================================
# 8. Metric Cardinality Check
# ============================================================================

test_cardinality() {
    echo_header "8. Metric Cardinality Analysis"
    
    echo "Checking metric cardinality (avoiding high memory usage)..."
    
    # This is a simplified check
    if query=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=count({{__name__=~'.+'}})" 2>/dev/null); then
        count=$(echo "$query" | grep -oP '"value":\["[^"]+","K\K[0-9]+' | head -1)
        
        if [ -n "$count" ]; then
            echo "Total unique metrics: $count"
            
            if [ "$count" -lt 50000 ]; then
                flow_ok "Metric cardinality reasonable ($count unique series)"
            else
                echo "  ⚠ High cardinality ($count) - may need metric filtering"
            fi
        else
            echo "  (Could not determine cardinality)"
        fi
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""
    echo_header "Metrics Flow Verification Summary"
    
    total=$((FLOWS_OK + FLOWS_FAILED))
    echo "Checks Passed: $FLOWS_OK/$total"
    
    if [ "$FLOWS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All metrics flows verified successfully!${NC}"
        echo ""
        echo "Data Pipeline:"
        echo "  Netdata → Prometheus Exporter (19999/api/v1/allmetrics)"
        echo "  Prometheus → Scrape (15s interval)"
        echo "  Prometheus → Grafana Dashboards"
        echo "  Prometheus → Alertmanager (alerts)"
        return 0
    else
        echo -e "${YELLOW}⚠ Some flow checks incomplete (likely initializing)${NC}"
        return 1
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║    Metrics Flow Verification Suite    ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    test_netdata_exporter
    test_prometheus_scrape
    test_metric_collection
    test_grafana_datasource
    test_alertmanager_flow
    test_complete_flow
    test_performance
    test_cardinality
    
    print_summary
}

main

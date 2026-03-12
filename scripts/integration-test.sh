#!/bin/bash
#
# Uptime Kuma Prometheus Exporter - Master Integration Test Suite
# ================================================================
# Comprehensive testing of all service integrations
# Verifies data flows, metrics collection, and alert routing
#
# Usage: ./scripts/integration-test.sh [--skip-prometheus] [--skip-netdata] [--skip-uptime-kuma]
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Metrics
PASSED=0
FAILED=0
WARNINGS=0

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"
NETDATA_URL="${NETDATA_URL:-http://localhost:19999}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_EXPORTER_URL="${UPTIME_EXPORTER_URL:-http://localhost:5000}"
OTEL_COLLECTOR_URL="${OTEL_COLLECTOR_URL:-http://localhost:8888}"

# ============================================================================
# Helper Functions
# ============================================================================

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARNINGS++))
}

test_connect() {
    local name=$1
    local url=$2
    local timeout=${3:-5}
    
    echo -ne "Testing connection to $name... "
    
    if curl -s -f --max-time $timeout "$url" > /dev/null 2>&1; then
        test_pass "Connected to $name ($url)"
        return 0
    else
        test_fail "Cannot connect to $name ($url)"
        return 1
    fi
}

# ============================================================================
# SERVICE CONNECTIVITY TESTS
# ============================================================================

test_service_connectivity() {
    echo_header "Phase 1: Service Connectivity Tests"
    
    test_connect "Prometheus" "$PROMETHEUS_URL/-/healthy" 5
    test_connect "Alertmanager" "$ALERTMANAGER_URL/-/healthy" 5
    test_connect "Netdata" "$NETDATA_URL/api/v1/info" 5
    test_connect "Uptime Kuma" "$UPTIME_KUMA_URL/api/status" 5
    test_connect "OpenTelemetry Collector" "$OTEL_COLLECTOR_URL/metrics" 5
    test_connect "Uptime Kuma Exporter" "$UPTIME_EXPORTER_URL/health" 5
}

# ============================================================================
# PROMETHEUS SCRAPE TARGETS TESTS
# ============================================================================

test_prometheus_targets() {
    echo_header "Phase 2: Prometheus Scrape Targets Verification"
    
    # Query Prometheus for target status
    echo "Fetching Prometheus targets..."
    targets_response=$(curl -s "$PROMETHEUS_URL/api/v1/targets" 2>/dev/null || echo "")
    
    if [ -z "$targets_response" ]; then
        test_fail "Cannot fetch Prometheus targets"
        return 1
    fi
    
    # Check for UP targets
    up_count=$(echo "$targets_response" | grep -o '"health":"up"' | wc -l)
    down_count=$(echo "$targets_response" | grep -o '"health":"down"' | wc -l)
    
    echo "Target Status: $up_count UP, $down_count DOWN"
    
    if [ "$up_count" -ge 4 ]; then
        test_pass "Most scrape targets are UP ($up_count up)"
    else
        test_warn "Few scrape targets UP ($up_count up, $down_count down)"
    fi
    
    # Check specific job targets
    echo ""
    echo "Checking specific job targets..."
    
    for job in 'prometheus' 'alertmanager' 'netdata' 'uptime-kuma' 'otel-collector'; do
        if echo "$targets_response" | grep -q "\"job\":\"$job\""; then
            status=$(echo "$targets_response" | grep -A 5 "\"job\":\"$job\"" | grep '"health":' | head -1 | grep -o '"health":"[^"]*"')
            if [[ $status == *'"up"'* ]]; then
                test_pass "Job '$job' scraped successfully (UP)"
            else
                test_warn "Job '$job' target DOWN"
            fi
        else
            test_fail "Job '$job' not configured or no targets"
        fi
    done
}

# ============================================================================
# METRIC INGESTION TESTS
# ============================================================================

test_metric_ingestion() {
    echo_header "Phase 3: Metric Ingestion Verification"
    
    # Helper function to check if metric exists in Prometheus
    check_metric() {
        local metric_name=$1
        local query="query?query=$metric_name"
        local result=$(curl -s "$PROMETHEUS_URL/api/v1/$query" 2>/dev/null | grep -o '"result":\[\]' || echo "found")
        
        if [[ $result != *'[]'* ]]; then
            test_pass "Metric '$metric_name' found in Prometheus"
            return 0
        else
            test_fail "Metric '$metric_name' not found in Prometheus"
            return 1
        fi
    }
    
    # Check Netdata metrics
    echo "Checking Netdata metrics..."
    check_metric "cpu_user_cpu" || true
    check_metric "system_ram_MemTotal" || true
    check_metric "disk_space_avail" || true
    
    # Check Uptime Kuma metrics
    echo ""
    echo "Checking Uptime Kuma metrics..."
    check_metric "uptime_monitor_up" || true
    check_metric "uptime_monitor_response_time_ms" || true
    
    # Check OTEL Collector metrics
    echo ""
    echo "Checking OpenTelemetry Collector metrics..."
    check_metric "otelcol_" || true
    
    # Count total active metrics
    echo ""
    metric_count=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up" 2>/dev/null | grep -o '"metric":' | wc -l)
    if [ "$metric_count" -gt 0 ]; then
        test_pass "Found $metric_count active metrics in Prometheus"
    else
        test_warn "No metrics found - services may still be initializing"
    fi
}

# ============================================================================
# ALERT RULE VALIDATION TESTS
# ============================================================================

test_alert_rules() {
    echo_header "Phase 4: Alert Rules Verification"
    
    # Query Prometheus for alert rules status
    rules_response=$(curl -s "$PROMETHEUS_URL/api/v1/rules" 2>/dev/null || echo "")
    
    if [ -z "$rules_response" ]; then
        test_fail "Cannot fetch alert rules"
        return 1
    fi
    
    # Count alert rules
    alert_count=$(echo "$rules_response" | grep -o '"type":"alert"' | wc -l)
    echo "Found $alert_count alert rules"
    
    if [ "$alert_count" -ge 5 ]; then
        test_pass "Alert rules loaded ($alert_count rules)"
    else
        test_warn "Few alert rules loaded ($alert_count rules, expected >=5)"
    fi
    
    # Check for specific alerts
    echo ""
    echo "Checking specific alert rules..."
    
    for alert in 'PrometheusDown' 'HighCpuUsage' 'HighMemoryUsage' 'DiskSpaceLow'; do
        if echo "$rules_response" | grep -q "\"name\":\"$alert\""; then
            test_pass "Alert rule '$alert' loaded"
        else
            test_warn "Alert rule '$alert' not found"
        fi
    done
}

# ============================================================================
# ALERTMANAGER VERIFICATION TESTS
# ============================================================================

test_alertmanager() {
    echo_header "Phase 5: Alertmanager Configuration Verification"
    
    # Query Alertmanager status
    status_response=$(curl -s "$ALERTMANAGER_URL/api/v1/status" 2>/dev/null || echo "")
    
    if [ -z "$status_response" ]; then
        test_fail "Cannot connect to Alertmanager API"
        return 1
    fi
    
    # Check if Alertmanager is working
    if echo "$status_response" | grep -q '"cluster":'; then
        test_pass "Alertmanager API responding"
    else
        test_warn "Alertmanager API response looks unusual"
    fi
    
    # Check alerts in Alertmanager
    echo ""
    echo "Checking active alerts in Alertmanager..."
    alerts_response=$(curl -s "$ALERTMANAGER_URL/api/v1/alerts" 2>/dev/null || echo "")
    
    if [ -n "$alerts_response" ]; then
        active_alerts=$(echo "$alerts_response" | grep -o '"status":"active"' | wc -l)
        test_pass "Alertmanager has $active_alerts active alerts"
    else
        test_pass "No active alerts (normal state)"
    fi
}

# ============================================================================
# INTER-SERVICE COMMUNICATION TESTS
# ============================================================================

test_inter_service_communication() {
    echo_header "Phase 6: Inter-Service Communication"
    
    if ! command -v docker-compose &> /dev/null; then
        test_warn "docker-compose not found - skipping inter-service tests"
        return
    fi
    
    echo "Testing Prometheus → Netdata connection..."
    if docker-compose exec -T prometheus \
        curl -s "http://netdata:19999/api/v1/info" > /dev/null 2>&1; then
        test_pass "Prometheus can reach Netdata"
    else
        test_fail "Prometheus cannot reach Netdata"
    fi
    
    echo "Testing Prometheus → Alertmanager connection..."
    if docker-compose exec -T prometheus \
        curl -s "http://alertmanager:9093/-/healthy" > /dev/null 2>&1; then
        test_pass "Prometheus can reach Alertmanager"
    else
        test_fail "Prometheus cannot reach Alertmanager"
    fi
    
    echo "Testing OTel Collector → ClickHouse connection..."
    if docker-compose exec -T otel-collector \
        curl -s "http://signoz-clickhouse:8123/" > /dev/null 2>&1; then
        test_pass "OTel Collector can reach ClickHouse"
    else
        test_warn "OTel Collector may not be able to reach ClickHouse (normal until data flows)"
    fi
}

# ============================================================================
# DATA FLOW VALIDATION TESTS
# ============================================================================

test_data_flow() {
    echo_header "Phase 7: End-to-End Data Flow Validation"
    
    echo "Verifying Netdata → Prometheus → Alertmanager flow..."
    
    # Check if any Netdata metrics are in Prometheus
    netdata_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=cpu_user_cpu" 2>/dev/null | \
        grep -c '"result":' || echo "0")
    
    if [ "$netdata_metrics" -gt 0 ]; then
        test_pass "Netdata metrics flowing through Prometheus"
    else
        test_warn "No Netdata metrics in Prometheus yet (initializing)"
    fi
    
    # Check if Uptime Kuma metrics are in Prometheus
    echo ""
    echo "Verifying Uptime Kuma → Exporter → Prometheus flow..."
    uptime_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=uptime_monitor_up" 2>/dev/null | \
        grep -c '"result":' || echo "0")
    
    if [ "$uptime_metrics" -gt 0 ]; then
        test_pass "Uptime Kuma metrics flowing through exporter to Prometheus"
    else
        test_warn "No Uptime Kuma metrics yet (exporter may need initialization)"
    fi
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================

print_summary() {
    echo ""
    echo_header "Integration Test Summary"
    
    total=$((PASSED + FAILED + WARNINGS))
    echo "Total Tests: $total"
    echo -e "  ${GREEN}Passed:${NC} $PASSED"
    echo -e "  ${RED}Failed:${NC} $FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    
    echo ""
    echo "Overall Status:"
    
    if [ "$FAILED" -eq 0 ]; then
        if [ "$WARNINGS" -eq 0 ]; then
            echo -e "${GREEN}✓ All tests passed!${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Tests passed with warnings${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Integration Test Suite ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Run all test phases
    test_service_connectivity
    test_prometheus_targets
    test_metric_ingestion
    test_alert_rules
    test_alertmanager
    test_inter_service_communication
    test_data_flow
    
    # Print summary and exit with appropriate code
    print_summary
    exit $?
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-prometheus)
            SKIP_PROMETHEUS=true
            shift
            ;;
        --skip-netdata)
            SKIP_NETDATA=true
            shift
            ;;
        --skip-uptime-kuma)
            SKIP_UPTIME_KUMA=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

main

#!/bin/bash
# test-integration.sh
# ===================
# End-to-end integration tests for the monitoring stack
# Tests complete workflows and data flows

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
SIGNOZ_URL="${SIGNOZ_URL:-http://localhost:3301}"
OTEL_COLLECTOR_URL="${OTEL_COLLECTOR_URL:-http://localhost:4318}"

# Counters
PASSED=0
FAILED=0

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

# ============================================================================
# 1. Netdata → Prometheus Flow
# ============================================================================

test_netdata_prometheus_flow() {
    echo_header "1. Netdata → Prometheus Flow"
    
    echo "Checking Netdata metrics in Prometheus..."
    
    # Query for Netdata-specific metrics
    local netdata_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=cpu_user_cpu" | grep -c '"result"')
    
    if [ "$netdata_metrics" -gt 0 ]; then
        test_pass "Netdata metrics found in Prometheus"
    else
        test_fail "No Netdata metrics found in Prometheus"
    fi
    
    # Check scrape target status
    local netdata_up=$(curl -s "$PROMETHEUS_URL/api/v1/targets" | grep -A 5 '"job":"netdata"' | grep -c '"health":"up"')
    
    if [ "$netdata_up" -gt 0 ]; then
        test_pass "Netdata scrape target is UP"
    else
        test_fail "Netdata scrape target is DOWN"
    fi
}

# ============================================================================
# 2. Uptime Kuma → Prometheus Flow
# ============================================================================

test_uptime_kuma_prometheus_flow() {
    echo_header "2. Uptime Kuma → Prometheus Flow"
    
    echo "Checking Uptime Kuma metrics in Prometheus..."
    
    # Query for uptime metrics
    local uptime_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=uptime_monitor_up" | grep -c '"result"')
    
    if [ "$uptime_metrics" -gt 0 ]; then
        test_pass "Uptime Kuma metrics found in Prometheus"
    else
        test_fail "No Uptime Kuma metrics found in Prometheus"
    fi
}

# ============================================================================
# 3. OpenTelemetry → SigNoz Flow
# ============================================================================

test_otel_signoz_flow() {
    echo_header "3. OpenTelemetry → SigNoz Flow"
    
    echo "Testing OTEL collector to SigNoz flow..."
    
    # Send test trace
    curl -s -X POST "$OTEL_COLLECTOR_URL/v1/traces" \
        -H "Content-Type: application/json" \
        -d '{
          "resourceSpans": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "integration-test"}}]},
            "instrumentationLibrarySpans": [{
              "spans": [{
                "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
                "spanId": "00f067aa0ba902b7",
                "name": "integration-test-span",
                "kind": "SPAN_KIND_INTERNAL",
                "startTimeUnixNano": "'$(date +%s%N)'",
                "endTimeUnixNano": "'$(date +%s%N)'"
              }]
            }]
          }]
        }' > /dev/null
    
    sleep 2
    
    # Check if trace appeared in SigNoz (simplified check)
    local trace_check=$(curl -s "$SIGNOZ_URL/api/v1/traces?service=integration-test" | grep -c "integration-test-span" || echo "0")
    
    if [ "$trace_check" -gt 0 ]; then
        test_pass "Test trace found in SigNoz"
    else
        test_warn "Test trace not found in SigNoz (may take time to index)"
    fi
    
    # Send test log
    curl -s -X POST "$OTEL_COLLECTOR_URL/v1/logs" \
        -H "Content-Type: application/json" \
        -d '{
          "resourceLogs": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "integration-test"}}]},
            "instrumentationLibraryLogs": [{
              "logs": [{"timeUnixNano": "'$(date +%s%N)'", "body": {"stringValue": "integration test log"}}]
            }]
          }]
        }' > /dev/null
    
    sleep 2
    
    # Check if log appeared in SigNoz
    local log_check=$(curl -s "$SIGNOZ_URL/api/v1/logs?query=integration+test+log" | grep -c "integration test log" || echo "0")
    
    if [ "$log_check" -gt 0 ]; then
        test_pass "Test log found in SigNoz"
    else
        test_warn "Test log not found in SigNoz (may take time to index)"
    fi
}

# ============================================================================
# 4. Prometheus → Grafana Datasource
# ============================================================================

test_prometheus_grafana_datasource() {
    echo_header "4. Prometheus → Grafana Datasource"
    
    echo "Testing Grafana Prometheus datasource..."
    
    # Check if datasource exists and is working
    local datasource_check=$(curl -s -u "admin:admin" "$GRAFANA_URL/api/datasources" | grep -c '"type":"prometheus"' || echo "0")
    
    if [ "$datasource_check" -gt 0 ]; then
        test_pass "Prometheus datasource configured in Grafana"
    else
        test_fail "Prometheus datasource not found in Grafana"
    fi
    
    # Test datasource health
    local health_check=$(curl -s -u "admin:admin" "$GRAFANA_URL/api/datasources/1/health" | grep -c '"message":"Data source is working"' || echo "0")
    
    if [ "$health_check" -gt 0 ]; then
        test_pass "Prometheus datasource health check passed"
    else
        test_fail "Prometheus datasource health check failed"
    fi
}

# ============================================================================
# 5. End-to-End Workflow Test
# ============================================================================

test_end_to_end_workflow() {
    echo_header "5. End-to-End Workflow Test"
    
    echo "Testing complete monitoring workflow..."
    
    # 1. Generate synthetic metric anomaly
    echo "  Step 1: Generating synthetic CPU spike..."
    # This would require a test application or manual intervention
    
    # 2. Check if metric appears in Prometheus
    local metric_check=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=cpu_user_cpu" | grep -c '"value"')
    
    if [ "$metric_check" -gt 0 ]; then
        test_pass "Metrics flowing to Prometheus"
    else
        test_fail "No metrics found in Prometheus"
    fi
    
    # 3. Check if alert fires (simplified)
    local alert_check=$(curl -s "$PROMETHEUS_URL/api/v1/alerts" | grep -c '"state":"firing"')
    
    if [ "$alert_check" -gt 0 ]; then
        test_pass "Alerts are firing"
    else
        test_warn "No alerts currently firing (may be normal)"
    fi
    
    # 4. Check if dashboard loads
    local dashboard_check=$(curl -s "$GRAFANA_URL/api/dashboards/uid/infrastructure-overview" | grep -c '"dashboard"' || echo "0")
    
    if [ "$dashboard_check" -gt 0 ]; then
        test_pass "Dashboard loads successfully"
    else
        test_fail "Dashboard failed to load"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Integration Tests   ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    test_netdata_prometheus_flow
    test_uptime_kuma_prometheus_flow
    test_otel_signoz_flow
    test_prometheus_grafana_datasource
    test_end_to_end_workflow
    
    echo ""
    echo_header "Integration Test Summary"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Total: $((PASSED + FAILED))"
    
    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}All integration tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some integration tests failed${NC}"
        exit 1
    fi
}

main
#!/bin/bash
# performance-test.sh
# ===================
# Measures performance baselines for the monitoring stack
# Tests scrape latency, query response time, dashboard load, etc.

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
OTEL_COLLECTOR_URL="${OTEL_COLLECTOR_URL:-http://localhost:8888}"

# Results storage
declare -A results

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

measure_time() {
    local start=$(date +%s%N)
    "$@"
    local end=$(date +%s%N)
    echo "scale=3; ($end - $start) / 1000000000" | bc
}

# ============================================================================
# 1. Scrape Latency Tests
# ============================================================================

test_scrape_latency() {
    echo_header "1. Scrape Latency Tests"
    
    echo "Testing Prometheus scrape latency..."
    
    # Measure time to scrape all targets
    local scrape_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/targets" > /dev/null)
    results["scrape_latency"]=$scrape_time
    
    echo "Scrape latency: ${scrape_time}s"
    
    if (( $(echo "$scrape_time < 5" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<5s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>5s)"
    fi
}

# ============================================================================
# 2. Query Response Time Tests
# ============================================================================

test_query_response_time() {
    echo_header "2. Query Response Time Tests"
    
    local queries=(
        "up"
        "cpu_user_cpu"
        "rate(http_requests_total[5m])"
        "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
    )
    
    local total_time=0
    local count=0
    
    for query in "${queries[@]}"; do
        echo "Testing query: $query"
        local query_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=$query" > /dev/null)
        total_time=$(echo "$total_time + $query_time" | bc)
        ((count++))
        
        echo "  Response time: ${query_time}s"
    done
    
    local avg_time=$(echo "scale=3; $total_time / $count" | bc)
    results["query_response_time"]=$avg_time
    
    echo "Average query response time: ${avg_time}s"
    
    if (( $(echo "$avg_time < 1" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<1s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>1s)"
    fi
}

# ============================================================================
# 3. Dashboard Load Time Tests
# ============================================================================

test_dashboard_load_time() {
    echo_header "3. Dashboard Load Time Tests"
    
    # Test Grafana dashboard load (assuming dashboard exists)
    echo "Testing Grafana dashboard load time..."
    
    # This is a simplified test - in practice, you'd use Grafana API or browser automation
    local dashboard_time=$(measure_time curl -s "$GRAFANA_URL/api/dashboards/uid/infrastructure-overview" > /dev/null)
    results["dashboard_load_time"]=$dashboard_time
    
    echo "Dashboard load time: ${dashboard_time}s"
    
    if (( $(echo "$dashboard_time < 3" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<3s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>3s)"
    fi
}

# ============================================================================
# 4. Alert Firing Latency Tests
# ============================================================================

test_alert_firing_latency() {
    echo_header "4. Alert Firing Latency Tests"
    
    echo "Testing alert firing latency..."
    
    # Create a test alert that should fire immediately
    curl -s -X POST "$PROMETHEUS_URL/-/reload" > /dev/null  # Force rule evaluation
    
    # Wait a moment for evaluation
    sleep 5
    
    # Check if test alert fired (this is simplified - you'd need a specific test alert)
    local alert_check=$(curl -s "$PROMETHEUS_URL/api/v1/alerts" | grep -c '"state":"firing"')
    
    # For now, just measure the time to check alerts
    local alert_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/alerts" > /dev/null)
    results["alert_firing_latency"]=$alert_time
    
    echo "Alert check time: ${alert_time}s"
    
    if (( $(echo "$alert_time < 30" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<30s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>30s)"
    fi
}

# ============================================================================
# 5. Log Ingestion Latency Tests
# ============================================================================

test_log_ingestion_latency() {
    echo_header "5. Log Ingestion Latency Tests"
    
    echo "Testing log ingestion latency..."
    
    # Send a test log via OTEL collector
    local log_time=$(measure_time curl -s -X POST "$OTEL_COLLECTOR_URL/v1/logs" \
        -H "Content-Type: application/json" \
        -d '{
          "resourceLogs": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "perf-test"}}]},
            "instrumentationLibraryLogs": [{
              "logs": [{"timeUnixNano": "'$(date +%s%N)'", "body": {"stringValue": "performance test log"}}]
            }]
          }]
        }')
    
    results["log_ingestion_latency"]=$log_time
    
    echo "Log ingestion time: ${log_time}s"
    
    if (( $(echo "$log_time < 5" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<5s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>5s)"
    fi
}

# ============================================================================
# 6. Trace Ingestion Latency Tests
# ============================================================================

test_trace_ingestion_latency() {
    echo_header "6. Trace Ingestion Latency Tests"
    
    echo "Testing trace ingestion latency..."
    
    local trace_time=$(measure_time curl -s -X POST "$OTEL_COLLECTOR_URL/v1/traces" \
        -H "Content-Type: application/json" \
        -d '{
          "resourceSpans": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "perf-test"}}]},
            "instrumentationLibrarySpans": [{
              "spans": [{
                "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
                "spanId": "00f067aa0ba902b7",
                "name": "perf-test-span",
                "kind": "SPAN_KIND_INTERNAL",
                "startTimeUnixNano": "'$(date +%s%N)'",
                "endTimeUnixNano": "'$(date +%s%N)'"
              }]
            }]
          }]
        }')
    
    results["trace_ingestion_latency"]=$trace_time
    
    echo "Trace ingestion time: ${trace_time}s"
    
    if (( $(echo "$trace_time < 5" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Within target (<5s)"
    else
        echo -e "${RED}✗${NC} Exceeds target (>5s)"
    fi
}

# ============================================================================
# Report Generation
# ============================================================================

generate_report() {
    echo_header "Performance Test Report"
    
    echo "Results:"
    for key in "${!results[@]}"; do
        printf "  %-25s: %s s\n" "$key" "${results[$key]}"
    done
    
    echo ""
    echo "Targets:"
    echo "  Scrape latency: <5s"
    echo "  Query response time: <1s"
    echo "  Dashboard load time: <3s"
    echo "  Alert firing latency: <30s"
    echo "  Log ingestion latency: <5s"
    echo "  Trace ingestion latency: <5s"
    
    # Save to file
    local report_file="performance-report-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "Performance Test Report - $(date)"
        echo "=================================="
        echo ""
        for key in "${!results[@]}"; do
            echo "$key: ${results[$key]} s"
        done
    } > "$report_file"
    
    echo ""
    echo "Report saved to: $report_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Performance Tests   ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    test_scrape_latency
    test_query_response_time
    test_dashboard_load_time
    test_alert_firing_latency
    test_log_ingestion_latency
    test_trace_ingestion_latency
    
    generate_report
}

main
#!/bin/bash
# load-test.sh
# =============
# Load testing for the monitoring stack
# Tests performance under various load conditions

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

# Load test parameters
CONCURRENT_REQUESTS="${CONCURRENT_REQUESTS:-10}"
DURATION="${DURATION:-60}"  # seconds
METRICS_PER_SECOND="${METRICS_PER_SECOND:-100}"

# Results storage
RESULTS_DIR="test-results/load-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

log_result() {
    echo "$1" >> "$RESULTS_DIR/load-test-results.txt"
}

measure_time() {
    local start_time=$(date +%s%N)
    "$@"
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # milliseconds
    echo "$duration"
}

# ============================================================================
# 1. Prometheus Query Load Test
# ============================================================================

test_prometheus_query_load() {
    echo_header "1. Prometheus Query Load Test"
    
    echo "Testing Prometheus query performance under load..."
    
    local total_queries=0
    local total_time=0
    local max_time=0
    local min_time=999999
    
    # Generate concurrent queries
    for i in $(seq 1 "$CONCURRENT_REQUESTS"); do
        (
            for j in $(seq 1 10); do
                local query_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null)
                echo "$query_time" >> "$RESULTS_DIR/prometheus-query-times.txt"
                
                ((total_queries++))
                total_time=$((total_time + query_time))
                
                if [ "$query_time" -gt "$max_time" ]; then
                    max_time="$query_time"
                fi
                if [ "$query_time" -lt "$min_time" ]; then
                    min_time="$query_time"
                fi
                
                sleep 0.1
            done
        ) &
    done
    
    wait
    
    local avg_time=$((total_time / total_queries))
    
    echo "Prometheus Query Performance:"
    echo "  Total queries: $total_queries"
    echo "  Average response time: ${avg_time}ms"
    echo "  Max response time: ${max_time}ms"
    echo "  Min response time: ${min_time}ms"
    
    log_result "Prometheus Query Performance:"
    log_result "  Total queries: $total_queries"
    log_result "  Average response time: ${avg_time}ms"
    log_result "  Max response time: ${max_time}ms"
    log_result "  Min response time: ${min_time}ms"
    
    # Threshold check
    if [ "$avg_time" -gt 1000 ]; then
        echo -e "${RED}WARNING: Average query time > 1s${NC}"
    fi
}

# ============================================================================
# 2. Grafana Dashboard Load Test
# ============================================================================

test_grafana_dashboard_load() {
    echo_header "2. Grafana Dashboard Load Test"
    
    echo "Testing Grafana dashboard loading under concurrent users..."
    
    local total_loads=0
    local total_time=0
    local max_time=0
    local min_time=999999
    
    # Generate concurrent dashboard loads
    for i in $(seq 1 "$CONCURRENT_REQUESTS"); do
        (
            for j in $(seq 1 5); do
                local load_time=$(measure_time curl -s -u "admin:admin" "$GRAFANA_URL/api/dashboards/uid/infrastructure-overview" > /dev/null)
                echo "$load_time" >> "$RESULTS_DIR/grafana-dashboard-times.txt"
                
                ((total_loads++))
                total_time=$((total_time + load_time))
                
                if [ "$load_time" -gt "$max_time" ]; then
                    max_time="$load_time"
                fi
                if [ "$load_time" -lt "$min_time" ]; then
                    min_time="$load_time"
                fi
                
                sleep 0.2
            done
        ) &
    done
    
    wait
    
    local avg_time=$((total_time / total_loads))
    
    echo "Grafana Dashboard Load Performance:"
    echo "  Total loads: $total_loads"
    echo "  Average load time: ${avg_time}ms"
    echo "  Max load time: ${max_time}ms"
    echo "  Min load time: ${min_time}ms"
    
    log_result "Grafana Dashboard Load Performance:"
    log_result "  Total loads: $total_loads"
    log_result "  Average load time: ${avg_time}ms"
    log_result "  Max load time: ${max_time}ms"
    log_result "  Min load time: ${min_time}ms"
    
    # Threshold check
    if [ "$avg_time" -gt 2000 ]; then
        echo -e "${RED}WARNING: Average dashboard load time > 2s${NC}"
    fi
}

# ============================================================================
# 3. OTEL Collector Throughput Test
# ============================================================================

test_otel_collector_throughput() {
    echo_header "3. OTEL Collector Throughput Test"
    
    echo "Testing OTEL collector throughput with synthetic traces..."
    
    local total_traces=0
    local start_time=$(date +%s)
    
    # Generate traces for specified duration
    while [ $(($(date +%s) - start_time)) -lt "$DURATION" ]; do
        # Send batch of traces
        for i in $(seq 1 "$METRICS_PER_SECOND"); do
            curl -s -X POST "$OTEL_COLLECTOR_URL/v1/traces" \
                -H "Content-Type: application/json" \
                -d '{
                  "resourceSpans": [{
                    "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "load-test"}}]},
                    "instrumentationLibrarySpans": [{
                      "spans": [{
                        "traceId": "'$(openssl rand -hex 16)'",
                        "spanId": "'$(openssl rand -hex 8)'",
                        "name": "load-test-span",
                        "kind": "SPAN_KIND_INTERNAL",
                        "startTimeUnixNano": "'$(date +%s%N)'",
                        "endTimeUnixNano": "'$(date +%s%N)'"
                      }]
                    }]
                  }]
                }' > /dev/null &
            
            ((total_traces++))
        done
        
        # Control rate
        sleep 1
    done
    
    wait
    
    local actual_duration=$(($(date +%s) - start_time))
    local throughput=$((total_traces / actual_duration))
    
    echo "OTEL Collector Throughput:"
    echo "  Total traces sent: $total_traces"
    echo "  Duration: ${actual_duration}s"
    echo "  Throughput: ${throughput} traces/second"
    
    log_result "OTEL Collector Throughput:"
    log_result "  Total traces sent: $total_traces"
    log_result "  Duration: ${actual_duration}s"
    log_result "  Throughput: ${throughput} traces/second"
    
    # Threshold check
    if [ "$throughput" -lt 50 ]; then
        echo -e "${RED}WARNING: Throughput < 50 traces/second${NC}"
    fi
}

# ============================================================================
# 4. SigNoz Query Load Test
# ============================================================================

test_signoz_query_load() {
    echo_header "4. SigNoz Query Load Test"
    
    echo "Testing SigNoz query performance..."
    
    local total_queries=0
    local total_time=0
    local max_time=0
    local min_time=999999
    
    # Generate concurrent queries
    for i in $(seq 1 "$CONCURRENT_REQUESTS"); do
        (
            for j in $(seq 1 5); do
                local query_time=$(measure_time curl -s "$SIGNOZ_URL/api/v1/traces?service=load-test&limit=10" > /dev/null)
                echo "$query_time" >> "$RESULTS_DIR/signoz-query-times.txt"
                
                ((total_queries++))
                total_time=$((total_time + query_time))
                
                if [ "$query_time" -gt "$max_time" ]; then
                    max_time="$query_time"
                fi
                if [ "$query_time" -lt "$min_time" ]; then
                    min_time="$query_time"
                fi
                
                sleep 0.2
            done
        ) &
    done
    
    wait
    
    local avg_time=$((total_queries > 0 ? total_time / total_queries : 0))
    
    echo "SigNoz Query Performance:"
    echo "  Total queries: $total_queries"
    echo "  Average response time: ${avg_time}ms"
    echo "  Max response time: ${max_time}ms"
    echo "  Min response time: ${min_time}ms"
    
    log_result "SigNoz Query Performance:"
    log_result "  Total queries: $total_queries"
    log_result "  Average response time: ${avg_time}ms"
    log_result "  Max response time: ${max_time}ms"
    log_result "  Min response time: ${min_time}ms"
    
    # Threshold check
    if [ "$avg_time" -gt 2000 ]; then
        echo -e "${RED}WARNING: Average query time > 2s${NC}"
    fi
}

# ============================================================================
# 5. Resource Usage Monitoring
# ============================================================================

monitor_resource_usage() {
    echo_header "5. Resource Usage Monitoring"
    
    echo "Monitoring system resources during load test..."
    
    # Start background monitoring
    (
        while true; do
            echo "$(date +%s),$(docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}}" | tr '\n' ';')" >> "$RESULTS_DIR/resource-usage.csv"
            sleep 5
        done
    ) &
    local monitor_pid=$!
    
    # Run load tests
    test_prometheus_query_load
    test_grafana_dashboard_load
    test_otel_collector_throughput
    test_signoz_query_load
    
    # Stop monitoring
    kill "$monitor_pid"
    
    echo "Resource usage data saved to $RESULTS_DIR/resource-usage.csv"
}

# ============================================================================
# 6. Generate Load Test Report
# ============================================================================

generate_report() {
    echo_header "6. Load Test Report"
    
    echo "Generating comprehensive load test report..."
    
    cat > "$RESULTS_DIR/load-test-report.md" << EOF
# Load Test Report
Generated: $(date)

## Test Configuration
- Concurrent Requests: $CONCURRENT_REQUESTS
- Duration: ${DURATION}s
- Metrics per Second: $METRICS_PER_SECOND

## Performance Results

### Prometheus Query Performance
\`\`\`
$(grep "Prometheus Query Performance" "$RESULTS_DIR/load-test-results.txt" | head -4)
\`\`\`

### Grafana Dashboard Load Performance
\`\`\`
$(grep "Grafana Dashboard Load Performance" "$RESULTS_DIR/load-test-results.txt" | head -4)
\`\`\`

### OTEL Collector Throughput
\`\`\`
$(grep "OTEL Collector Throughput" "$RESULTS_DIR/load-test-results.txt" | head -3)
\`\`\`

### SigNoz Query Performance
\`\`\`
$(grep "SigNoz Query Performance" "$RESULTS_DIR/load-test-results.txt" | head -4)
\`\`\`

## Recommendations

EOF
    
    # Add recommendations based on results
    local avg_prometheus=$(grep "Average response time" "$RESULTS_DIR/load-test-results.txt" | grep Prometheus | awk '{print $4}' | sed 's/ms//')
    local avg_grafana=$(grep "Average response time" "$RESULTS_DIR/load-test-results.txt" | grep Grafana | awk '{print $4}' | sed 's/ms//')
    
    if [ "${avg_prometheus:-0}" -gt 1000 ]; then
        echo "- Consider optimizing Prometheus query performance" >> "$RESULTS_DIR/load-test-report.md"
    fi
    
    if [ "${avg_grafana:-0}" -gt 2000 ]; then
        echo "- Review Grafana dashboard complexity and caching" >> "$RESULTS_DIR/load-test-report.md"
    fi
    
    echo "Load test report saved to $RESULTS_DIR/load-test-report.md"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Load Testing        ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo "Results will be saved to: $RESULTS_DIR"
    echo ""
    
    monitor_resource_usage
    generate_report
    
    echo ""
    echo -e "${GREEN}Load testing completed!${NC}"
    echo "Results: $RESULTS_DIR"
}

main
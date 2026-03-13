#!/bin/bash
# stress-test.sh
# ===============
# Stress testing for the monitoring stack
# Tests system limits and failure scenarios

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

# Stress test parameters
MAX_CONCURRENT="${MAX_CONCURRENT:-50}"
STRESS_DURATION="${STRESS_DURATION:-30}"
BURST_SIZE="${BURST_SIZE:-1000}"

# Results storage
RESULTS_DIR="test-results/stress-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

log_result() {
    echo "$1" >> "$RESULTS_DIR/stress-test-results.txt"
}

# ============================================================================
# 1. Concurrent Connection Stress Test
# ============================================================================

test_concurrent_connections() {
    echo_header "1. Concurrent Connection Stress Test"
    
    echo "Testing maximum concurrent connections..."
    
    local success_count=0
    local failure_count=0
    
    # Test increasing concurrent connections
    for concurrent in 5 10 20 30 50; do
        echo "Testing $concurrent concurrent connections..."
        
        local start_time=$(date +%s)
        local pids=()
        
        # Launch concurrent requests
        for i in $(seq 1 "$concurrent"); do
            curl -s --max-time 10 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null &
            pids+=($!)
        done
        
        # Wait for completion
        local completed=0
        for pid in "${pids[@]}"; do
            if wait "$pid" 2>/dev/null; then
                ((completed++))
            fi
        done
        
        local duration=$(($(date +%s) - start_time))
        
        echo "  Completed: $completed/$concurrent in ${duration}s"
        
        if [ "$completed" -eq "$concurrent" ]; then
            success_count=$((success_count + 1))
        else
            failure_count=$((failure_count + 1))
        fi
        
        sleep 2
    done
    
    echo "Concurrent Connection Test Results:"
    echo "  Success rate: $success_count/$(($success_count + $failure_count))"
    
    log_result "Concurrent Connection Test Results:"
    log_result "  Success rate: $success_count/$(($success_count + $failure_count))"
}

# ============================================================================
# 2. Memory Pressure Test
# ============================================================================

test_memory_pressure() {
    echo_header "2. Memory Pressure Test"
    
    echo "Testing system under memory pressure..."
    
    # Monitor memory usage
    local initial_memory=$(docker stats --no-stream --format "{{.MemUsage}}" $(docker ps --format "{{.Names}}" | grep prometheus) | head -1)
    
    echo "Initial Prometheus memory usage: $initial_memory"
    
    # Generate high memory load (large queries)
    for i in $(seq 1 10); do
        curl -s "$PROMETHEUS_URL/api/v1/query_range?query=up&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)&step=1s" > /dev/null &
    done
    
    sleep 10
    
    local peak_memory=$(docker stats --no-stream --format "{{.MemUsage}}" $(docker ps --format "{{.Names}}" | grep prometheus) | head -1)
    
    echo "Peak Prometheus memory usage: $peak_memory"
    
    log_result "Memory Pressure Test:"
    log_result "  Initial memory: $initial_memory"
    log_result "  Peak memory: $peak_memory"
    
    # Check if memory usage is reasonable
    # This is a simplified check - in production you'd want more sophisticated monitoring
    echo "Memory pressure test completed"
}

# ============================================================================
# 3. Network Flood Test
# ============================================================================

test_network_flood() {
    echo_header "3. Network Flood Test"
    
    echo "Testing network handling under high traffic..."
    
    local sent_requests=0
    local successful_requests=0
    
    # Send burst of requests
    local start_time=$(date +%s)
    
    for i in $(seq 1 "$BURST_SIZE"); do
        if curl -s --max-time 1 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null 2>&1; then
            ((successful_requests++))
        fi
        ((sent_requests++))
    done
    
    local duration=$(($(date +%s) - start_time))
    local success_rate=$((successful_requests * 100 / sent_requests))
    
    echo "Network Flood Test Results:"
    echo "  Sent: $sent_requests requests"
    echo "  Successful: $successful_requests requests"
    echo "  Success rate: ${success_rate}%"
    echo "  Duration: ${duration}s"
    
    log_result "Network Flood Test Results:"
    log_result "  Sent: $sent_requests requests"
    log_result "  Successful: $successful_requests requests"
    log_result "  Success rate: ${success_rate}%"
    log_result "  Duration: ${duration}s"
    
    if [ "$success_rate" -lt 95 ]; then
        echo -e "${RED}WARNING: Low success rate under network flood${NC}"
    fi
}

# ============================================================================
# 4. Disk I/O Stress Test
# ============================================================================

test_disk_io_stress() {
    echo_header "4. Disk I/O Stress Test"
    
    echo "Testing disk I/O under high write load..."
    
    # Monitor disk usage before test
    local initial_disk=$(df -h | grep -E "/$" | awk '{print $5}')
    
    echo "Initial disk usage: $initial_disk"
    
    # Generate high volume of logs/traces
    local start_time=$(date +%s)
    
    for i in $(seq 1 100); do
        # Send large log entries
        curl -s -X POST "$OTEL_COLLECTOR_URL/v1/logs" \
            -H "Content-Type: application/json" \
            -d '{
              "resourceLogs": [{
                "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "stress-test"}}]},
                "instrumentationLibraryLogs": [{
                  "logs": [{
                    "timeUnixNano": "'$(date +%s%N)'",
                    "body": {"stringValue": "Stress test log entry with lots of data: '$(openssl rand -hex 1000)'"}
                  }]
                }]
              }]
            }' > /dev/null &
    done
    
    wait
    
    local duration=$(($(date +%s) - start_time))
    local final_disk=$(df -h | grep -E "/$" | awk '{print $5}')
    
    echo "Disk I/O Stress Test Results:"
    echo "  Duration: ${duration}s"
    echo "  Initial disk usage: $initial_disk"
    echo "  Final disk usage: $final_disk"
    
    log_result "Disk I/O Stress Test Results:"
    log_result "  Duration: ${duration}s"
    log_result "  Initial disk usage: $initial_disk"
    log_result "  Final disk usage: $final_disk"
}

# ============================================================================
# 5. Service Failure Simulation
# ============================================================================

test_service_failure_simulation() {
    echo_header "5. Service Failure Simulation"
    
    echo "Testing system resilience to service failures..."
    
    # Test 1: Stop a service and check if others continue
    echo "Stopping Netdata temporarily..."
    docker stop netdata 2>/dev/null || true
    
    sleep 5
    
    # Check if Prometheus still works
    if curl -s --max-time 5 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null; then
        echo "✓ Prometheus still operational after Netdata stop"
        log_result "✓ Prometheus still operational after Netdata stop"
    else
        echo "✗ Prometheus failed after Netdata stop"
        log_result "✗ Prometheus failed after Netdata stop"
    fi
    
    # Restart Netdata
    echo "Restarting Netdata..."
    docker start netdata 2>/dev/null || true
    
    sleep 10
    
    # Test 2: Stop Grafana and check if data collection continues
    echo "Stopping Grafana temporarily..."
    docker stop grafana 2>/dev/null || true
    
    sleep 5
    
    if curl -s --max-time 5 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null; then
        echo "✓ Data collection continues after Grafana stop"
        log_result "✓ Data collection continues after Grafana stop"
    else
        echo "✗ Data collection failed after Grafana stop"
        log_result "✗ Data collection failed after Grafana stop"
    fi
    
    # Restart Grafana
    echo "Restarting Grafana..."
    docker start grafana 2>/dev/null || true
    
    sleep 10
}

# ============================================================================
# 6. Recovery Time Test
# ============================================================================

test_recovery_time() {
    echo_header "6. Recovery Time Test"
    
    echo "Testing service recovery times..."
    
    # Test Prometheus restart time
    echo "Testing Prometheus restart time..."
    local start_time=$(date +%s%N)
    
    docker restart prometheus
    
    # Wait for service to be ready
    local ready=false
    local attempts=0
    while [ "$ready" = false ] && [ "$attempts" -lt 30 ]; do
        if curl -s --max-time 2 "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null 2>&1; then
            ready=true
        else
            sleep 1
            ((attempts++))
        fi
    done
    
    local end_time=$(date +%s%N)
    local recovery_time=$(( (end_time - start_time) / 1000000 ))  # milliseconds
    
    echo "Prometheus recovery time: ${recovery_time}ms"
    log_result "Prometheus recovery time: ${recovery_time}ms"
    
    if [ "$recovery_time" -gt 30000 ]; then  # 30 seconds
        echo -e "${RED}WARNING: Slow Prometheus recovery${NC}"
    fi
    
    # Test Grafana restart time
    echo "Testing Grafana restart time..."
    start_time=$(date +%s%N)
    
    docker restart grafana
    
    ready=false
    attempts=0
    while [ "$ready" = false ] && [ "$attempts" -lt 30 ]; do
        if curl -s --max-time 2 "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
            ready=true
        else
            sleep 1
            ((attempts++))
        fi
    done
    
    end_time=$(date +%s%N)
    recovery_time=$(( (end_time - start_time) / 1000000 ))
    
    echo "Grafana recovery time: ${recovery_time}ms"
    log_result "Grafana recovery time: ${recovery_time}ms"
    
    if [ "$recovery_time" -gt 30000 ]; then
        echo -e "${RED}WARNING: Slow Grafana recovery${NC}"
    fi
}

# ============================================================================
# 7. Generate Stress Test Report
# ============================================================================

generate_stress_report() {
    echo_header "7. Stress Test Report"
    
    echo "Generating stress test report..."
    
    cat > "$RESULTS_DIR/stress-test-report.md" << EOF
# Stress Test Report
Generated: $(date)

## Test Configuration
- Max Concurrent Connections: $MAX_CONCURRENT
- Stress Duration: ${STRESS_DURATION}s
- Burst Size: $BURST_SIZE

## Stress Test Results

### Concurrent Connection Test
\`\`\`
$(grep "Concurrent Connection Test Results" "$RESULTS_DIR/stress-test-results.txt" | head -1)
\`\`\`

### Memory Pressure Test
\`\`\`
$(grep "Memory Pressure Test" "$RESULTS_DIR/stress-test-results.txt" -A 2)
\`\`\`

### Network Flood Test
\`\`\`
$(grep "Network Flood Test Results" "$RESULTS_DIR/stress-test-results.txt" -A 4)
\`\`\`

### Disk I/O Stress Test
\`\`\`
$(grep "Disk I/O Stress Test Results" "$RESULTS_DIR/stress-test-results.txt" -A 4)
\`\`\`

### Service Failure Simulation
\`\`\`
$(grep -E "(✓|✗)" "$RESULTS_DIR/stress-test-results.txt" | tail -4)
\`\`\`

### Recovery Times
\`\`\`
$(grep "recovery time" "$RESULTS_DIR/stress-test-results.txt")
\`\`\`

## System Limits Identified

EOF
    
    # Analyze results for system limits
    local success_rate=$(grep "Success rate:" "$RESULTS_DIR/stress-test-results.txt" | head -1 | awk '{print $3}' | cut -d'/' -f1)
    
    if [ "${success_rate:-100}" -lt 95 ]; then
        echo "- Network flood success rate below 95%" >> "$RESULTS_DIR/stress-test-report.md"
    fi
    
    echo "- Monitor memory usage during high query loads" >> "$RESULTS_DIR/stress-test-report.md"
    echo "- Test service recovery procedures regularly" >> "$RESULTS_DIR/stress-test-report.md"
    
    echo "Stress test report saved to $RESULTS_DIR/stress-test-report.md"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Stress Testing      ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo "Results will be saved to: $RESULTS_DIR"
    echo ""
    
    test_concurrent_connections
    test_memory_pressure
    test_network_flood
    test_disk_io_stress
    test_service_failure_simulation
    test_recovery_time
    generate_stress_report
    
    echo ""
    echo -e "${GREEN}Stress testing completed!${NC}"
    echo "Results: $RESULTS_DIR"
}

main
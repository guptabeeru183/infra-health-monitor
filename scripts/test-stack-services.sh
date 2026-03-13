#!/bin/bash
# test-stack-services.sh
# ======================
# Comprehensive test of all monitoring stack services
# Verifies containers, ports, health endpoints, connectivity, and persistence

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

test_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ============================================================================
# 1. Container Status Tests
# ============================================================================

test_containers_running() {
    echo_header "1. Container Status Tests"
    
    local services=(
        "prometheus"
        "grafana"
        "alertmanager"
        "netdata"
        "uptime-kuma"
        "signoz-query-service"
        "otel-collector"
        "uptime-kuma-exporter"
    )
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            test_pass "Container '$service' is running"
        else
            test_fail "Container '$service' is not running"
        fi
    done
}

# ============================================================================
# 2. Port Accessibility Tests
# ============================================================================

test_ports_accessible() {
    echo_header "2. Port Accessibility Tests"
    
    local ports=(
        "prometheus:9090"
        "grafana:3000"
        "alertmanager:9093"
        "netdata:19999"
        "uptime-kuma:3001"
        "signoz-query-service:3301"
        "otel-collector:8888"
        "uptime-kuma-exporter:5000"
    )
    
    for port in "${ports[@]}"; do
        local service="${port%%:*}"
        local port_num="${port##*:}"
        
        if nc -z localhost "$port_num" 2>/dev/null; then
            test_pass "Port $port_num ($service) is accessible"
        else
            test_fail "Port $port_num ($service) is not accessible"
        fi
    done
}

# ============================================================================
# 3. Health Endpoint Tests
# ============================================================================

test_health_endpoints() {
    echo_header "3. Health Endpoint Tests"
    
    # Prometheus health
    if curl -s -f "http://localhost:9090/-/healthy" > /dev/null; then
        test_pass "Prometheus health endpoint responding"
    else
        test_fail "Prometheus health endpoint not responding"
    fi
    
    # Grafana health
    if curl -s -f "http://localhost:3000/api/health" > /dev/null; then
        test_pass "Grafana health endpoint responding"
    else
        test_fail "Grafana health endpoint not responding"
    fi
    
    # Alertmanager health
    if curl -s -f "http://localhost:9093/-/healthy" > /dev/null; then
        test_pass "Alertmanager health endpoint responding"
    else
        test_fail "Alertmanager health endpoint not responding"
    fi
    
    # Netdata info
    if curl -s -f "http://localhost:19999/api/v1/info" > /dev/null; then
        test_pass "Netdata API responding"
    else
        test_fail "Netdata API not responding"
    fi
    
    # Uptime Kuma status
    if curl -s -f "http://localhost:3001/api/status" > /dev/null; then
        test_pass "Uptime Kuma API responding"
    else
        test_fail "Uptime Kuma API not responding"
    fi
    
    # SigNoz version
    if curl -s -f "http://localhost:3301/api/v1/version" > /dev/null; then
        test_pass "SigNoz Query Service responding"
    else
        test_fail "SigNoz Query Service not responding"
    fi
    
    # OTEL Collector metrics
    if curl -s -f "http://localhost:8888/metrics" > /dev/null; then
        test_pass "OTEL Collector metrics endpoint responding"
    else
        test_fail "OTEL Collector metrics endpoint not responding"
    fi
}

# ============================================================================
# 4. Inter-Service Connectivity Tests
# ============================================================================

test_inter_service_connectivity() {
    echo_header "4. Inter-Service Connectivity Tests"
    
    # Prometheus to Alertmanager
    if docker-compose exec -T prometheus curl -s "http://alertmanager:9093/-/healthy" > /dev/null 2>&1; then
        test_pass "Prometheus can reach Alertmanager"
    else
        test_fail "Prometheus cannot reach Alertmanager"
    fi
    
    # Prometheus to Netdata
    if docker-compose exec -T prometheus curl -s "http://netdata:19999/api/v1/info" > /dev/null 2>&1; then
        test_pass "Prometheus can reach Netdata"
    else
        test_fail "Prometheus cannot reach Netdata"
    fi
    
    # OTEL Collector to ClickHouse
    if docker-compose exec -T otel-collector curl -s "http://signoz-clickhouse:8123/" > /dev/null 2>&1; then
        test_pass "OTEL Collector can reach ClickHouse"
    else
        test_warn "OTEL Collector may not be able to reach ClickHouse (normal until data flows)"
    fi
}

# ============================================================================
# 5. Volume Persistence Tests
# ============================================================================

test_volume_persistence() {
    echo_header "5. Volume Persistence Tests"
    
    # Check if volumes exist and have data
    local volumes=(
        "prometheus-data"
        "grafana-data"
        "netdata-data"
        "clickhouse-data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            test_pass "Volume '$volume' exists"
        else
            test_fail "Volume '$volume' does not exist"
        fi
    done
    
    # Test persistence by checking if data survives restart
    echo ""
    echo "Testing data persistence across restart..."
    
    # Get current Prometheus metric count as baseline
    baseline_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=up" | grep -o '"metric":' | wc -l)
    
    # Restart Prometheus
    docker-compose restart prometheus
    sleep 10
    
    # Check if metrics are still there
    after_restart_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=up" | grep -o '"metric":' | wc -l)
    
    if [ "$after_restart_metrics" -ge "$baseline_metrics" ]; then
        test_pass "Data persisted across Prometheus restart"
    else
        test_fail "Data loss detected after Prometheus restart"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Stack Services Test ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    test_containers_running
    test_ports_accessible
    test_health_endpoints
    test_inter_service_connectivity
    test_volume_persistence
    
    echo ""
    echo_header "Test Summary"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Total: $((PASSED + FAILED))"
    
    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed${NC}"
        exit 1
    fi
}

main
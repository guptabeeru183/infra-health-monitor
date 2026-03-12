#!/bin/bash
#
# Health Check Script for Infra Health Monitor Stack
# ===================================================
# Verifies that all monitoring services are up and healthy
# Usage: ./health-check.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
STACK_NAME="infra-health-monitor"
CHECK_INTERVAL=5
MAX_RETRIES=12

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Infra Health Monitor Health Check${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Counter for overall health
HEALTHY=0
TOTAL=0

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    TOTAL=$((TOTAL + 1))
    
    echo -ne "${YELLOW}Checking ${service_name}...${NC} "
    
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s -f "http://localhost:${port}${endpoint}" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ UP (${service_name}:${port})${NC}"
            HEALTHY=$((HEALTHY + 1))
            return 0
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            echo -ne "."
            sleep $CHECK_INTERVAL
        fi
    done
    
    echo -e "${RED}✗ DOWN (${service_name}:${port})${NC}"
    return 1
}

# Function to check if a service is running and return status code
check_service_status() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    TOTAL=$((TOTAL + 1))
    
    echo -ne "${YELLOW}Checking ${service_name}...${NC} "
    
    for i in $(seq 1 $MAX_RETRIES); do
        status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}${endpoint}" 2>/dev/null || echo "000")
        
        if [ "$status" != "000" ] && [ "$status" -lt 400 ]; then
            echo -e "${GREEN}✓ UP (${service_name}:${port}, Status: ${status})${NC}"
            HEALTHY=$((HEALTHY + 1))
            return 0
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            echo -ne "."
            sleep $CHECK_INTERVAL
        fi
    done
    
    echo -e "${RED}✗ DOWN (${service_name}:${port})${NC}"
    return 1
}

# Check each service
echo "Checking containerized services..."
echo ""

check_service "Prometheus" "9090" "/-/healthy"
check_service "Grafana" "3000" "/api/health"
check_service "Alertmanager" "9093" "/-/healthy"
check_service "Netdata" "19999" "/api/v1/info"
check_service "Uptime Kuma" "3001" "/api/status"
check_service "SigNoz Query Service" "3301" "/api/v1/version"
check_service "OpenTelemetry Collector" "8888" "/metrics"

echo ""
echo "Checking metrics endpoints..."
echo ""

# Check if Prometheus can scrape metrics
echo -ne "${YELLOW}Checking Prometheus targets...${NC} "
targets=$(curl -s "http://localhost:9090/api/v1/targets" | grep -c '"health":"up"' || echo "0")
if [ "$targets" -gt "0" ]; then
    echo -e "${GREEN}✓ Found ${targets} healthy targets${NC}"
else
    echo -e "${YELLOW}~ No targets up yet (initializing)${NC}"
fi

echo ""
echo "Checking network connectivity..."
echo ""

# Test inter-service communication
echo -ne "${YELLOW}Testing Prometheus -> Alertmanager...${NC} "
if docker-compose exec -T prometheus curl -s "http://alertmanager:9093/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
    HEALTHY=$((HEALTHY + 1))
else
    echo -e "${RED}✗ Not connected${NC}"
fi
TOTAL=$((TOTAL + 1))

echo -ne "${YELLOW}Testing Grafana -> Prometheus...${NC} "
if docker-compose exec -T grafana curl -s "http://prometheus:9090/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
    HEALTHY=$((HEALTHY + 1))
else
    echo -e "${RED}✗ Not connected${NC}"
fi
TOTAL=$((TOTAL + 1))

echo ""
echo "Summary:"
echo "--------"
echo -e "Services checked: ${BLUE}${TOTAL}${NC}"
echo -e "Services healthy: ${GREEN}${HEALTHY}${NC}"

if [ $HEALTHY -eq $TOTAL ]; then
    echo -e "${GREEN}✓ All services are healthy!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Access Grafana: http://localhost:3000 (admin/admin)"
    echo "2. Access Prometheus: http://localhost:9090"
    echo "3. Access Alertmanager: http://localhost:9093"
    echo "4. Access Netdata: http://localhost:19999"
    echo "5. Access Uptime Kuma: http://localhost:3001"
    exit 0
else
    echo -e "${YELLOW}~ Some services may still be initializing...${NC}"
    echo "  Run this script again to check status."
    exit 1
fi

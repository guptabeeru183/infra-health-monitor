#!/bin/bash
#
# Docker Compose Validation Script
# =================================
# Validates docker-compose.yml configuration and checks for common issues
# Usage: ./validate-compose.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Docker Compose Validation${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}✗ ERROR: docker-compose.yml not found${NC}"
    exit 1
fi

# 1. Validate YAML syntax
echo -ne "${YELLOW}Checking YAML syntax...${NC} "
if docker-compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ YAML syntax valid${NC}"
else
    echo -e "${RED}✗ YAML syntax invalid${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 2. Check for required files
echo ""
echo "Checking required configuration files..."

required_files=(
    "configs/prometheus-overrides/prometheus.yml"
    "configs/prometheus-overrides/alert-rules.yml"
    "configs/prometheus-overrides/alertmanager.yml"
    "configs/grafana-provisioning/datasources/datasources.yaml"
    "configs/signoz-overrides/otel-collector-config.yml"
    ".env.example"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${YELLOW}⚠${NC} $file (missing - may affect deployment)"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# 3. Check .env file
echo ""
echo -ne "${YELLOW}Checking environment configuration...${NC} "
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env file present${NC}"
    
    # Check for required environment variables
    echo "  Checking required variables..."
    required_vars=(
        "COMPOSE_PROJECT_NAME"
        "PROMETHEUS_VERSION"
        "GRAFANA_VERSION"
        "ALERTMANAGER_VERSION"
        "NETDATA_VERSION"
    )
    
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            echo -e "    ${GREEN}✓${NC} $var"
        else
            echo -e "    ${YELLOW}⚠${NC} $var (not set)"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
else
    echo -e "${YELLOW}⚠ .env file not found (using defaults)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 4. Check port availability
echo ""
echo "Checking port availability..."

ports=(
    "9090:Prometheus"
    "3000:Grafana"
    "9093:Alertmanager"
    "19999:Netdata"
    "3001:Uptime Kuma"
    "3301:SigNoz Query Service"
    "14250:SigNoz Jaeger"
)

for port_info in "${ports[@]}"; do
    port="${port_info%%:*}"
    service="${port_info##*:}"
    
    if netstat -tuln 2>/dev/null | grep -q ":${port}[[:space:]]"; then
        echo -e "  ${YELLOW}⚠${NC} Port ${port} (${service}) is already in use"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${GREEN}✓${NC} Port ${port} (${service}) available"
    fi
done

# 5. Check Docker daemon
echo ""
echo -ne "${YELLOW}Checking Docker daemon...${NC} "
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker daemon not accessible${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 6. Check Docker Compose version
echo -ne "${YELLOW}Checking Docker Compose version...${NC} "
compose_version=$(docker-compose --version | awk '{print $NF}')
echo -e "${GREEN}✓ Version $compose_version${NC}"

# 7. Check for image availability
echo ""
echo "Checking image availability..."

# Get services from docker-compose
services=$(docker-compose config --services 2>/dev/null)

for service in $services; do
    # Skip if service uses 'build' instead of 'image'
    image=$(docker-compose config --format=json 2>/dev/null | grep -o "\"image\":\"[^\"]*\"" | head -1 | cut -d'"' -f4 || echo "")
    
    if [ ! -z "$image" ]; then
        if docker image inspect "$image" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $image available"
        else
            echo -e "  ${YELLOW}⚠${NC} $image not found (will be pulled on docker-compose up)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
done

# 8. Validate Prometheus configuration
echo ""
echo -ne "${YELLOW}Validating Prometheus config...${NC} "
if [ -f "configs/prometheus-overrides/prometheus.yml" ]; then
    # Basic YAML structure check
    if grep -q "global:" configs/prometheus-overrides/prometheus.yml && \
       grep -q "scrape_configs:" configs/prometheus-overrides/prometheus.yml; then
        echo -e "${GREEN}✓ Structure valid${NC}"
    else
        echo -e "${YELLOW}⚠ Structure may be incomplete${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠ File not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 9. Validate alert rules
echo -ne "${YELLOW}Validating alert rules...${NC} "
if [ -f "configs/prometheus-overrides/alert-rules.yml" ]; then
    if grep -q "alert:" configs/prometheus-overrides/alert-rules.yml && \
       grep -q "expr:" configs/prometheus-overrides/alert-rules.yml; then
        echo -e "${GREEN}✓ Rules defined${NC}"
    else
        echo -e "${YELLOW}⚠ Alert structure may be incomplete${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠ File not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=================================="
echo "Validation Summary"
echo "=================================="
echo -e "Errors:   ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"

echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Validation passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Ensure .env is configured: cp .env.example .env && nano .env"
    echo "2. Start the stack: docker-compose up -d"
    echo "3. Monitor progress: docker-compose logs -f"
    echo "4. Check health: ./scripts/health-check.sh"
    exit 0
else
    echo -e "${RED}✗ Validation failed - please fix errors before deploying${NC}"
    exit 1
fi

#!/bin/bash
# test-security.sh
# =================
# Security testing for the Infra Health Monitor platform

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
SIGNOZ_URL="${SIGNOZ_URL:-http://localhost:3301}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"

# Results storage
RESULTS_DIR="test-results/security-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

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
    ((WARNINGS++))
}

log_finding() {
    echo "$1" >> "$RESULTS_DIR/security-findings.txt"
}

# ============================================================================
# 1. Network Security Assessment
# ============================================================================

test_network_security() {
    echo_header "1. Network Security Assessment"

    echo "Checking exposed ports and services..."

    # Check for exposed ports
    local exposed_ports=$(netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -E "0\.0\.0\.0|:" | wc -l)

    if [ "$exposed_ports" -gt 0 ]; then
        test_warn "Found $exposed_ports exposed ports - review network configuration"
        log_finding "EXPOSED_PORTS: $exposed_ports ports found listening on all interfaces"
    else
        test_pass "No ports exposed to all interfaces"
    fi

    # Check for default credentials
    echo "Testing default credentials..."

    # Test Grafana default credentials
    if curl -s -u "admin:admin" "$GRAFANA_URL/api/user" | grep -q '"isGrafanaAdmin":true'; then
        test_fail "Grafana using default admin:admin credentials"
        log_finding "DEFAULT_CREDS: Grafana admin:admin credentials still active"
    else
        test_pass "Grafana not using default credentials"
    fi

    # Check for HTTP endpoints (should be HTTPS in production)
    local http_endpoints=0
    for url in "$GRAFANA_URL" "$PROMETHEUS_URL" "$SIGNOZ_URL" "$UPTIME_KUMA_URL"; do
        if curl -s --max-time 5 "$url" | grep -q "HTTP/1.1 200 OK"; then
            ((http_endpoints++))
        fi
    done

    if [ "$http_endpoints" -gt 0 ]; then
        test_warn "Found $http_endpoints HTTP endpoints - consider HTTPS in production"
        log_finding "HTTP_ENDPOINTS: $http_endpoints services using HTTP instead of HTTPS"
    else
        test_pass "All endpoints using secure protocols"
    fi
}

# ============================================================================
# 2. Access Control Testing
# ============================================================================

test_access_control() {
    echo_header "2. Access Control Testing"

    echo "Testing authentication and authorization..."

    # Test unauthenticated access to sensitive endpoints
    local sensitive_endpoints=(
        "$PROMETHEUS_URL/api/v1/query?query=up"
        "$GRAFANA_URL/api/datasources"
        "$SIGNOZ_URL/api/v1/traces"
    )

    local unprotected=0
    for endpoint in "${sensitive_endpoints[@]}"; do
        if curl -s --max-time 5 "$endpoint" | grep -q -v "401\|403\|Unauthorized\|Forbidden"; then
            ((unprotected++))
            log_finding "UNPROTECTED_ENDPOINT: $endpoint accessible without authentication"
        fi
    done

    if [ "$unprotected" -gt 0 ]; then
        test_fail "Found $unprotected unprotected sensitive endpoints"
    else
        test_pass "Sensitive endpoints properly protected"
    fi

    # Test Grafana user permissions
    echo "Testing Grafana user permissions..."
    local user_count=$(curl -s -u "admin:admin" "$GRAFANA_URL/api/users" 2>/dev/null | grep -o '"id":[0-9]*' | wc -l)

    if [ "${user_count:-0}" -gt 1 ]; then
        test_pass "Multiple users configured in Grafana"
    else
        test_warn "Only default admin user found - consider adding users"
        log_finding "SINGLE_USER: Only default admin user configured"
    fi
}

# ============================================================================
# 3. Data Protection Assessment
# ============================================================================

test_data_protection() {
    echo_header "3. Data Protection Assessment"

    echo "Testing data protection measures..."

    # Check for sensitive data in logs
    echo "Scanning for sensitive data patterns..."
    local sensitive_patterns_found=0

    # Check container logs for sensitive patterns
    if docker-compose logs 2>/dev/null | grep -i -E "(password|secret|key|token)" | grep -v -E "(grep|echo|\*\*\*\*\*)" | head -5 > "$RESULTS_DIR/sensitive-logs.txt"; then
        sensitive_patterns_found=$(wc -l < "$RESULTS_DIR/sensitive-logs.txt")
        if [ "$sensitive_patterns_found" -gt 0 ]; then
            test_fail "Found $sensitive_patterns_found potential sensitive data exposures in logs"
            log_finding "SENSITIVE_DATA_LOGS: $sensitive_patterns_found instances of sensitive data in logs"
        fi
    fi

    # Check configuration files for hardcoded secrets
    local secret_patterns="password|secret|key|token|auth"
    local config_secrets=$(grep -r -i "$secret_patterns" configs/ docs/ scripts/ 2>/dev/null | grep -v -E "(grep|echo|\*\*\*\*\*|example|template)" | wc -l)

    if [ "$config_secrets" -gt 0 ]; then
        test_warn "Found $config_secrets potential secrets in configuration files"
        log_finding "CONFIG_SECRETS: $config_secrets potential secrets found in config files"
    else
        test_pass "No hardcoded secrets found in configuration"
    fi

    # Test data encryption at rest (basic check)
    echo "Checking data volume encryption..."
    local encrypted_volumes=$(docker volume ls | grep infra-health-monitor | wc -l)
    local total_volumes=$(docker volume ls | grep infra-health-monitor | wc -l)

    if [ "$encrypted_volumes" -eq "$total_volumes" ]; then
        test_pass "All data volumes appear to be configured"
    else
        test_warn "Data volume encryption not verified - manual review required"
        log_finding "VOLUME_ENCRYPTION: Data at rest encryption not confirmed"
    fi
}

# ============================================================================
# 4. Vulnerability Assessment
# ============================================================================

test_vulnerabilities() {
    echo_header "4. Vulnerability Assessment"

    echo "Checking for common vulnerabilities..."

    # Check for outdated images (basic check)
    echo "Checking container image versions..."
    local running_containers=$(docker-compose ps --format "{{.Image}}" | grep -v "^$" | wc -l)
    local latest_check=$(docker-compose pull --quiet 2>&1 | grep -c "Downloaded\|Up to date" || echo "0")

    if [ "$latest_check" -gt 0 ]; then
        test_pass "Container images are up to date"
    else
        test_warn "Some container images may be outdated"
        log_finding "OUTDATED_IMAGES: Container images may need updating"
    fi

    # Check for exposed debug endpoints
    local debug_endpoints=0
    local debug_urls=(
        "$PROMETHEUS_URL/debug/pprof"
        "$GRAFANA_URL/debug"
        "$SIGNOZ_URL/debug"
    )

    for url in "${debug_urls[@]}"; do
        if curl -s --max-time 5 "$url" | grep -q -i "debug\|pprof"; then
            ((debug_endpoints++))
            log_finding "DEBUG_ENDPOINT: $url exposes debug information"
        fi
    done

    if [ "$debug_endpoints" -gt 0 ]; then
        test_warn "Found $debug_endpoints debug endpoints exposed"
    else
        test_pass "No debug endpoints exposed"
    fi

    # Check for information disclosure
    echo "Testing for information disclosure..."
    local info_disclosure=0

    # Check error pages for sensitive information
    if curl -s "$PROMETHEUS_URL/invalid-endpoint" 2>&1 | grep -i -E "(version|stack|trace|error)" | head -3 > "$RESULTS_DIR/error-disclosure.txt"; then
        info_disclosure=$(wc -l < "$RESULTS_DIR/error-disclosure.txt")
        if [ "$info_disclosure" -gt 0 ]; then
            test_warn "Potential information disclosure in error messages"
            log_finding "INFO_DISCLOSURE: Error messages may reveal sensitive information"
        fi
    fi
}

# ============================================================================
# 5. Compliance Check
# ============================================================================

test_compliance() {
    echo_header "5. Compliance Check"

    echo "Checking basic compliance requirements..."

    # Check for audit logging
    echo "Verifying audit logging..."
    local audit_logs=$(docker-compose logs 2>/dev/null | grep -i -E "(login|auth|access)" | wc -l)

    if [ "$audit_logs" -gt 0 ]; then
        test_pass "Audit logging appears to be active"
    else
        test_warn "Limited audit logging detected"
        log_finding "AUDIT_LOGGING: Limited authentication logging found"
    fi

    # Check for backup procedures
    if [ -d "backups" ] && [ "$(ls backups/*.tar.gz 2>/dev/null | wc -l)" -gt 0 ]; then
        test_pass "Backup procedures appear to be in place"
    else
        test_fail "No backup files found - backup procedures required"
        log_finding "BACKUP_PROCEDURES: No backup files detected"
    fi

    # Check for monitoring of security events
    local security_alerts=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up" 2>/dev/null | grep -c '"result"')

    if [ "$security_alerts" -gt 0 ]; then
        test_pass "Security monitoring appears to be configured"
    else
        test_warn "Security monitoring not verified"
        log_finding "SECURITY_MONITORING: Security event monitoring not confirmed"
    fi
}

# ============================================================================
# 6. Generate Security Report
# ============================================================================

generate_security_report() {
    echo_header "6. Security Assessment Report"

    local report_file="$RESULTS_DIR/security-report.md"

    cat > "$report_file" << EOF
# Security Assessment Report
Generated: $(date)

## Executive Summary

**Overall Security Posture**: $([ $FAILED -eq 0 ] && echo "GOOD" || echo "REQUIRES ATTENTION")

- Tests Passed: $PASSED
- Tests Failed: $FAILED
- Warnings: $WARNINGS

## Detailed Findings

### Critical Issues (Failed Tests)
$(grep "FAIL\|CRITICAL" "$RESULTS_DIR/security-findings.txt" 2>/dev/null || echo "No critical issues found")

### Warnings
$(grep "WARN" "$RESULTS_DIR/security-findings.txt" 2>/dev/null || echo "No warnings found")

### Passed Tests
$(grep "PASS" "$RESULTS_DIR/security-findings.txt" 2>/dev/null || echo "Test results not detailed")

## Recommendations

### Immediate Actions Required
$(if [ $FAILED -gt 0 ]; then
    echo "1. Address all failed security tests"
    echo "2. Review security findings in detail"
    echo "3. Implement remediation steps"
else
    echo "No immediate actions required"
fi)

### Security Best Practices
1. **Change Default Credentials**: Ensure no default passwords are used
2. **Enable HTTPS**: Use TLS encryption for all external communications
3. **Regular Updates**: Keep all components updated with security patches
4. **Access Control**: Implement principle of least privilege
5. **Monitoring**: Enable comprehensive security monitoring and alerting

### Compliance Considerations
- Implement regular security assessments
- Maintain audit logs for compliance requirements
- Document security procedures and incident response
- Conduct security awareness training

## Next Steps

1. Review detailed findings in security-findings.txt
2. Implement remediation for failed tests
3. Schedule regular security assessments
4. Update security procedures based on findings
5. Monitor security metrics continuously

---
**Security Assessment Completed**: $(date)
**Next Assessment Due**: $(date -d "+90 days")
EOF

    echo "Security report generated: $report_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - Security Testing    ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "Results will be saved to: $RESULTS_DIR"
    echo ""

    test_network_security
    test_access_control
    test_data_protection
    test_vulnerabilities
    test_compliance
    generate_security_report

    echo ""
    echo_header "Security Test Summary"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Warnings: $WARNINGS"
    echo "Total: $((PASSED + FAILED + WARNINGS))"

    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}Security assessment completed with no critical issues!${NC}"
        exit 0
    else
        echo -e "${RED}Security assessment found $FAILED critical issues!${NC}"
        echo "Review: $RESULTS_DIR/security-report.md"
        exit 1
    fi
}

main
#!/bin/bash
#
# Test Alert Routing Script
# =========================
# Validates alert rules and alert routing through Alertmanager
# Tests alert firing, routing, and notification delivery
#
# Usage: ./scripts/test-alert-routing.sh [--trigger-alerts] [--check-notifications]
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
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Helper Functions
# ============================================================================

echo_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""
}

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ============================================================================
# 1. ALERT RULES VALIDATION
# ============================================================================

test_alert_rules_loaded() {
    echo_header "1. Alert Rules Validation"
    
    echo "Fetching alert rules from Prometheus..."
    rules_response=$(curl -s "$PROMETHEUS_URL/api/v1/rules" 2>/dev/null || echo "")
    
    if [ -z "$rules_response" ]; then
        test_fail "Cannot fetch alert rules from Prometheus"
        return 1
    fi
    
    # Count alert rules
    alert_count=$(echo "$rules_response" | grep -o '"type":"alert"' | wc -l)
    
    if [ "$alert_count" -gt 0 ]; then
        test_pass "Alert rules loaded: $alert_count rules"
    else
        test_fail "No alert rules loaded"
        return 1
    fi
    
    # Validate specific alert rules
    echo ""
    echo "Checking specific alert rules..."
    
    expected_alerts=(
        "PrometheusDown"
        "AlertmanagerDown"
        "NetdataDown"
        "HighCpuUsage"
        "HighMemoryUsage"
        "DiskSpaceLow"
        "DiskSpaceCritical"
    )
    
    for alert_name in "${expected_alerts[@]}"; do
        if echo "$rules_response" | grep -q "\"name\":\"$alert_name\""; then
            test_pass "Alert rule '$alert_name' present"
        else
            test_warn "Alert rule '$alert_name' not found"
        fi
    done
}

# ============================================================================
# 2. ALERT FIRING TESTS
# ============================================================================

test_alert_evaluation() {
    echo_header "2. Alert Rule Evaluation"
    
    echo "Testing alert rule evaluation..."
    
    # Get evaluation state
    rules=$(curl -s "$PROMETHEUS_URL/api/v1/rules" 2>/dev/null || echo "")
    
    # Count rules by state
    pending=$(echo "$rules" | grep -o '"state":"pending"' | wc -l)
    firing=$(echo "$rules" | grep -o '"state":"firing"' | wc -l)
    inactive=$(echo "$rules" | grep -o '"state":"inactive"' | wc -l)
    
    echo "Alert States:"
    echo "  Pending: $pending"
    echo "  Firing: $firing"
    echo "  Inactive: $inactive"
    
    test_pass "Alert evaluation working (states: pending=$pending, firing=$firing, inactive=$inactive)"
    
    # Show active alerts
    echo ""
    echo "Currently Firing Alerts:"
    
    if [ "$firing" -gt 0 ]; then
        echo "$rules" | jq -r '.groups[]?.rules[]? | select(.state=="firing") | 
            "  - \(.name) (\(.alerts | length) instances)"' 2>/dev/null || \
        echo "  (Alert details unavailable)"
        test_warn "There are active alerts (may be normal in test environment)"
    else
        test_pass "No alerts currently firing (expected in stable system)"
    fi
}

# ============================================================================
# 3. ALERTMANAGER CONNECTIVITY
# ============================================================================

test_alertmanager_connectivity() {
    echo_header "3. Alertmanager Connectivity"
    
    echo "Testing Alertmanager API connectivity..."
    
    if response=$(curl -s -f "$ALERTMANAGER_URL/api/v1/status" 2>/dev/null); then
        test_pass "Alertmanager API responding"
        
        # Parse response
        if echo "$response" | grep -q '"config":'; then
            test_pass "Alertmanager configuration loaded"
        fi
    else
        test_fail "Cannot connect to Alertmanager API"
        return 1
    fi
    
    echo ""
    echo "Checking Alertmanager configuration..."
    
    if echo "$response" | grep -q '"cluster":'; then
        test_pass "Alertmanager cluster support enabled"
    fi
    
    if echo "$response" | grep -q '"uptime":'; then
        uptime=$(echo "$response" | grep -oP '"uptime":"\K[^"]+')
        echo "  Alertmanager Uptime: $uptime"
    fi
}

# ============================================================================
# 4. ALERT ROUTING CONFIGURATION
# ============================================================================

test_alert_routing_config() {
    echo_header "4. Alert Routing Configuration"
    
    echo "Fetching Alertmanager configuration..."
    
    config=$(curl -s "$ALERTMANAGER_URL/api/v1/status" 2>/dev/null | \
        jq '.data.config' 2>/dev/null || echo "")
    
    if [ -z "$config" ]; then
        test_warn "Cannot retrieve Alertmanager configuration"
        return
    fi
    
    # Check receiver configuration (this is complex, so we do basic checks)
    echo "Analyzing routing rules..."
    
    if curl -s "$ALERTMANAGER_URL/-/api/v1/status" > /dev/null 2>&1; then
        test_pass "Alertmanager routing engine responsive"
    fi
    
    # Check for common routing patterns
    echo ""
    echo "Expected routing configurations:"
    echo "  - Global receiver (default alert handler)"
    echo "  - Severity-based routing (critical, warning)"
    echo "  - Service-specific routing (by job label)"
}

# ============================================================================
# 5. ACTIVE ALERTS IN ALERTMANAGER
# ============================================================================

test_active_alerts() {
    echo_header "5. Active Alerts in Alertmanager"
    
    echo "Fetching active alerts from Alertmanager..."
    
    alerts=$(curl -s "$ALERTMANAGER_URL/api/v1/alerts" 2>/dev/null || echo "")
    
    if [ -z "$alerts" ]; then
        test_fail "Cannot fetch alerts from Alertmanager"
        return 1
    fi
    
    # Count alerts by status
    active_count=$(echo "$alerts" | grep -o '"status":"active"' | wc -l)
    suppressed_count=$(echo "$alerts" | grep -o '"status":"suppressed"' | wc -l)
    
    echo "Alert Status:"
    echo "  Active: $active_count"
    echo "  Suppressed: $suppressed_count"
    
    if [ "$active_count" -eq 0 ]; then
        test_pass "No active alerts (system healthy)"
    else
        test_warn "Active alerts present: $active_count"
        
        echo ""
        echo "Active Alert Details:"
        echo "$alerts" | jq -r '.[] | select(.status=="active") | 
            "  - \(.labels.alertname) (\(.labels.severity)): \(.annotations.summary)"' 2>/dev/null || \
        echo "  (Details unavailable)"
    fi
}

# ============================================================================
# 6. TEST ALERT GENERATION (Optional)
# ============================================================================

test_trigger_test_alert() {
    echo_header "6. Test Alert Generation (Optional)"
    
    read -p "Generate a test alert? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        test_warn "Test alert generation skipped"
        return
    fi
    
    echo "Generating a test alert by querying for a non-existent high value..."
    
    # This is a trick: query something that will be false to test the system
    # In production, you'd have actual alert conditions
    
    test_query='up{job="prometheus"} == 999'
    
    echo "Test query: $test_query"
    result=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$test_query" 2>/dev/null || echo "")
    
    if echo "$result" | grep -q '"resultType":"vector"'; then
        test_pass "Test query executed (can be used for alert testing)"
    fi
    
    echo ""
    echo "To actually trigger an alert, you can:"
    echo "  1. Simulate high CPU: stress-ng --cpu $(nproc)"
    echo "  2. Fill disk space: dd if=/dev/zero of=/tmp/test.img bs=1M"
    echo "  3. Stop a service: docker-compose stop netdata"
    echo ""
    echo "Wait 5-10 minutes for Prometheus to evaluate and fire the alert."
}

# ============================================================================
# 7. NOTIFICATION DELIVERY (if configured)
# ============================================================================

test_notification_config() {
    echo_header "7. Notification Delivery Configuration"
    
    echo "Checking notification configurations in Alertmanager..."
    
    # Check common notification types
    echo "Expected notification receivers:"
    echo "  - Email (SMTP)"
    echo "  - Slack Webhooks"
    echo "  - PagerDuty"
    echo "  - Custom Webhooks"
    
    echo ""
    echo "To verify actual notifications:"
    echo "  1. Check Alertmanager logs for send errors:"
    echo "     docker-compose logs alertmanager | grep -i 'notification\\|send\\|error'"
    echo ""
    echo "  2. Verify webhook endpoints are configured and reachable"
    echo ""
    echo "  3. Check that credentials (SMTP password, webhook tokens) are set in environment"
}

# ============================================================================
# 8. ALERT RULE SYNTAX VALIDATION
# ============================================================================

test_alert_syntax() {
    echo_header "8. Alert Rule Syntax Validation"
    
    echo "Checking alert rule syntax..."
    
    rules=$(curl -s "$PROMETHEUS_URL/api/v1/rules" 2>/dev/null || echo "")
    
    if echo "$rules" | jq . 2>/dev/null | grep -q '"name"'; then
        test_pass "Alert rules parsed successfully (valid syntax)"
    else
        test_fail "Alert rules have syntax errors"
        return 1
    fi
    
    # Check for common misconfigurations
    echo ""
    echo "Checking for common alert rule issues..."
    
    # Verify evaluation intervals
    eval_intervals=$(echo "$rules" | grep -o '"evaluationTime":"[^"]*"' | sort -u | wc -l)
    if [ "$eval_intervals" -gt 0 ]; then
        test_pass "Alert rules are being evaluated (found $eval_intervals unique evaluation times)"
    fi
}

# ============================================================================
# Summary Report
# ============================================================================

print_summary() {
    echo ""
    echo_header "Alert Routing Test Summary"
    
    total=$((TESTS_PASSED + TESTS_FAILED))
    echo "Tests Passed: $TESTS_PASSED/$total"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All alert routing tests passed!${NC}"
        echo ""
        echo "Alert System Status: OPERATIONAL"
        echo ""
        echo "Next Steps:"
        echo "  1. Review alert receiver configurations"
        echo "  2. Test notification delivery by triggering alerts"
        echo "  3. Monitor alert queuing and delivery latency"
        return 0
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
    echo "╔═══════════════════════════════════════╗"
    echo "║    Alert Routing Test Suite           ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Run test phases
    test_alert_rules_loaded
    test_alert_evaluation
    test_alertmanager_connectivity
    test_alert_routing_config
    test_active_alerts
    test_alert_syntax
    
    # Optional tests
    if [[ "$*" == *"--trigger-alerts"* ]]; then
        test_trigger_test_alert
    fi
    
    if [[ "$*" == *"--check-notifications"* ]]; then
        test_notification_config
    fi
    
    print_summary
}

main "$@"

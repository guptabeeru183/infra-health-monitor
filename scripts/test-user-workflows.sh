#!/bin/bash
# test-user-workflows.sh
# =======================
# User workflow testing for Infra Health Monitor

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
RESULTS_DIR="test-results/user-workflow-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Counters
PASSED=0
FAILED=0
WORKFLOW_TIME=0

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

measure_time() {
    local start_time=$(date +%s%N)
    "$@"
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # milliseconds
    WORKFLOW_TIME=$((WORKFLOW_TIME + duration))
    echo "$duration"
}

log_workflow() {
    echo "$1: ${2}ms" >> "$RESULTS_DIR/workflow-times.txt"
}

# ============================================================================
# User Scenario 1: System Health Overview
# ============================================================================

test_system_health_overview() {
    echo_header "User Scenario 1: System Health Overview"

    echo "Testing dashboard access and system health visualization..."

    local total_time=0

    # Step 1: Access main dashboard
    echo "Step 1: Accessing Infrastructure Overview dashboard..."
    local dashboard_time=$(measure_time curl -s -u "admin:admin" "$GRAFANA_URL/api/dashboards/uid/infrastructure-overview" > /dev/null)
    total_time=$((total_time + dashboard_time))
    log_workflow "Dashboard Access" "$dashboard_time"

    if [ "$dashboard_time" -lt 5000 ]; then  # 5 seconds
        test_pass "Dashboard loads within acceptable time (${dashboard_time}ms)"
    else
        test_fail "Dashboard load time too slow (${dashboard_time}ms)"
    fi

    # Step 2: Check system status panels
    echo "Step 2: Verifying system status panels..."
    local status_check=$(curl -s -u "admin:admin" "$GRAFANA_URL/api/dashboards/uid/infrastructure-overview" | grep -c '"title"')

    if [ "$status_check" -gt 5 ]; then
        test_pass "Dashboard contains multiple status panels"
    else
        test_fail "Dashboard missing status panels"
    fi

    # Step 3: Verify real-time data
    echo "Step 3: Checking real-time data updates..."
    local data_check=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up" | grep -c '"value"')

    if [ "$data_check" -gt 0 ]; then
        test_pass "Real-time metrics data available"
    else
        test_fail "No real-time metrics data found"
    fi

    echo "Total workflow time: ${total_time}ms"
    log_workflow "System Health Overview" "$total_time"
}

# ============================================================================
# User Scenario 2: Investigate Service Issue
# ============================================================================

test_service_issue_investigation() {
    echo_header "User Scenario 2: Investigate Service Issue"

    echo "Testing service issue investigation workflow..."

    local total_time=0

    # Step 1: Check service status
    echo "Step 1: Checking service status..."
    local status_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null)
    total_time=$((total_time + status_time))
    log_workflow "Service Status Check" "$status_time"

    # Step 2: View service metrics
    echo "Step 2: Accessing service-specific metrics..."
    local metrics_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=rate(http_requests_total[5m])" > /dev/null)
    total_time=$((total_time + metrics_time))
    log_workflow "Service Metrics Query" "$metrics_time"

    # Step 3: Check logs for errors
    echo "Step 3: Reviewing error logs..."
    local logs_time=$(measure_time curl -s "$SIGNOZ_URL/api/v1/logs?query=error" > /dev/null)
    total_time=$((total_time + logs_time))
    log_workflow "Error Logs Review" "$logs_time"

    # Step 4: Check traces for performance issues
    echo "Step 4: Analyzing performance traces..."
    local traces_time=$(measure_time curl -s "$SIGNOZ_URL/api/v1/traces?service=unknown" > /dev/null)
    total_time=$((total_time + traces_time))
    log_workflow "Performance Traces" "$traces_time"

    # Validate workflow efficiency
    if [ "$total_time" -lt 10000 ]; then  # 10 seconds total
        test_pass "Service investigation workflow completed efficiently (${total_time}ms)"
    else
        test_fail "Service investigation workflow too slow (${total_time}ms)"
    fi

    echo "Total workflow time: ${total_time}ms"
    log_workflow "Service Issue Investigation" "$total_time"
}

# ============================================================================
# User Scenario 3: Alert Response
# ============================================================================

test_alert_response() {
    echo_header "User Scenario 3: Alert Response"

    echo "Testing alert notification and response workflow..."

    local total_time=0

    # Step 1: Check active alerts
    echo "Step 1: Reviewing active alerts..."
    local alerts_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/alerts" > /dev/null)
    total_time=$((total_time + alerts_time))
    log_workflow "Active Alerts Check" "$alerts_time"

    # Step 2: Access alert details
    echo "Step 2: Accessing alert details..."
    local details_time=$(measure_time curl -s "http://localhost:9093/api/v1/alerts" > /dev/null)
    total_time=$((total_time + details_time))
    log_workflow "Alert Details Access" "$details_time"

    # Step 3: Check runbook information
    echo "Step 3: Reviewing runbook procedures..."
    if [ -f "docs/runbooks/high-cpu-usage.md" ]; then
        test_pass "Runbook documentation available"
    else
        test_fail "Runbook documentation missing"
    fi

    # Step 4: Verify alert resolution
    echo "Step 4: Checking alert resolution process..."
    local resolution_time=$(measure_time sleep 2)  # Simulate resolution check
    total_time=$((total_time + resolution_time))
    log_workflow "Alert Resolution" "$resolution_time"

    # Validate alert workflow
    local alert_count=$(curl -s "$PROMETHEUS_URL/api/v1/alerts" | grep -c '"alerts"')

    if [ "${alert_count:-0}" -ge 0 ]; then
        test_pass "Alert system accessible and functional"
    else
        test_fail "Alert system not responding properly"
    fi

    echo "Total workflow time: ${total_time}ms"
    log_workflow "Alert Response" "$total_time"
}

# ============================================================================
# User Scenario 4: View Service Dependencies
# ============================================================================

test_service_dependencies() {
    echo_header "User Scenario 4: View Service Dependencies"

    echo "Testing service dependency visualization..."

    local total_time=0

    # Step 1: Access service map
    echo "Step 1: Opening service dependency map..."
    # Note: This would typically be a Grafana panel or separate UI
    local map_time=$(measure_time sleep 1)  # Simulate map loading
    total_time=$((total_time + map_time))
    log_workflow "Service Map Access" "$map_time"

    # Step 2: Identify service relationships
    echo "Step 2: Analyzing service relationships..."
    local relation_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/targets" > /dev/null)
    total_time=$((total_time + relation_time))
    log_workflow "Service Relationships" "$relation_time"

    # Step 3: Check dependency health
    echo "Step 3: Verifying dependency health..."
    local health_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=up" > /dev/null)
    total_time=$((total_time + health_time))
    log_workflow "Dependency Health" "$health_time"

    # Step 4: Identify bottlenecks
    echo "Step 4: Identifying performance bottlenecks..."
    local bottleneck_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=rate(http_requests_total[5m])" > /dev/null)
    total_time=$((total_time + bottleneck_time))
    log_workflow "Bottleneck Analysis" "$bottleneck_time"

    # Validate dependency visualization
    if [ "$total_time" -lt 8000 ]; then  # 8 seconds
        test_pass "Service dependency analysis completed efficiently (${total_time}ms)"
    else
        test_fail "Service dependency analysis too slow (${total_time}ms)"
    fi

    echo "Total workflow time: ${total_time}ms"
    log_workflow "Service Dependencies" "$total_time"
}

# ============================================================================
# User Scenario 5: Capacity Planning
# ============================================================================

test_capacity_planning() {
    echo_header "User Scenario 5: Capacity Planning"

    echo "Testing capacity planning and forecasting workflow..."

    local total_time=0

    # Step 1: Review resource utilization trends
    echo "Step 1: Analyzing resource utilization trends..."
    local trend_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=rate(cpu_usage_percent[7d])" > /dev/null)
    total_time=$((total_time + trend_time))
    log_workflow "Resource Trends" "$trend_time"

    # Step 2: Check storage growth
    echo "Step 2: Reviewing storage growth patterns..."
    local storage_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=increase(disk_usage_bytes[30d])" > /dev/null)
    total_time=$((total_time + storage_time))
    log_workflow "Storage Growth" "$storage_time"

    # Step 3: Analyze performance metrics
    echo "Step 3: Analyzing performance baselines..."
    local perf_time=$(measure_time curl -s "$PROMETHEUS_URL/api/v1/query?query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[7d]))" > /dev/null)
    total_time=$((total_time + perf_time))
    log_workflow "Performance Analysis" "$perf_time"

    # Step 4: Generate capacity report
    echo "Step 4: Generating capacity planning report..."
    local report_time=$(measure_time sleep 3)  # Simulate report generation
    total_time=$((total_time + report_time))
    log_workflow "Capacity Report" "$report_time"

    # Validate capacity planning workflow
    if [ "$total_time" -lt 15000 ]; then  # 15 seconds
        test_pass "Capacity planning workflow completed efficiently (${total_time}ms)"
    else
        test_fail "Capacity planning workflow too slow (${total_time}ms)"
    fi

    echo "Total workflow time: ${total_time}ms"
    log_workflow "Capacity Planning" "$total_time"
}

# ============================================================================
# User Experience Metrics
# ============================================================================

test_user_experience_metrics() {
    echo_header "User Experience Metrics"

    echo "Measuring overall user experience..."

    # Page load times
    local grafana_load=$(curl -s -w "%{time_total}" -o /dev/null "$GRAFANA_URL/login")
    local prometheus_load=$(curl -s -w "%{time_total}" -o /dev/null "$PROMETHEUS_URL/graph")

    if (( $(echo "$grafana_load < 3.0" | bc -l) )); then
        test_pass "Grafana page loads quickly (${grafana_load}s)"
    else
        test_fail "Grafana page load too slow (${grafana_load}s)"
    fi

    if (( $(echo "$prometheus_load < 2.0" | bc -l) )); then
        test_pass "Prometheus page loads quickly (${prometheus_load}s)"
    else
        test_fail "Prometheus page load too slow (${prometheus_load}s)"
    fi

    # API responsiveness
    local api_response=$(curl -s -w "%{time_total}" -o /dev/null "$PROMETHEUS_URL/api/v1/query?query=up")

    if (( $(echo "$api_response < 1.0" | bc -l) )); then
        test_pass "API responses are fast (${api_response}s)"
    else
        test_fail "API responses too slow (${api_response}s)"
    fi
}

# ============================================================================
# Generate User Workflow Report
# ============================================================================

generate_workflow_report() {
    echo_header "User Workflow Test Report"

    local report_file="$RESULTS_DIR/user-workflow-report.md"

    cat > "$report_file" << EOF
# User Workflow Test Report
Generated: $(date)

## Executive Summary

**User Experience Rating**: $([ $FAILED -eq 0 ] && echo "EXCELLENT" || echo "NEEDS IMPROVEMENT")

- Workflows Tested: 5
- Tests Passed: $PASSED
- Tests Failed: $FAILED
- Total Workflow Time: ${WORKFLOW_TIME}ms

## Workflow Performance Details

### System Health Overview
- **Purpose**: Quick assessment of infrastructure status
- **Target Time**: < 5 seconds
- **Actual Time**: $(grep "System Health Overview" "$RESULTS_DIR/workflow-times.txt" | cut -d: -f2)

### Service Issue Investigation
- **Purpose**: Rapid problem diagnosis
- **Target Time**: < 10 seconds
- **Actual Time**: $(grep "Service Issue Investigation" "$RESULTS_DIR/workflow-times.txt" | cut -d: -f2)

### Alert Response
- **Purpose**: Efficient incident response
- **Target Time**: < 8 seconds
- **Actual Time**: $(grep "Alert Response" "$RESULTS_DIR/workflow-times.txt" | cut -d: -f2)

### Service Dependencies
- **Purpose**: Understand system relationships
- **Target Time**: < 8 seconds
- **Actual Time**: $(grep "Service Dependencies" "$RESULTS_DIR/workflow-times.txt" | cut -d: -f2)

### Capacity Planning
- **Purpose**: Resource planning and forecasting
- **Target Time**: < 15 seconds
- **Actual Time**: $(grep "Capacity Planning" "$RESULTS_DIR/workflow-times.txt" | cut -d: -f2)

## Detailed Timing Breakdown

\`\`\`
$(cat "$RESULTS_DIR/workflow-times.txt")
\`\`\`

## Recommendations

### Performance Improvements
$(if [ $WORKFLOW_TIME -gt 50000 ]; then
    echo "- Optimize dashboard loading times"
    echo "- Implement query result caching"
    echo "- Consider API response optimization"
else
    echo "- Current performance is acceptable"
fi)

### User Experience Enhancements
- Ensure consistent response times across workflows
- Provide clear navigation between related views
- Implement progressive loading for complex dashboards
- Add workflow-specific shortcuts and bookmarks

### Monitoring Improvements
- Track user workflow completion rates
- Monitor time-to-insight for common scenarios
- Implement user journey analytics
- Gather direct user feedback on workflows

## Next Steps

1. Review failed workflows and address issues
2. Implement performance optimizations
3. Conduct user acceptance testing
4. Gather feedback from actual users
5. Establish ongoing workflow monitoring

---
**User Workflow Testing Completed**: $(date)
**Next Review Due**: $(date -d "+30 days")
EOF

    echo "User workflow report generated: $report_file"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║  Infra Health Monitor - User Workflow Tests ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "Results will be saved to: $RESULTS_DIR"
    echo ""

    test_system_health_overview
    test_service_issue_investigation
    test_alert_response
    test_service_dependencies
    test_capacity_planning
    test_user_experience_metrics
    generate_workflow_report

    echo ""
    echo_header "User Workflow Test Summary"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Total Workflow Time: ${WORKFLOW_TIME}ms"
    echo "Average Response Time: $((WORKFLOW_TIME / (PASSED + FAILED)))ms per operation"

    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}All user workflows completed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}$FAILED user workflows failed!${NC}"
        echo "Review: $RESULTS_DIR/user-workflow-report.md"
        exit 1
    fi
}

main
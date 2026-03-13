# Operations Manual
## Infra Health Monitor - Production Operations Guide

This manual provides comprehensive operational procedures for maintaining the Infra Health Monitor platform in production environments.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Weekly Maintenance](#weekly-maintenance)
3. [Monthly Reviews](#monthly-reviews)
4. [Emergency Procedures](#emergency-procedures)
5. [Troubleshooting Guide](#troubleshooting-guide)
6. [Contact Information](#contact-information)
7. [Performance Monitoring](#performance-monitoring)
8. [Backup and Recovery](#backup-and-recovery)

## Daily Operations

### Morning Health Check (9:00 AM)

**Objective**: Ensure all monitoring services are operational and collecting data.

**Procedure**:
```bash
# 1. Check service status
make status

# 2. Verify health endpoints
make health

# 3. Check for active alerts
curl -s http://localhost:9093/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'

# 4. Verify data ingestion (last 5 minutes)
curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length'

# 5. Check Grafana accessibility
curl -s -u "admin:admin" http://localhost:3000/api/health
```

**Expected Results**:
- All services show "Up" status
- No critical alerts firing
- Data points present for monitored services
- Grafana returns healthy status

**Escalation**: If any service is down, proceed to [Service Recovery](#service-recovery) procedures.

### Data Quality Verification (10:00 AM)

**Objective**: Ensure monitoring data quality and completeness.

**Checks**:
```bash
# Verify metrics collection
curl -s "http://localhost:9090/api/v1/query?query=count(up)" | jq '.data.result[0].value[1]'

# Check SigNoz log ingestion
curl -s "http://localhost:3301/api/v1/logs/count" | jq '.data'

# Verify trace collection
curl -s "http://localhost:3301/api/v1/traces/count" | jq '.data'
```

**Thresholds**:
- Metrics: > 90% of expected services reporting
- Logs: Steady ingestion rate (no drops > 50%)
- Traces: Active trace collection from instrumented services

### Alert Review (11:00 AM)

**Objective**: Review overnight alerts and assess impact.

**Procedure**:
1. Access Alertmanager UI: http://localhost:9093
2. Review silenced alerts
3. Check alert history for patterns
4. Update runbooks if needed
5. Document false positives

### Capacity Monitoring (2:00 PM)

**Objective**: Monitor resource utilization trends.

**Checks**:
```bash
# Check disk usage
df -h | grep -E "/$|/data"

# Monitor container resources
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check Prometheus metrics volume
curl -s "http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_samples_appended_total" | jq '.data.result[0].value[1]'
```

**Thresholds**:
- Disk usage: < 80%
- CPU: < 70% sustained
- Memory: < 80%
- Metrics volume: Within expected growth rate

## Weekly Maintenance

### Monday: System Updates Review

**Objective**: Review and plan system updates.

**Procedure**:
```bash
# Check for Docker image updates
docker-compose pull

# Review submodule updates
git submodule status

# Check security advisories for components
# - Netdata: https://github.com/netdata/netdata/security/advisories
# - SigNoz: https://github.com/SigNoz/signoz/security/advisories
# - Uptime Kuma: https://github.com/louislam/uptime-kuma/security/advisories
# - Prometheus/Grafana: Official security bulletins
```

**Documentation**: Update `SUBMODULE_VERSIONS.txt` with any planned updates.

### Tuesday: Performance Testing

**Objective**: Validate system performance against baselines.

**Procedure**:
```bash
# Run performance test suite
make test-performance

# Review results against baselines
cat test-results/performance-*/performance-report.md

# Check for performance degradation
# Compare with previous week's results
```

**Escalation**: If performance degrades > 10%, investigate immediately.

### Wednesday: Backup Verification

**Objective**: Ensure backup integrity and test restore procedures.

**Procedure**:
```bash
# Verify backup completion
ls -la backups/ | tail -5

# Test configuration backup
tar -tzf backups/config-$(date +%Y%m%d).tar.gz | head -10

# Test data restore (on staging environment)
# Document in BACKUP_VERIFICATION.md
```

### Thursday: Alert Effectiveness Review

**Objective**: Review alert quality and effectiveness.

**Procedure**:
1. Analyze alert metrics:
   ```bash
   # Alert firing rate
   curl -s "http://localhost:9090/api/v1/query?query=rate(alertmanager_alerts_total[7d])"

   # Alert resolution time
   curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, rate(alertmanager_alerts_invalid_total_bucket[7d]))"
   ```

2. Review false positive/negative rates
3. Update alert rules if needed
4. Document improvements in `ALERT_REVIEW.md`

### Friday: Capacity Planning

**Objective**: Review growth trends and plan capacity.

**Procedure**:
1. Analyze metrics volume trends:
   ```bash
   # Metrics growth rate
   curl -s "http://localhost:9090/api/v1/query?query=rate(prometheus_tsdb_head_samples_appended_total[7d])"

   # Storage usage trends
   du -sh /data/prometheus/
   ```

2. Review monitored service count
3. Plan for scaling needs
4. Update capacity planning document

## Monthly Reviews

### First Monday: Security Review

**Objective**: Comprehensive security assessment.

**Procedure**:
```bash
# Run security tests
make test-security

# Review access logs
docker-compose logs --tail=1000 | grep -i "unauthorized\|forbidden\|error"

# Check for exposed ports
netstat -tlnp | grep LISTEN

# Review user access and permissions
# Audit Grafana user accounts and permissions
```

**Deliverable**: `SECURITY_REVIEW_$(date +%Y%m).md`

### Second Monday: Performance Optimization

**Objective**: Optimize system performance.

**Procedure**:
1. Run comprehensive load testing
2. Analyze performance bottlenecks
3. Review query optimization opportunities
4. Implement performance improvements
5. Update performance baselines

### Third Monday: Documentation Review

**Objective**: Ensure documentation accuracy and completeness.

**Procedure**:
1. Follow each runbook without referring to authors
2. Test all troubleshooting procedures
3. Verify all links in documentation
4. Update outdated information
5. Collect feedback from team members

### Fourth Monday: Stakeholder Review

**Objective**: Review system effectiveness with stakeholders.

**Procedure**:
1. Present monthly metrics dashboard
2. Review incident response effectiveness
3. Gather user feedback
4. Plan improvements for next month
5. Update roadmap priorities

## Emergency Procedures

### Service Down - Critical Priority

**Immediate Actions**:
1. Confirm service status: `docker-compose ps`
2. Check service logs: `docker-compose logs <service>`
3. Attempt restart: `docker-compose restart <service>`
4. If restart fails, escalate to on-call engineer

**Escalation Path**:
- Level 1: On-call engineer (15 minutes)
- Level 2: DevOps lead (30 minutes)
- Level 3: Management (1 hour)

### Data Loss Incident

**Immediate Actions**:
1. Stop all write operations if possible
2. Assess data loss scope
3. Initiate backup restore if available
4. Document incident details
5. Notify stakeholders

**Recovery Steps**:
```bash
# Stop services
docker-compose down

# Restore from backup
./scripts/restore.sh <backup-file>

# Verify data integrity
make test-integration

# Restart services
docker-compose up -d
```

### Security Incident

**Immediate Actions**:
1. Isolate affected systems
2. Preserve evidence (logs, network captures)
3. Notify security team
4. Assess breach scope
5. Implement containment measures

**Post-Incident**:
- Conduct root cause analysis
- Update security measures
- Review incident response procedures
- Update team training

## Troubleshooting Guide

### Service Startup Failures

**Symptom**: Service shows "Exit" or "Restarting" status

**Diagnosis**:
```bash
# Check service logs
docker-compose logs <service> --tail=50

# Check resource constraints
docker stats <container>

# Verify configuration
docker-compose config

# Check dependencies
docker-compose ps
```

**Common Solutions**:
- Port conflicts: Change port mappings
- Resource limits: Increase memory/CPU limits
- Configuration errors: Validate YAML syntax
- Dependency failures: Check network connectivity

### Data Ingestion Issues

**Symptom**: Missing metrics/logs/traces

**Diagnosis**:
```bash
# Check OTEL collector logs
docker-compose logs otel-collector

# Verify network connectivity
curl -v http://localhost:4318/v1/traces

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify SigNoz ingestion
curl http://localhost:3301/api/v1/traces/count
```

**Solutions**:
- Network issues: Check firewall rules
- Configuration errors: Validate pipeline configs
- Resource constraints: Scale up resources
- Authentication failures: Verify credentials

### Alert Storm

**Symptom**: Excessive alert notifications

**Immediate Response**:
```bash
# Silence alerts temporarily
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{"matchers": [{"name": "alertname", "value": ".*", "isRegex": true}], "startsAt": "now", "endsAt": "in 1h", "comment": "Emergency silence"}'
```

**Root Cause Analysis**:
1. Identify triggering alerts
2. Check alert rules for logic errors
3. Review metric anomalies
4. Update alert thresholds if needed

### Performance Degradation

**Symptom**: Slow response times or high resource usage

**Diagnosis**:
```bash
# Check system resources
docker stats

# Analyze query performance
curl "http://localhost:9090/api/v1/query?query=up&stats"

# Review recent changes
git log --oneline -10

# Check for memory leaks
docker-compose logs | grep -i "memory\|leak"
```

**Optimization Steps**:
1. Restart problematic services
2. Clear caches if applicable
3. Review query optimization
4. Scale resources if needed

## Contact Information

### On-Call Rotation
- **Primary**: [Primary Engineer] - [Phone] - [Email]
- **Secondary**: [Secondary Engineer] - [Phone] - [Email]
- **Management**: [Manager] - [Phone] - [Email]

### External Contacts
- **Infrastructure Team**: [Team Email] - For infrastructure issues
- **Security Team**: [Security Email] - For security incidents
- **Vendor Support**:
  - Netdata: https://github.com/netdata/netdata/issues
  - SigNoz: https://github.com/SigNoz/signoz/issues
  - Uptime Kuma: https://github.com/louislam/uptime-kuma/issues

### Escalation Matrix

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| Critical | 15 minutes | On-call → Manager |
| High | 1 hour | On-call → Team Lead |
| Medium | 4 hours | Next business day |
| Low | 24 hours | Weekly review |

## Performance Monitoring

### Key Metrics to Monitor

#### System Health
- Service uptime (> 99.9%)
- Response times (< 2s for dashboards)
- Error rates (< 1%)
- Resource utilization (< 80%)

#### Data Quality
- Metrics collection rate (steady)
- Data completeness (> 95%)
- Alert accuracy (> 90%)
- False positive rate (< 5%)

#### User Experience
- Dashboard load times (< 3s)
- Query response times (< 1s)
- Alert notification delivery (< 30s)
- System availability (99.9%+)

### Monitoring Dashboards

**Primary Dashboard**: http://localhost:3000/d/infrastructure-overview
- Real-time system health
- Alert status
- Performance metrics
- Capacity utilization

**Detailed Metrics**: http://localhost:3000/d/prometheus-overview
- Prometheus performance
- Query latency
- Storage metrics
- Target health

**Application Monitoring**: http://localhost:3301/
- Log analysis
- Trace visualization
- Error tracking
- Performance insights

## Backup and Recovery

### Backup Schedule

**Daily (2:00 AM)**:
- Configuration files
- Grafana dashboards and datasources
- Alertmanager configuration
- Custom scripts and documentation

**Weekly (Sunday 3:00 AM)**:
- Full data backup (metrics, logs, traces)
- Database dumps if applicable
- Complete system snapshot

### Backup Verification

**Daily Checks**:
```bash
# Verify backup completion
ls -la backups/ | grep $(date +%Y%m%d)

# Check backup size (should be > 0)
du -sh backups/daily-$(date +%Y%m%d).tar.gz

# Test configuration restore
tar -tzf backups/config-$(date +%Y%m%d).tar.gz > /dev/null
```

### Recovery Procedures

#### Configuration Recovery
```bash
# Stop services
docker-compose down

# Restore configuration
tar -xzf backups/config-$(date +%Y%m%d).tar.gz -C .

# Validate configuration
docker-compose config

# Restart services
docker-compose up -d
```

#### Data Recovery
```bash
# Stop services
docker-compose down

# Restore data volumes
./scripts/restore-data.sh <backup-file>

# Verify data integrity
make test-integration

# Restart services
docker-compose up -d
```

### Recovery Time Objectives (RTO)

- **Configuration**: 30 minutes
- **Partial Data Loss**: 2 hours
- **Full System Recovery**: 4 hours
- **Complete Data Loss**: 8 hours (with backup)

### Recovery Point Objectives (RPO)

- **Configuration**: 1 hour
- **Metrics Data**: 1 hour
- **Logs Data**: 15 minutes
- **Traces Data**: 15 minutes

## Maintenance Windows

### Scheduled Maintenance
- **Weekly**: Tuesday 2:00-4:00 AM - Performance testing
- **Monthly**: First Sunday 1:00-3:00 AM - System updates
- **Quarterly**: Last Sunday of quarter - Major version updates

### Emergency Maintenance
- Announced 24 hours in advance
- Business impact assessment required
- Stakeholder approval needed
- Rollback plan mandatory

### Change Management

**Change Request Process**:
1. Submit change request with impact assessment
2. Review by change advisory board
3. Schedule during maintenance window
4. Implement with rollback plan
5. Post-implementation verification
6. Documentation update

**Change Categories**:
- **Standard**: Low risk, pre-approved procedures
- **Normal**: Medium risk, CAB review required
- **Emergency**: High risk, immediate implementation allowed

## Training and Certification

### Required Training
- **New Team Members**: Complete operations manual walkthrough
- **Annual Refresher**: All team members
- **Role-Specific**: On-call engineer certification
- **Technology Updates**: When major versions deployed

### Certification Requirements
- [ ] Complete operations manual review
- [ ] Pass troubleshooting assessment
- [ ] Demonstrate emergency procedures
- [ ] Shadow on-call engineer for one week

### Knowledge Base
- **Internal Wiki**: Detailed procedures and runbooks
- **Shared Drive**: Incident reports and post-mortems
- **GitHub Repository**: Configuration and scripts
- **Documentation Site**: User guides and API references

## Continuous Improvement

### Monthly Metrics Review
- System availability and performance
- Incident response times
- Alert effectiveness
- User satisfaction scores

### Quarterly Planning
- Capacity planning updates
- Technology roadmap review
- Process improvement initiatives
- Training program updates

### Annual Assessments
- Architecture review
- Disaster recovery testing
- Security audit
- Compliance verification

### Feedback Mechanisms
- **User Surveys**: Quarterly satisfaction surveys
- **Incident Reviews**: Post-mortem analysis
- **Suggestion Box**: Continuous improvement ideas
- **Team Retrospectives**: Monthly improvement discussions

---

## Quick Reference

### Critical Commands
```bash
# Health check
make health

# Service status
make status

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Emergency stop
docker-compose down
```

### Important URLs
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **SigNoz**: http://localhost:3301
- **Uptime Kuma**: http://localhost:3001

### Emergency Contacts
- **On-call Engineer**: [Current on-call]
- **DevOps Lead**: [Lead contact]
- **Management**: [Manager contact]

**Last Updated**: $(date)
**Version**: 1.0
**Review Cycle**: Monthly
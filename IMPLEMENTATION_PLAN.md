# Infra Health Monitor - Phase-wise Implementation Plan

## Overview

This document provides a detailed, incremental execution roadmap for building the unified infrastructure monitoring platform. The strategy uses Git submodules for stack orchestration, Docker Compose for container orchestration, and avoids modifying upstream source code.

**Total Expected Duration**: 4-6 weeks (1-2 weeks per Phase, executed sequentially with parallel work on non-blocking activities)

---

## Phase 1: Repository Setup and Folder Structure

### Objectives
- Establish the repository foundation with the correct directory structure
- Initialize Git with proper submodule configuration support
- Create configuration templates and base files
- Set up version tracking and documentation

### Tasks

#### 1.1 Initialize Repository Structure
- [ ] Create main directory structure according to architecture
- [ ] Create subdirectories: `stack/`, `integration/`, `configs/`, `dashboards/`, `scripts/`
- [ ] Create `.gitignore` to exclude sensitive files, volumes, and generated content
- [ ] Create `.gitmodules` placeholder for submodule declarations

#### 1.2 Create Base Configuration Files
- [ ] Create `docker-compose.yml` (base structure, not complete)
- [ ] Create `.env.example` for environment variable templates
- [ ] Create `versioning.txt` to track component versions
- [ ] Create basic `Makefile` for common operations (optional but recommended)

#### 1.3 Documentation Infrastructure
- [ ] Create `ARCHITECTURE.md` with detailed system design
- [ ] Create `DEPLOYMENT_GUIDE.md` for operators
- [ ] Create `TROUBLESHOOTING.md` for common issues
- [ ] Create `CHANGELOG.md` for version tracking

#### 1.4 Initialize Git Repository
- [ ] Initialize empty Git repository (if not already done)
- [ ] Create initial commit with skeleton structure
- [ ] Document submodule strategy in `.github/SUBMODULE_GUIDE.md`

### Files to Create or Modify

```
.gitignore
├── docker volumes/
├── .env (but keep .env.example)
├── logs/
├── data/
└── node_modules/

.gitmodules
├── [stack/dockprom]
├── [stack/netdata]
├── [stack/signoz]
└── [stack/uptime-kuma]

docker-compose.yml (v1 - base structure)
├── version: '3.8'
├── services: {} (empty)
└── volumes: {} (empty)

.env.example
├── GRAFANA_ADMIN_PASSWORD=admin123
├── PROMETHEUS_PORT=9090
├── GRAFANA_PORT=3000
├── ... (all service ports and credentials)

Makefile (optional)
├── init: Initialize submodules
├── up: Start stack
├── down: Stop stack
├── logs: View logs
└── clean: Remove volumes

docs/
├── SUBMODULE_GUIDE.md
├── ARCHITECTURE.md
├── DEPLOYMENT_GUIDE.md
├── TROUBLESHOOTING.md
└── CHANGELOG.md
```

### Expected Output
- Clean, organized repository structure
- `docker-compose.yml` skeleton ready for service definitions
- `.env.example` with all configuration parameters
- `.gitmodules` file ready for submodule declarations
- Git repository with initial commit
- Documentation foundation

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Merge conflicts in docker-compose.yml** | Use clear comments marking sections; one person responsible for docker-compose.yml structure; use YAML anchors for reusable configs |
| **Environment variable collisions** | Prefix all env vars by service (e.g., `PROMETHEUS_PORT`, `GRAFANA_PORT`); document all variables in `.env.example` |
| **Submodule path conflicts** | Plan submodule paths early; use consistent naming convention (e.g., `stack/<project-name>`) |
| **.gitignore too broad** | Start with minimal .gitignore; add entries only as needed; review .gitignore regularly |
| **Sensitive data in repo** | Use `.env.example` as template; ensure `.env` is in .gitignore; never commit credentials |

### Success Criteria
- [ ] Repository structure matches planned architecture
- [ ] `.gitignore` properly excludes volumes, .env file, and temporary data
- [ ] `docker-compose.yml` skeleton compiles (validates with `docker-compose config`)
- [ ] All documentation files created and linked from README
- [ ] Git history shows clean initial commit
- [ ] Team can clone and run `git submodule init` commands

---

## Phase 2: Adding Monitoring Stack via Git Submodules

### Objectives
- Add upstream monitoring projects as Git submodules
- Maintain complete independence from upstream code
- Establish clear upgrade and maintenance procedures
- Create submodule integration documentation

### Tasks

#### 2.1 Add dockprom (Prometheus + Grafana + Alertmanager)
- [ ] Add dockprom repository as submodule to `stack/dockprom`
  ```bash
  git submodule add https://github.com/stefanprodan/dockprom stack/dockprom
  ```
- [ ] Create override configuration directory: `configs/dockprom-overrides/`
- [ ] Document dockprom version tracking
- [ ] Create `integration/dockprom-entrypoint.sh` wrapper if needed
- [ ] Test submodule cloning and initialization

#### 2.2 Add Netdata
- [ ] Add netdata repository as submodule to `stack/netdata`
  ```bash
  git submodule add https://github.com/netdata/netdata stack/netdata
  ```
- [ ] Create override configuration directory: `configs/netdata-overrides/`
- [ ] Plan Netdata → Prometheus integration points
- [ ] Create edge-case handling documentation (standalone vs agent mode)

#### 2.3 Add SigNoz
- [ ] Add SigNoz repository as submodule to `stack/signoz`
  ```bash
  git submodule add https://github.com/SigNoz/signoz stack/signoz
  ```
- [ ] Create override configuration directory: `configs/signoz-overrides/`
- [ ] Document OpenTelemetry integration requirements
- [ ] Plan SigNoz data persistence strategy

#### 2.4 Add Uptime Kuma
- [ ] Add Uptime Kuma repository as submodule to `stack/uptime-kuma`
  ```bash
  git submodule add https://github.com/louislam/uptime-kuma stack/uptime-kuma
  ```
- [ ] Create override configuration directory: `configs/uptime-kuma-overrides/`
- [ ] Plan Uptime Kuma → Prometheus metric export

#### 2.5 Create Submodule Management Tools
- [ ] Create `scripts/submodule-init.sh` - Initialize all submodules
- [ ] Create `scripts/submodule-update.sh` - Update all submodules safely
- [ ] Create `scripts/submodule-status.sh` - Check submodule statuses
- [ ] Create `scripts/submodule-pin.sh` - Pin specific versions
- [ ] Document submodule upgrade procedure
- [ ] Create version lock file: `SUBMODULE_VERSIONS.txt`

#### 2.6 Update Documentation
- [ ] Document each submodule's purpose and key features
- [ ] Create upgrade guide for each component
- [ ] Document breaking changes between versions
- [ ] Create roll-back procedure documentation

### Files to Create or Modify

```
stack/
├── dockprom/ (submodule)
│   └── docker-compose.yml (upstream)
├── netdata/ (submodule)
├── signoz/ (submodule)
└── uptime-kuma/ (submodule)

configs/
├── dockprom-overrides/
│   ├── prometheus.yml (our customizations)
│   ├── alertmanager.yml (our customizations)
│   └── grafana-provisioning/ (our datasources)
├── netdata-overrides/
│   └── netdata.conf (our customizations)
├── signoz-overrides/
│   └── otel-collector-config.yml (our customizations)
└── uptime-kuma-overrides/
    └── config.json (our customizations)

scripts/
├── submodule-init.sh
├── submodule-update.sh
├── submodule-status.sh
├── submodule-pin.sh
└── verify-submodules.sh

.gitmodules (modified)
├── [submodule "stack/dockprom"]
├── [submodule "stack/netdata"]
├── [submodule "stack/signoz"]
└── [submodule "stack/uptime-kuma"]

SUBMODULE_VERSIONS.txt
├── dockprom: v1.x.x
├── netdata: v1.x.x
├── signoz: v0.x.x
└── uptime-kuma: v1.x.x

docs/SUBMODULE_MANAGEMENT.md (new)
├── Adding submodules
├── Updating submodules
├── Pinning versions
└── Roll-back procedures
```

### Expected Output
- Four working Git submodules pointing to upstream repositories
- Each submodule checked out at a stable, documented version
- Submodule management scripts functioning
- Version lock file tracking all component versions
- Clear documentation on submodule updates and roll-back

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Submodule initialization failures** | Use `git submodule update --init --recursive`; test cloning from scratch; document pre-requisites |
| **Inconsistent versions across team** | Maintain `SUBMODULE_VERSIONS.txt`; use pinning scripts; require version checks in CI/CD |
| **Upstream breaking changes** | Subscribe to upstream release notifications; test updates in feature branch; maintain compatibility matrix |
| **Detached HEAD state in submodules** | Document proper submodule checkout procedures; use helper scripts; add pre-commit hooks |
| **Large download sizes** | Use shallow clones if supported: `git submodule update --init --depth=1`; document disk space requirements |
| **Network timeouts during clone** | Provide retry logic in scripts; use longer timeouts; offer offline setup guide |

### Success Criteria
- [ ] All four submodules clone and initialize successfully from clean repo
- [ ] `git submodule status` shows all submodules at tagged versions
- [ ] `SUBMODULE_VERSIONS.txt` documents all pinned versions
- [ ] Submodule management scripts execute without errors
- [ ] Team members can update submodules using provided scripts
- [ ] Version roll-back procedure tested and documented

---

## Phase 3: Docker Compose Orchestration Layer

### Objectives
- Create unified Docker Compose configuration orchestrating all services
- Define service dependencies and startup order
- Configure networking, volumes, and resource limits
- Enable flexible environment-based configuration
- Create service health checks

### Tasks

#### 3.1 Create Main Docker Compose Configuration
- [ ] Create complete `docker-compose.yml` with all services
- [ ] Define service names matching architecture:
  - `prometheus` (from dockprom)
  - `grafana` (from dockprom)
  - `alertmanager` (from dockprom)
  - `netdata` (from netdata submodule)
  - `signoz-clickhouse` (from signoz)
  - `signoz-query-service` (from signoz)
  - `signoz-otel-collector` (from signoz)
  - `uptime-kuma` (from uptime-kuma)
- [ ] Define service dependencies using `depends_on` directive
- [ ] Configure startup order using health checks
- [ ] Set resource limits (CPU, memory) for each service
- [ ] Define port mappings matching service port documentation

#### 3.2 Configure Networking
- [ ] Create custom bridge network: `monitoring-network`
- [ ] Ensure all services on the same network
- [ ] Document service discovery DNS names
- [ ] Configure network isolation policies
- [ ] Test inter-service communication

#### 3.3 Configure Volumes and Persistence
- [ ] Define named volumes for data persistence:
  - `prometheus-storage` (metrics)
  - `grafana-storage` (dashboards, datasources)
  - `alertmanager-storage` (alert history)
  - `netdata-storage` (metrics cache)
  - `signoz-clickhouse-storage` (logs, traces, metrics)
  - `uptime-kuma-storage` (monitor data)
- [ ] Plan volume mount strategies (host vs named)
- [ ] Create backup/snapshot procedures
- [ ] Document data retention policies
- [ ] Test volume persistence across container restarts

#### 3.4 Create Environment Configuration
- [ ] Finalize `.env` file structure from template
- [ ] Create environment-specific configs:
  - `.env.development` (localhost, debug modes)
  - `.env.staging` (staging server)
  - `.env.production` (production server)
- [ ] Document all environment variables with descriptions
- [ ] Implement environment variable validation script
- [ ] Create secret management strategy (if needed)

#### 3.5 Implement Service Customization Strategy
- [ ] Create docker-compose override mechanism:
  - `docker-compose.yml` (base)
  - `docker-compose.override.yml` (local development)
  - `docker-compose.production.yml` (production)
- [ ] Document when to use each override file
- [ ] Create merge testing procedure
- [ ] Implement CI/CD validation for all compose files

#### 3.6 Create Initialization and Health Check Logic
- [ ] Implement health checks for all services:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s
  ```
- [ ] Create `scripts/health-check.sh` for manual verification
- [ ] Create `scripts/wait-for-services.sh` for deployment automation
- [ ] Document service startup dependencies and timing

#### 3.7 Test and Validate Orchestration
- [ ] Test full stack startup: `docker-compose up -d`
- [ ] Verify all services are healthy and running
- [ ] Test service restart resilience
- [ ] Test partial stack startup (some services only)
- [ ] Test stack shutdown and cleanup
- [ ] Document troubleshooting steps

### Files to Create or Modify

```
docker-compose.yml (complete)
├── version: '3.8'
├── services:
│   ├── prometheus
│   ├── grafana
│   ├── alertmanager
│   ├── netdata
│   ├── signoz-clickhouse
│   ├── signoz-query-service
│   ├── signoz-otel-collector
│   └── uptime-kuma
├── networks:
│   └── monitoring-network (bridge)
└── volumes:
    ├── prometheus-storage
    ├── grafana-storage
    ├── alertmanager-storage
    ├── netdata-storage
    ├── signoz-clickhouse-storage
    └── uptime-kuma-storage

docker-compose.override.yml (new)
├── Development overrides
├── Expose ports for debugging
└── Mount volumes from host for development

docker-compose.production.yml (new)
├── Production overrides
├── Resource limits
├── Security configurations
└── Backup volume definitions

.env.development (new)
.env.staging (new)
.env.production (new)

configs/
├── docker-compose-schema.json (validation)
└── environment-validation.sh (new)

scripts/
├── health-check.sh (new)
├── wait-for-services.sh (new)
├── validate-compose.sh (new)
└── service-diagnostics.sh (new)

docs/DOCKER_COMPOSE_GUIDE.md (new)
├── Service definitions
├── Networking and communication
├── Volume strategies
├── Environment variables
├── Health checks
├── Overrides mechanism
└── Troubleshooting
```

### Expected Output
- Fully functional `docker-compose.yml` file
- All services defined with proper dependencies
- Custom monitoring network configured
- Named volumes for all persistent data
- Environment configuration files for multiple deployment scenarios
- Health checks on all services
- Documentation and validation scripts
- Successful `docker-compose up -d` startup
- All services healthy and inter-connected

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Port conflicts** | Define all ports in `.env`; use port range checking script; document default ports in README |
| **Service startup order issues** | Use `depends_on` with health checks; implement `wait-for-services.sh`; add startup delays if necessary |
| **Volume mount permissions** | Use appropriate user IDs in containers; test on different host OSes; document permission requirements |
| **Network communication failures** | Use custom bridge network; test DNS resolution; document service discovery names |
| **Resource exhaustion** | Set resource limits; monitor during initial testing; document minimum hardware requirements |
| **Environment variable conflicts** | Use prefixed names; validate all env vars at startup; create comprehensive .env.example |
| **Dirty state after failed startup** | Implement cleanup scripts; use proper volume cleanup in docker-compose; test idempotent startup |

### Success Criteria
- [ ] `docker-compose config` validates without errors
- [ ] All services start successfully: `docker-compose up -d`
- [ ] All services report healthy status within 60 seconds
- [ ] Services can communicate with each other via network names
- [ ] Named volumes persist data across restarts
- [ ] `docker-compose down` cleanly stops all services
- [ ] Environment override files merge correctly
- [ ] Manual health checks pass with provided scripts
- [ ] Team can start/stop entire stack with single command

---

## Phase 4: Integration Between Services

### Objectives
- Configure Netdata → Prometheus metrics export
- Configure SigNoz OpenTelemetry collector
- Configure Uptime Kuma → Prometheus metrics export
- Establish data flow between all components
- Create integration validation procedures

### Tasks

#### 4.1 Netdata → Prometheus Integration
- [ ] Enable Netdata Prometheus exporter endpoint
  - Create `configs/netdata-overrides/netdata.conf`:
    ```ini
    [prometheus]
        enabled = yes
        listen on = 0.0.0.0:19999
    ```
- [ ] Configure Prometheus to scrape Netdata:
  - Create `configs/prometheus-overrides/netdata-scrape.yml`
  - Add scrape job for Netdata target
  - Set appropriate scrape intervals (15-30s)
- [ ] Test Netdata metrics in Prometheus
- [ ] Create validation script to check metrics ingestion
- [ ] Document metric naming and labels

#### 4.2 SigNoz OpenTelemetry Collector Integration
- [ ] Configure OpenTelemetry Collector for:
  - Metrics collection
  - Log collection
  - Trace collection
- [ ] Create `configs/signoz-overrides/otel-collector-config.yml`:
  ```yaml
  receivers:
    prometheus:
    otlp:
  processors:
    batch:
    memory_limiter:
  exporters:
    clickhouse:
  ```
- [ ] Configure exporters for ClickHouse backend
- [ ] Set up log pipelines (file-based logging)
- [ ] Configure trace pipelines
- [ ] Test data flow through SigNoz
- [ ] Verify ClickHouse data storage

#### 4.3 Uptime Kuma → Prometheus Integration
- [ ] Enable Uptime Kuma Prometheus exporter (if available) or:
- [ ] Create custom exporter bridge
  - Create `integration/uptime-kuma-exporter.py` (Python Flask app)
  - Expose `/metrics` endpoint with Prometheus format
  - Query Uptime Kuma API and convert to metrics
- [ ] Configure Prometheus to scrape Uptime Kuma metrics:
  - Add scrape job: `uptime-kuma-monitor`
  - Query metrics like: `uptime_status`, `uptime_response_time`
- [ ] Test uptime metrics in Prometheus
- [ ] Document exposed metrics

#### 4.4 Prometheus Configuration for All Targets
- [ ] Create comprehensive `configs/prometheus-overrides/prometheus.yml`:
  ```yaml
  global:
    scrape_interval: 15s
  scrape_configs:
    - job_name: 'prometheus'
    - job_name: 'netdata'
    - job_name: 'uptime-kuma'
    - job_name: 'signoz-metrics' (if applicable)
  ```
- [ ] Configure service discovery mechanisms
- [ ] Set up metric relabeling (if needed)
- [ ] Configure remote write to external systems (optional)
- [ ] Document all scrape configurations

#### 4.5 Alertmanager Configuration
- [ ] Configure `configs/alertmanager-overrides/alertmanager.yml`:
  - Define alert routing rules
  - Configure notification receivers
  - Set up grouping and inhibition rules
- [ ] Create basic alert rules:
  - Service down alerts
  - High resource utilization alerts
  - SigNoz ingestion errors
- [ ] Store alert rules in `configs/prometheus-overrides/alert-rules.yml`
- [ ] Test alert firing and notification routing

#### 4.6 Integration Testing Framework
- [ ] Create `scripts/integration-test.sh`:
  - Verify all services are running
  - Check Prometheus scrape targets
  - Validate metric ingestion
  - Verify data in SigNoz
  - Test uptime metrics
- [ ] Create health check matrix:
  - Service → Service connectivity
  - Data flow verification
  - Metric collection verification
- [ ] Implement continuous integration checks

#### 4.7 Create Integration Documentation
- [ ] Document data flow diagrams
- [ ] Document metric naming conventions
- [ ] Create troubleshooting guide for integration issues
- [ ] Document API endpoints used for integration
- [ ] Create backup/restore procedures for integrated data

### Files to Create or Modify

```
configs/
├── netdata-overrides/
│   └── netdata.conf (enable Prometheus exporter)
├── prometheus-overrides/
│   ├── prometheus.yml (complete with all targets)
│   ├── netdata-scrape.yml
│   ├── uptime-kuma-scrape.yml
│   └── alert-rules.yml
├── signoz-overrides/
│   └── otel-collector-config.yml
└── uptime-kuma-overrides/
    └── (configurations)

integration/
├── uptime-kuma-exporter.py (new, if custom exporter needed)
├── netdata-integration.sh
├── signoz-integration.sh
└── prometheus-integration.sh

scripts/
├── integration-test.sh (new)
├── verify-metrics-flow.sh (new)
├── check-scrape-targets.sh (new)
└── test-alert-routing.sh (new)

docs/
├── INTEGRATION_GUIDE.md (new)
├── DATA_FLOW.md (new)
├── METRIC_NAMING.md (new)
└── TROUBLESHOOTING_INTEGRATION.md (new)
```

### Expected Output
- Netdata metrics flowing into Prometheus
- Prometheus scraping all configured targets
- SigNoz collecting logs and traces
- Uptime Kuma metrics available in Prometheus
- All integration scripts passing validation
- Data flow verified end-to-end
- Alerting configured and tested

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Prometheus targets showing DOWN** | Verify service DNS resolution; check network connectivity; review service port configurations in scrape config |
| **Missing metrics in Prometheus** | Check scrape configs for correct targets; verify metrics path/port in exporters; test manual curl to exporter endpoints |
| **SigNoz not receiving data** | Verify OpenTelemetry Collector connectivity; check exporter configuration; review ClickHouse logs |
| **High cardinality metrics** | Implement metric relabeling; use metric dropping rules; monitor Prometheus memory usage |
| **Alertmanager not routing alerts** | Verify alert rule syntax; test with manual curl; review routing configuration; check notification receiver settings |
| **Custom exporter crashes** | Add error handling and logging; implement auto-restart; test with unit tests; add health checks |
| **Integration timing issues** | Add startup delays; use health checks; implement retry logic; document dependency order |

### Success Criteria
- [ ] All Prometheus scrape targets show UP status
- [ ] Netdata metrics visible in Prometheus query interface
- [ ] SigNoz dashboard shows incoming logs/traces/metrics
- [ ] Uptime monitoring data in Prometheus
- [ ] Integration test script passes completely
- [ ] Custom integrations (if any) functioning without errors
- [ ] Metric data flowing correctly between all components
- [ ] Alert rules firing correctly for test conditions

---

## Phase 5: Grafana Unified Dashboards

### Objectives
- Configure Grafana with all data sources
- Create unified dashboards combining metrics from all sources
- Implement dashboard templating and variables
- Set up dashboard provisioning for Infrastructure as Code
- Create alert-aware dashboards

### Tasks

#### 5.1 Configure Grafana Data Sources
- [ ] Create `configs/grafana-overrides/provisioning/datasources/datasources.yaml`:
  ```yaml
  apiVersion: 1
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
    - name: SigNoz
      type: clickhouse (or graphite)
      url: http://signoz-query-service:8080
    - name: Uptime Kuma
      type: prometheus
      url: http://uptime-kuma-exporter:5000 (if separate exporter)
  ```
- [ ] Test all data source connections
- [ ] Configure data source authentication (if needed)
- [ ] Set up data source alerting (optional)

#### 5.2 Create Infrastructure Overview Dashboard
- [ ] Create `dashboards/grafana/01-infrastructure-overview.json`:
  - System health summary cards
  - CPU, memory, disk usage across all devices
  - Network I/O graphs
  - Service status indicators
  - Alert summary panel
  - Key metrics from all sources
- [ ] Add drill-down capabilities to host-specific dashboards
- [ ] Implement templating for time range and refresh interval
- [ ] Add annotations for events

#### 5.3 Create Per-Host/Service Dashboards
- [ ] Create `dashboards/grafana/02-host-details.json`:
  - CPU usage (with breakdown)
  - Memory usage (with breakdown)
  - Disk space and I/O
  - Network interface stats
  - Process-level details
  - Recent alerts for this host
- [ ] Implement host variable selection dropdown
- [ ] Create linked panels for drill-down analysis
- [ ] Add historical comparison panels

#### 5.4 Create Application Monitoring Dashboard
- [ ] Create `dashboards/grafana/03-applications.json`:
  - Application health status
  - Request rates and latency
  - Error rates
  - Resource consumption by application
  - Dependency map (if applicable)
- [ ] Add SigNoz data for application traces
- [ ] Implement service variable selection
- [ ] Add alert correlation

#### 5.5 Create Uptime and Availability Dashboard
- [ ] Create `dashboards/grafana/04-uptime-monitoring.json`:
  - Uptime percentage by service
  - Response time trends
  - Downtime events
  - Service dependency status
  - SLA compliance metrics
- [ ] Add Uptime Kuma data source integration
- [ ] Implement status panels with color coding
- [ ] Add historical SLA tracking

#### 5.6 Create Logging and Observability Dashboard
- [ ] Create `dashboards/grafana/05-logs-observability.json`:
  - Log volume trends
  - Error log counts
  - Distributed traces
  - Log sampling explorer
  - Trace service map
- [ ] Integrate SigNoz logs and traces
- [ ] Implement log level filtering
  - Add trace correlation with metrics

#### 5.7 Create Performance and Capacity Planning Dashboard
- [ ] Create `dashboards/grafana/06-capacity-planning.json`:
  - Resource usage trends
  - Capacity utilization forecasts
  - Peak usage periods
  - Slow growth metrics
  - Resource allocation recommendations
- [ ] Add trend analysis with statistical forecasts
- [ ] Implement alerting thresholds visualization

#### 5.8 Create Alerting Dashboard
- [ ] Create `dashboards/grafana/07-alerting.json`:
  - Alert history timeline
  - Alert firing frequency
  - Alert resolution time
  - Alert distribution by service
  - On-call schedule (if applicable)
- [ ] Link to underlying metrics causing alerts
- [ ] Add silence/suppress alerts controls (if permitted)

#### 5.9 Dashboard Provisioning Strategy
- [ ] Create `configs/grafana-overrides/provisioning/dashboards/provider.yaml`:
  ```yaml
  apiVersion: 1
  providers:
    - name: 'Monitoring Dashboards'
      orgId: 1
      folder: 'Infrastructure'
      type: file
      disableDeletion: false
      updateIntervalSeconds: 10
      options:
        path: /etc/grafana/provisioning/dashboards
  ```
- [ ] Implement dashboard version control in Git
- [ ] Create CI/CD pipeline for dashboard validation
- [ ] Document dashboard backup and restore procedures

#### 5.10 Implement Dashboard Templating
- [ ] Create reusable dashboard templates:
  - Generic host dashboard template
  - Application monitoring template
  - Service component template
- [ ] Implement variable selection for:
  - Time ranges
  - Hosts/services
  - Metrics aggregation
  - Threshold values
- [ ] Test template functionality across different data sets

#### 5.11 Create Dashboard Documentation
- [ ] Document each dashboard's purpose and metrics
- [ ] Create user guide for dashboard navigation
- [ ] Document how to customize dashboards
- [ ] Create dashboard modification procedures
- [ ] Document metric/query language used

### Files to Create or Modify

```
configs/grafana-overrides/
├── provisioning/
│   ├── datasources/
│   │   └── datasources.yaml (all data sources)
│   ├── dashboards/
│   │   ├── provider.yaml
│   │   └── dashboards/ → ../../dashboards/grafana/
│   ├── alerting/ (optional, for Grafana native alerts)
│   └── plugins/ (optional, for Grafana plugins)

dashboards/grafana/
├── 01-infrastructure-overview.json
├── 02-host-details.json
├── 03-applications.json
├── 04-uptime-monitoring.json
├── 05-logs-observability.json
├── 06-capacity-planning.json
├── 07-alerting.json
└── _templates/ (reusable panels)

scripts/
├── dashboard-backup.sh (new)
├── dashboard-restore.sh (new)
├── dashboard-validate.sh (new)
├── test-grafana-datasources.sh (new)
└── export-dashboards.sh (new)

docs/GRAFANA_DASHBOARDS.md (new)
├── Data sources setup
├── Dashboard overview
├── Customization guide
└── Dashboard management
```

### Expected Output
- Grafana accessible at configured port
- All data sources connected and validated
- 7+ functional, production-ready dashboards
- Dashboard IaC implementation working
- Dashboards automatically loaded on startup
- Dashboard backup/restore procedures tested
- Unified monitoring interface operational

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Data source connection failures** | Verify all service hostnames resolve; test with curl; check network connectivity; review service logs |
| **Dashboard JSON syntax errors** | Use Grafana UI to create dashboards initially; validate JSON; use schema validation tool |
| **Missing metrics in dashboard** | Verify metric names in query builder; check Prometheus metric labels; test queries in Prometheus UI |
| **Dashboard performance issues** | Limit query time ranges; use metric aggregation; reduce graph resolution; implement caching |
| **Dashboard variable scope issues** | Test variable scoping; use proper label matching; verify variable options queries |
| **Provisioning not loading dashboards** | Verify provisioning YAML syntax; check file paths; review Grafana logs; restart Grafana service |
| **Merge conflicts in dashboard JSON** | Use provisioning approach; implement dashboard export/import workflow; document change procedures |

### Success Criteria
- [ ] Grafana web interface loads without errors
- [ ] All configured data sources show green/connected status
- [ ] Each dashboard loads and displays data correctly
- [ ] Variables and drill-down navigation work properly
- [ ] Dashboards provision automatically from git on startup
- [ ] Alerts/annotations display on dashboard graphs
- [ ] Dashboard backup can be restored successfully
- [ ] Team has clear documentation for dashboard usage
- [ ] Dashboard customization is maintainable and version-controlled

---

## Phase 6: Metrics, Logs, and Uptime Pipelines

### Objectives
- Implement comprehensive metrics collection pipeline
- Set up centralized logging infrastructure
- Configure distributed tracing
- Establish uptime monitoring and alerting
- Create data retention and archival policies

### Tasks

#### 6.1 Implement Metrics Collection Pipeline

##### 6.1.1 Host Metrics (via Netdata)
- [ ] Deploy Netdata agents to monitored systems:
  - Deploy parent Netdata in container (already done)
  - Configure child agents for distributed monitoring
  - Create `scripts/deploy-netdata-agent.sh` for agent installation
- [ ] Configure Netdata collectors:
  - System metrics (CPU, memory, disk, network)
  - Application metrics (if available)
  - Custom collectors for business metrics
- [ ] Set metric collection intervals (typically 1s default)
- [ ] Configure parent-child communication
- [ ] Test metric arrival at Prometheus

##### 6.1.2 Application Metrics (via Prometheus client libraries)
- [ ] Document application instrumentation requirements
- [ ] Create example application with Prometheus client
- [ ] Configure scrape endpoints for applications
- [ ] Implement business metrics:
  - Request counts and latency
  - Error rates by type
  - Resource consumption
  - Custom business KPIs
- [ ] Set appropriate metric retention (disk space dependent)

##### 6.1.3 Container/Orchestration Metrics (if applicable)
- [ ] If using Kubernetes: add Prometheus scraping for k8s metrics
- [ ] If using Docker: configure cAdvisor for container metrics
- [ ] Implement resource monitoring for container hosts
- [ ] Correlate container metrics with application metrics

##### 6.1.4 Third-party SaaS Metrics (optional)
- [ ] Document integration points for external services
- [ ] Create custom exporters if needed
- [ ] Implement metric translation/normalization

#### 6.2 Implement Centralized Logging Pipeline

##### 6.2.1 Configure Log Collection
- [ ] Configure all services to output structured logs (JSON preferred)
- [ ] Create SigNoz ingestion configuration for logs:
  - OpenTelemetry Collector log receivers
  - Log parsing rules
  - Log attribute enrichment
- [ ] Implement log forwarding from containers:
  - Use JSON logging driver for Docker
  - Implement log aggregation (fluentd/fluent-bit)
- [ ] Create `configs/signoz-overrides/log-collection.yml`

##### 6.2.2 Implement Log Processing
- [ ] Create log parsing rules for each service:
  - Prometheus logs
  - Grafana logs
  - Netdata logs
  - SigNoz logs
  - Uptime Kuma logs
  - Application logs
- [ ] Implement log filtering (remove sensitive data)
- [ ] Set up log level-based routing
- [ ] Create log attribute standardization rules
- [ ] Implement log sampling for high-volume applications

##### 6.2.3 Configure Log Storage and Retention
- [ ] Set up ClickHouse storage for SigNoz logs
- [ ] Define retention policies:
  - DEBUG logs: 7 days
  - INFO logs: 30 days
  - WARN logs: 90 days
  - ERROR logs: 1 year
- [ ] Implement log archival to cold storage (optional)
- [ ] Create log backup procedures
- [ ] Monitor storage growth and implement cleanup

#### 6.3 Implement Distributed Tracing Pipeline

##### 6.3.1 Configure Trace Collection
- [ ] Configure OpenTelemetry SDK in applications (or add support)
- [ ] Implement trace samplers:
  - Always sample errors
  - Sample percentage of successful requests
  - Trace certain user IDs/session IDs
- [ ] Create trace context propagation rules
- [ ] Implement trace correlation with logs and metrics
- [ ] Configure span processors and exporters

##### 6.3.2 Configure Trace Storage and Visualization
- [ ] Set up SigNoz trace ingestion
- [ ] Configure ClickHouse trace storage schema
- [ ] Implement trace search and filtering
- [ ] Create service dependency map visualization
- [ ] Set up flame graph visualization for performance analysis
- [ ] Configure trace retention policies

#### 6.4 Configure Comprehensive Metrics Retention

##### 6.4.1 Time Series Database (Prometheus)
- [ ] Calculate disk requirements for metrics:
  - Average metrics per target: 1000-10000
  - Scrape interval: 15s default
  - Retention: 15 days default
  - Space needed: varies by scrape count
- [ ] In `docker-compose.yml` Prometheus service:
  ```yaml
  command:
    - '--storage.tsdb.retention.time=15d'
    - '--storage.tsdb.retention.size=50GB'
  ```
- [ ] Configure remote storage if needed (e.g., Thanos)
- [ ] Implement metrics downsampling for historical requests
- [ ] Set up metrics backup strategy

##### 6.4.2 Long-Term Storage Strategy
- [ ] Plan for metrics beyond Prometheus retention:
  - Use Thanos for cross-cluster metrics
  - Implement remote write to long-term storage
  - Set up metrics archival
- [ ] Document upgrade path for storage (if needed)
- [ ] Implement metrics query strategies for long-term data
- [ ] Set up metrics compaction policies

#### 6.5 Configure Uptime Monitoring Pipeline

##### 6.5.1 Uptime Kuma Configuration
- [ ] Create comprehensive monitor definitions:
  - HTTP endpoints (web services)
  - TCP port monitoring
  - DNS resolution checks
  - ICMP ping checks
  - Keyword checks (page content monitoring)
  - SSL certificate expiry monitoring
- [ ] Set check intervals (typically 60-300s per service)
- [ ] Configure multiple check locations (if available)
- [ ] Implement monitor grouping by application/service
- [ ] Configure status page (public status dashboard)

##### 6.5.2 Uptime Metrics Export
- [ ] Ensure Uptime Kuma metrics export to Prometheus:
  - Uptime percentage
  - Response time
  - Check count
  - Error count
- [ ] Create Prometheus alerts based on uptime metrics
- [ ] Integrate uptime data into dashboards

##### 6.5.3 Uptime Data Correlation
- [ ] Correlate uptime events with metrics changes
- [ ] Correlate uptime events with logs
- [ ] Correlate uptime events with traces
- [ ] Create on-call alerting for availability incidents

#### 6.6 Data Retention and Policy Enforcement

##### 6.6.1 Retention Policies
- [ ] Create `docs/DATA_RETENTION_POLICY.md`:
  - Metrics retention: 15 days default (configurable)
  - Logs retention: 30-90 days by level
  - Traces retention: 30 days
  - Uptime history: 1 year
- [ ] Implement retention enforcement:
  - ClickHouse TTL policies for SigNoz data
  - Prometheus retention settings
  - Uptime Kuma data cleanup
- [ ] Document override procedures for longer retention

##### 6.6.2 Backup and Disaster Recovery
- [ ] Create backup strategy:
  - Metrics snapshot frequency (daily)
  - Logs backup frequency (weekly)
  - Configuration backup (on changes)
  - Dashboard backup (on git push)
- [ ] Implement backup automation via scripts
- [ ] Create restore procedures
- [ ] Test restore procedures quarterly
- [ ] Document backup storage requirements

#### 6.7 Pipeline Validation and Testing

##### 6.7.1 End-to-End Pipeline Testing
- [ ] Create test application that generates:
  - Metrics (custom counters, gauges)
  - Logs (at all levels)
  - Traces (with spans)
  - Performance variations
- [ ] Create `scripts/test-metrics-pipeline.sh`:
  - Verify metrics in Prometheus
  - Validate metric correctness
  - Check metric latency
- [ ] Create `scripts/test-logs-pipeline.sh`:
  - Verify logs in SigNoz
  - Validate log parsing
  - Check log parsing accuracy
- [ ] Create `scripts/test-traces-pipeline.sh`:
  - Verify traces in SigNoz
  - Validate span structure
  - Check span correlation
- [ ] Create `scripts/test-uptime-pipeline.sh`:
  - Verify monitors in Uptime Kuma
  - Test monitor checks
  - Validate metric export

##### 6.7.2 Stress Testing
- [ ] Test pipeline under high load:
  - Metrics: 1000s of metrics per second
  - Logs: 1000s of log lines per second
  - Traces: high request volume
  - Uptime: many simultaneous checks
- [ ] Monitor resource consumption during stress
- [ ] Identify bottlenecks and optimization opportunities
- [ ] Document performance baselines

#### 6.8 Documentation

- [ ] Create comprehensive pipeline documentation:
  - Metrics flow diagram
  - Logs flow diagram
  - Traces flow diagram
  - Uptime flow diagram
- [ ] Document data models and schemas
- [ ] Document query examples for each data type
- [ ] Create troubleshooting guide for each pipeline

### Files to Create or Modify

```
configs/
├── netdata-overrides/
│   └── netdata.conf (collectors configuration)
├── signoz-overrides/
│   ├── otel-collector-config.yml (expanded for logs/traces)
│   ├── log-collection.yml
│   └── trace-sampling.yml
├── uptime-kuma-overrides/
│   └── monitor-definitions.json (or yaml)
└── retention-policies/
    ├── prometheus-retention.yml
    ├── signoz-retention.yml
    └── uptime-retention.yml

scripts/
├── deploy-netdata-agent.sh (new)
├── test-metrics-pipeline.sh (new)
├── test-logs-pipeline.sh (new)
├── test-traces-pipeline.sh (new)
├── test-uptime-pipeline.sh (new)
├── stress-test-pipeline.sh (new)
└── backup-metrics.sh (new)

integration/
├── test-application/ (new)
│   ├── app.py (generates metrics/logs/traces)
│   ├── docker-compose.yml
│   └── requirements.txt

docs/
├── METRICS_PIPELINE.md (new)
├── LOGS_PIPELINE.md (new)
├── TRACES_PIPELINE.md (new)
├── UPTIME_PIPELINE.md (new)
├── DATA_RETENTION_POLICY.md (new)
└── BACKUP_RECOVERY.md (new)
```

### Expected Output
- Complete metrics collection from all sources
- Centralized logging in SigNoz
- Distributed tracing working end-to-end
- Uptime monitoring for all critical services
- Data retention policies enforced
- Pipeline validation and stress tests passing
- Documentation complete and validated
- All pipelines validated with test applications

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **High metrics cardinality** | Implement label dropping rules; use metric relabeling; monitor cardinality; limit label dimensions |
| **Logs not appearing in SigNoz** | Verify OpenTelemetry Collector receiver config; check ClickHouse connectivity; review OTC logs; test with curl |
| **Traces not being sampled** | Review sampler configuration; check trace exporter; verify OTEL SDK integration; test with manual spans |
| **Uptime checks failing** | Verify service accessibility; check firewall rules; review probe logging; implement retry logic |
| **Storage exhaustion** | Monitor disk usage; implement aggressive retention; use storage quotas; set up alerts for disk usage |
| **Slow query performance** | Implement metric downsampling; optimize ClickHouse schema; use appropriate time ranges; add indexes |
| **Data loss during restarts** | Verify volume mounts; check backup processes; test restore procedures; document recovery steps |
| **Pipeline latency too high** | Review batch sizes; check network latency; optimize query performance; implement caching |

### Success Criteria
- [ ] Metrics flowing from all sources into Prometheus
- [ ] Logs ingested and searchable in SigNoz
- [ ] Traces correlating with logs and metrics
- [ ] Uptime data exported to Prometheus
- [ ] All pipeline test scripts passing
- [ ] Stress tests showing acceptable performance
- [ ] Data retention policies enforced correctly
- [ ] Backup and restore procedures functional
- [ ] Historical data accessible and queryable
- [ ] Documentation complete and accurate

---

## Phase 7: Alerting Configuration

### Objectives
- Implement comprehensive alerting rules
- Configure alert routing and notifications
- Set up multi-channel alerting (email, Slack, PagerDuty, etc.)
- Implement alert suppression and deduplication
- Create SLA-aligned alerting

### Tasks

#### 7.1 Define Alert Rules

##### 7.1.1 System Resource Alerts
- [ ] Create alert rules in `configs/prometheus-overrides/alert-rules.yml`:
  - High CPU usage (>80% for 5 minutes)
  - High memory usage (>85% for 5 minutes)
  - Disk space critical (<10% free for 5 minutes)
  - Disk I/O high (>80% utilization)
  - Network interface errors or packet loss
  - High load average

##### 7.1.2 Service Availability Alerts
- [ ] Create service health alerts:
  - Service down (no response for 2 minutes)
  - Service restart (frequent restarts)
  - Service response time degradation (>2x baseline)
  - Service error rate increase (>5% errors)

##### 7.1.3 Monitoring System Alerts
- [ ] Create alerts for monitoring infrastructure:
  - Prometheus scrape failures
  - Prometheus disk space
  - Prometheus high cardinality
  - Grafana availability
  - SigNoz component failures
  - Uptime Kuma collector failures
  - Alertmanager failures

##### 7.1.4 Application-Specific Alerts
- [ ] For each application, create alerts:
  - Application-specific error conditions
  - Business metric thresholds
  - SLA violations
  - Dependency availability issues

##### 7.1.5 Infrastructure Alerts
- [ ] Create infrastructure degradation alerts:
  - Database reachability
  - External API availability
  - DNS resolution failures
  - Certificate expiry warnings

#### 7.2 Configure Alertmanager Routes and Receivers

##### 7.2.1 Create Alertmanager Configuration
- [ ] Create `configs/alertmanager-overrides/alertmanager.yml`:
  ```yaml
  global:
    resolve_timeout: 5m
  route:
    receiver: 'default'
    group_by: ['alertname', 'cluster']
    group_wait: 10s
    group_interval: 10s
    repeat_interval: 12h
    routes:
      - match:
          severity: critical
        receiver: 'critical-alerts'
        continue: true
      - match:
          severity: warning
        receiver: 'warning-alerts'
  receivers:
    - name: 'default'
    - name: 'critical-alerts'
    - name: 'warning-alerts'
  inhibit_rules: []
  ```

##### 7.2.2 Configure Email Notifications
- [ ] Set up email SMTP configuration:
  ```yaml
  receivers:
    - name: 'critical-alerts'
      email_configs:
        - to: 'alerts@company.com'
          from: 'alertmanager@monitoring.local'
          smarthost: 'smtp.company.com:587'
          auth_username: 'alerts@company.com'
          auth_password: '${SMTP_PASSWORD}'
  ```
- [ ] Create email templates for different alert types
- [ ] Test email delivery

##### 7.2.3 Configure Slack Notifications
- [ ] Create Slack webhook integration:
  - Create Slack app and incoming webhook
  - Add webhook URL to `.env`
  - Configure channels per alert severity
  ```yaml
  receivers:
    - name: 'critical-alerts'
      slack_configs:
        - api_url: '${SLACK_WEBHOOK_CRITICAL}'
          channel: '#alerts-critical'
          title: 'Critical Alert'
  ```
- [ ] Test Slack delivery and message formatting
- [ ] Configure threading and grouping (if available)

##### 7.2.4 Configure PagerDuty Integration (optional)
- [ ] Create PagerDuty service and integration key
- [ ] Configure alertmanager for PagerDuty:
  ```yaml
  receivers:
    - name: 'critical-alerts'
      pagerduty_configs:
        - service_key: '${PAGERDUTY_SERVICE_KEY}'
          severity: 'critical'
  ```
- [ ] Test incident creation in PagerDuty

##### 7.2.5 Configure Additional Notification Channels
- [ ] Implement webhooks for custom integrations
- [ ] Configure Telegram notifications (if desired)
- [ ] Configure OpsGenie integration (if used)
- [ ] Document all notification channels

#### 7.3 Implement Alert Routing and Grouping

##### 7.3.1 Design Alerting Strategy
- [ ] Create alert routing matrix:
  - Critical alerts → PagerDuty + Email + Slack
  - Warning alerts → Email + Slack
  - Info alerts → Slack only
  - System alerts → On-call only (if applicable)
- [ ] Define team/on-call mappings
- [ ] Define escalation procedures
- [ ] Document runbooks for each alert type

##### 7.3.2 Set Up Alert Inhibition Rules
- [ ] Prevent cascading alerts:
  ```yaml
  inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'service']
  ```
- [ ] Suppress child service alerts if parent is down
- [ ] Create maintenance silence rules

##### 7.3.3 Implement Alert Grouping
- [ ] Group related alerts:
  ```yaml
  group_by: ['alertname', 'cluster', 'service']
  ```
- [ ] Set appropriate wait times:
  - `group_wait: 10s` (wait before first notification)
  - `group_interval: 10s` (wait before notifying on updates)
  - `repeat_interval: 4h` (repeat every 4 hours)

#### 7.4 Create Alert Remediation Runbooks

##### 7.4.1 Document Alert Runbooks
- [ ] For each alert, create runbook with:
  - What triggered the alert
  - Impact of the condition
  - How to verify the issue
  - How to remediate
  - Escalation procedure
  - Links to relevant dashboards
- [ ] Create `integration/alert-runbooks/`:
  - `high-cpu-usage.md`
  - `disk-space-critical.md`
  - `service-down.md`
  - `etc.md`

##### 7.4.2 Link Runbooks to Alerts
- [ ] Add runbook URL as annotation to alerts:
  ```yaml
  - alert: HighCpuUsage
    annotations:
      runbook_url: 'https://wiki.company.com/runbooks/high-cpu'
  ```
- [ ] Ensure alerts include context in descriptions

#### 7.5 Implement Alert Silencing and Maintenance

##### 7.5.1 Create Maintenance Window Support
- [ ] Implement manual silence procedures:
  - Via Alertmanager CLI
  - Via script: `scripts/silence-alert.sh`
- [ ] Document silence procedures
- [ ] Create maintenance window notification process
- [ ] Test silence and re-alert after maintenance

##### 7.5.2 Implement Automatic Silence Rules
- [ ] Create silence rules for expected downtimes:
  - Scheduled backup windows
  - Maintenance windows
  - Deployment windows
- [ ] Document active silence rules
- [ ] Review silences quarterly

#### 7.6 Set Up Alert Testing and Validation

##### 7.6.1 Create Alert Testing Framework
- [ ] Create `scripts/test-alerts.sh`:
  - Fire test alerts to each channel
  - Verify delivery
  - Validate formatting
  - Check alert properties
- [ ] Implement synthetic alert generation:
  ```bash
  # Example: test critical alert
  curl -X POST http://alertmanager:9093/api/v1/alerts \
    -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]'
  ```

##### 7.6.2 Create Alert Implementation Tests
- [ ] For each alert rule:
  - Create test scenario that triggers alert
  - Verify alert fires correctly
  - Verify metrics are present
  - Verify routing works
- [ ] Create test dashboard showing alert states

##### 7.6.3 Document Alert Validation Procedure
- [ ] Create alert validation checklist
- [ ] Establish alert review schedule
- [ ] Document alert false positive/negative tracking

#### 7.7 Create Alert Dashboard and Monitoring

##### 7.7.1 Create Alert Status Dashboard
- [ ] Create `dashboards/grafana/08-alerts-status.json`:
  - Firing alerts count
  - Silenced alerts count
  - Alert firing rate
  - Alert resolution time (SLA)
  - Notifications sent per channel
  - Alertmanager health status

##### 7.7.2 Monitor Alerting System Health
- [ ] Create alerts for:
  - Alertmanager down
  - Prometheus unable to write alerts
  - Notification delivery failures
  - High alert firing rate (potential runaway condition)

#### 7.8 Create Alerting Documentation

- [ ] Create comprehensive alerting guide:
  - Alert rules overview
  - Alert routing diagram
  - Notification channels
  - Silence procedures
  - Runbook directory
  - Testing procedures
  - Troubleshooting guide

### Files to Create or Modify

```
configs/
├── prometheus-overrides/
│   └── alert-rules.yml (comprehensive rules)
├── alertmanager-overrides/
│   ├── alertmanager.yml (complete configuration)
│   ├── email-template.tmpl
│   ├── slack-template.tmpl
│   └── custom-receiver-config.yml (if needed)

integration/
├── alert-runbooks/
│   ├── high-cpu-usage.md
│   ├── disk-space-critical.md
│   ├── service-down.md
│   ├── database-unreachable.md
│   ├── high-error-rate.md
│   ├── monitoring-system-failure.md
│   └── README.md (runbook index)

scripts/
├── test-alerts.sh (new)
├── silence-alert.sh (new)
├── check-alertmanager-health.sh (new)
├── validate-alert-rules.sh (new)
└── generate-alert-report.sh (new)

dashboards/grafana/
├── 08-alerts-status.json (new)

docs/
├── ALERTING_GUIDE.md (new)
├── ALERT_RUNBOOKS.md (new, index of runbooks)
├── NOTIFICATION_CHANNELS.md (new)
└── ALERT_TESTING.md (new)
```

### Expected Output
- Comprehensive alert rules covering all critical conditions
- Alert routing configured for multiple notification channels
- Email, Slack, and other notifications working correctly
- Alert runbooks documented and linked
- Alert testing framework functional
- Alerting dashboard showing system health
- Team trained on alert response procedures
- Alert false positive/negative rate < 5%

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Alert fatigue from false positives** | Tune alert thresholds through testing; implement grouping; use ambient intelligence baselines |
| **Missed critical alerts** | Test notification channels regularly; implement multi-channel alerting; have fallback escalation |
| **Notification delivery failures** | Test SMTP/Slack connectivity; implement retry logic; monitor notification channel health |
| **Excessive alert suppression** | Review silence rules quarterly; implement silence expiration dates; track silence effectiveness |
| **Unclear alert descriptions** | Use consistent alert naming; include context in descriptions; link to runbooks; test readability |
| **Alert routing misconfiguration** | Test routing with test alerts; review routing rules during change management; document exceptions |
| **Performance impact of alerting** | Monitor Prometheus resource usage; optimize alert rule complexity; implement time ranges for historical queries |

### Success Criteria
- [ ] All alert rules validating without errors
- [ ] Alertmanager loading configuration successfully
- [ ] Test alerts firing and routing correctly to all channels
- [ ] Email delivery working
- [ ] Slack notifications formatted and working
- [ ] Alert runbooks complete and linked
- [ ] Alert testing scripts passing
- [ ] Team trained and acknowledged alert procedures
- [ ] Alert false positive rate acceptable (<5%)
- [ ] Critical alerts reaching on-call within 2 minutes

---

## Phase 8: Testing and Validation

### Objectives
- Validate entire monitoring platform functionality
- Perform system integration testing
- Execute performance and stress testing
- Verify operational procedures
- Publish production readiness checklist

### Tasks

#### 8.1 Functional Testing

##### 8.1.1 Test Monitoring Stack Services
- [ ] Create `scripts/test-stack-services.sh`:
  - Verify all containers running
  - Verify all service ports accessible
  - Verify service health endpoints respond
  - Verify inter-service connectivity
  - Verify volume mounts persistent across restarts

##### 8.1.2 Test Data Collection
- [ ] Deploy test application generating metrics/logs/traces
- [ ] Verify metrics appear in Prometheus:
  - Check target scrape status
  - Query test metrics
  - Verify metrics labeled correctly
- [ ] Verify logs appear in SigNoz:
  - Check log ingestion
  - Verify log parsing
  - Check log search functionality
- [ ] Verify traces appear in SigNoz:
  - Check trace ingestion
  - Verify trace visualization
  - Check service map generation
- [ ] Verify uptime monitoring data:
  - Check monitors in Uptime Kuma
  - Verify metric export
  - Check status page

##### 8.1.3 Test Dashboard Functionality
- [ ] Navigate all dashboards
- [ ] Verify all panels load and display data
- [ ] Test variable selection and filtering
- [ ] Test drill-down navigation
- [ ] Test time range selection
- [ ] Test dashboard refresh
- [ ] Verify dashboard persistence

##### 8.1.4 Test Alert Functionality
- [ ] Trigger test alert conditions:
  - Manually set high metric values
  - Monitor alert firing
  - Verify alert routing
  - Verify notifications sent
- [ ] Test alert suppression/silencing
- [ ] Test alert resolution
- [ ] Verify alert history in Alertmanager

##### 8.1.5 Test Integration Points
- [ ] Verify Netdata → Prometheus flow
- [ ] Verify Uptime Kuma → Prometheus flow
- [ ] Verify OpenTelemetry → SigNoz flow
- [ ] Verify Prometheus → Grafana datasource
- [ ] Verify SigNoz → Grafana datasource
- [ ] Test cross-system correlation (metric ↔ log ↔ trace)

#### 8.2 Integration Testing

##### 8.2.1 Test Complete Monitoring Workflow
- [ ] End-to-end test:
  1. Introduce metric anomaly (e.g., CPU spike)
  2. Verify metric appears in Prometheus
  3. Verify alert fires
  4. Verify notification sent
  5. Verify anomaly visible in dashboard
  6. Verify logs/traces show related issues
  7. Verify Uptime Kuma detects impact
  8. Verify alert runbook accessible

##### 8.2.2 Test Multi-Host Scenarios
- [ ] Deploy test agents to multiple hosts
- [ ] Verify metrics from all hosts
- [ ] Test host-specific dashboards
- [ ] Test infrastructure overview with multiple hosts
- [ ] Verify alerts respect host-specific configuration

##### 8.2.3 Test Service Dependencies
- [ ] Map all service dependencies
- [ ] Simulate service failure
- [ ] Verify dependent service alerts
- [ ] Verify alert cascade/suppression works
- [ ] Verify automation response (if any)

##### 8.2.4 Test Data Correlation
- [ ] Generate known event (e.g., application error)
- [ ] Verify measurement across all systems:
  - Trace shows error span
  - Logs show error message
  - Metrics show error rate increase
  - Dashboard highlights anomaly
- [ ] Verify correlation tools (if available)

#### 8.3 Performance and Stress Testing

##### 8.3.1 Baseline Performance Testing
- [ ] Create `scripts/performance-test.sh`:
  - Measure scrape latency
  - Measure query response time
  - Measure dashboard load time
  - Measure alert firing latency
  - Measure log ingestion latency
  - Measure trace ingestion latency

##### 8.3.2 Load Testing
- [ ] Test Prometheus with high metric volume:
  - Create synthetic metrics (10,000+)
  - Measure scrape performance
  - Monitor Prometheus memory/CPU
  - Verify query performance degrades gracefully
- [ ] Test SigNoz with high log volume:
  - Ingest 1000s of logs/second
  - Monitor ingestion latency
  - Verify search performance
  - Monitor storage usage
- [ ] Test Grafana with multiple concurrent users:
  - Simulate 10+ dashboard viewers
  - Monitor dashboard response time
  - Verify query caching works
  - Monitor resource usage

##### 8.3.3 Stress Testing
- [ ] Push systems to limits:
  - Continuous high metric volume (30+ minutes)
  - Continuous high log volume (30+ minutes)
  - All alerts firing simultaneously
  - Storage at 90%+ capacity
- [ ] Monitor behavior at limits:
  - Check for data loss
  - Verify graceful degradation
  - Monitor resource usage
  - Verify recovery after stress ends

##### 8.3.4 Document Performance Baselines
- [ ] Create `docs/PERFORMANCE_BASELINES.md`:
  - Scrape latency: target <5s
  - Query response time: target <1s
  - Dashboard load time: target <3s
  - Alert firing latency: target <30s
  - Log ingestion latency: target <5s
  - Trace ingestion latency: target <5s

#### 8.4 Operational Procedure Testing

##### 8.4.1 Test Startup Procedures
- [ ] Clean start from docker-compose down:
  - All services start
  - Services start in correct order
  - No missing dependencies
  - All services healthy <2 minutes
- [ ] Test startup with pre-existing volumes
- [ ] Test partial startup (subset of services)

##### 8.4.2 Test Shutdown Procedures
- [ ] Clean shutdown: `docker-compose down`
- [ ] Test shutdown with `--remove-orphans`
- [ ] Verify volume preservation
- [ ] Verify configuration preservation

##### 8.4.3 Test Update Procedures
- [ ] Test submodule update:
  - `git submodule update --remote --recursive`
  - Verify compatibility after update
  - Verify services start with new versions
- [ ] Test service restart:
  - Individual service restart
  - Rolling restart
  - Verify data integrity after restart
- [ ] Test configuration updates:
  - Update docker-compose.yml
  - Verify changes apply
  - Verify backward compatibility

##### 8.4.4 Test Backup and Recovery
- [ ] Create full backup
- [ ] Delete all volumes
- [ ] Restore from backup
- [ ] Verify data integrity after restore
- [ ] Document backup/restore procedures

##### 8.4.5 Test Disaster Recovery
- [ ] Simulate service failure:
  - Kill service container
  - Verify auto-restart (if configured)
  - Verify data integrity
- [ ] Simulate storage failure:
  - Delete volume data
  - Restore from backup
  - Verify recovery time
- [ ] Simulate network failure (if containerized networking tested)

#### 8.5 Security Testing

##### 8.5.1 Test Access Control
- [ ] Verify Grafana authentication required
- [ ] Test Grafana user roles and permissions
- [ ] Verify Prometheus not publicly accessible
- [ ] Verify alertmanager not publicly accessible
- [ ] Test network isolation between services

##### 8.5.2 Test Data Privacy
- [ ] Verify no sensitive data in logs (PII, passwords)
- [ ] Verify encryption in transit (if applicable)
- [ ] Verify encryption at rest (if applicable)
- [ ] Test environment variable handling

##### 8.5.3 Test Configuration Security
- [ ] Verify .env file not committed
- [ ] Verify credentials not in Git history
- [ ] Verify docker-compose.yml doesn't hardcode secrets
- [ ] Review all configuration files for exposed credentials

#### 8.6 Usability Testing

##### 8.6.1 Test User Workflows
- [ ] User scenario 1: View system health
  - Access Grafana
  - Navigate infrastructure dashboard
  - Understand current system state
  - Estimated time: <2 minutes
- [ ] User scenario 2: Investigate alert
  - Receive alert notification
  - Navigate to relevant dashboard
  - Understand root cause
  - Access runbook
  - Estimated time: <5 minutes
- [ ] User scenario 3: Search logs
  - Open SigNoz logs
  - Search for error
  - Filter results
  - Estimated time: <3 minutes
- [ ] User scenario 4: View service dependencies
  - Open service map
  - Understand dependencies
  - Identify bottlenecks

##### 8.6.2 Test Documentation Accuracy
- [ ] Follow README from start
- [ ] Verify accuracy of all steps
- [ ] Check links in documentation
- [ ] Verify API documentation
- [ ] Test troubleshooting guides

##### 8.6.3 Test Runbook Usability
- [ ] Follow each runbook
- [ ] Verify runbook steps work
- [ ] Verify links are correct
- [ ] Time runbook completion

#### 8.7 Monitoring Platform Reliability Testing

##### 8.7.1 Test Monitoring System Self-Monitoring
- [ ] Verify alerting on Prometheus failures
- [ ] Verify alerting on Grafana failures
- [ ] Verify alerting on SigNoz failures
- [ ] Verify alerting on Uptime Kuma failures
- [ ] Verify alerting on Alertmanager failures

##### 8.7.2 Test Data Consistency
- [ ] Generate known event
  - Metrics should show event
  - Logs should show event
  - Traces should show event
  - Timestamps should be consistent
- [ ] Verify data not lost during restarts

##### 8.7.3 Test Monitoring Platform Scaling
- [ ] Add more monitored hosts
- [ ] Verify performance acceptable
- [ ] Verify Prometheus handles cardinality
- [ ] Verify SigNoz handles log volume

#### 8.8 Create Comprehensive Test Report

##### 8.8.1 Test Coverage Report
- [ ] Create test matrix covering all functionality
- [ ] Document test results
- [ ] Identify gaps in testing
- [ ] Plan for additional testing

##### 8.8.2 Known Issues and Limitations
- [ ] Document any identified issues
- [ ] Document workarounds (if any)
- [ ] Plan for future improvements
- [ ] Document version-specific limitations

##### 8.8.3 Performance Report
- [ ] Document performance baselines achieved
- [ ] Identify performance bottlenecks
- [ ] Provide optimization recommendations
- [ ] Document scaling limits

#### 8.9 Create Production Readiness Checklist

Create `docs/PRODUCTION_READINESS_CHECKLIST.md`:

```markdown
# Production Readiness Checklist

## Phase 1: Repository Setup ✓
- [ ] Git repository initialized
- [ ] .gitignore configured
- [ ] docker-compose.yml validates
- [ ] .env.example complete

## Phase 2: Git Submodules ✓
- [ ] All submodules initialized
- [ ] Versions pinned and documented
- [ ] Submodule scripts functional

## Phase 3: Docker Compose ✓
- [ ] All services defined
- [ ] Health checks passing
- [ ] Volumes persistent
- [ ] Network isolated

## Phase 4: Integration ✓
- [ ] Netdata → Prometheus working
- [ ] SigNoz → OpenTelemetry working
- [ ] Uptime Kuma → Prometheus working
- [ ] Data correlation verified

## Phase 5: Grafana Dashboards ✓
- [ ] All datasources connected
- [ ] All dashboards loading
- [ ] Variables functional
- [ ] Drill-down navigation working

## Phase 6: Data Pipelines ✓
- [ ] Metrics pipeline functional
- [ ] Logs pipeline functional
- [ ] Traces pipeline functional
- [ ] Uptime pipeline functional
- [ ] Retention policies enforced

## Phase 7: Alerting ✓
- [ ] Alert rules defined
- [ ] Alertmanager routing working
- [ ] Notifications delivered
- [ ] Runbooks documented
- [ ] Testing framework functional

## Phase 8: Testing & Validation ✓
- [ ] All functional tests passing
- [ ] Integration tests passing
- [ ] Performance baselines acceptable
- [ ] Operational procedures tested
- [ ] Security validation complete
- [ ] Documentation reviewed

## Production Deployment
- [ ] Team trained and acknowledged
- [ ] On-call procedures in place
- [ ] Backup/restore procedures tested
- [ ] Escalation procedures documented
- [ ] Go/no-go decision: ___________
```

#### 8.10 Create Operations Manual

Create `docs/OPERATIONS_MANUAL.md`:
- Daily operational tasks
- Weekly maintenance tasks
- Monthly review procedures
- Troubleshooting flowcharts
- Emergency procedures
- Contact information and escalation

### Files to Create or Modify

```
scripts/
├── test-stack-services.sh (new)
├── test-integration.sh (new)
├── performance-test.sh (new)
├── load-test.sh (new)
├── stress-test.sh (new)
├── test-backup-restore.sh (new)
├── test-user-workflows.sh (new)
└── test-security.sh (new)

docs/
├── TESTING_PLAN.md (new)
├── PERFORMANCE_BASELINES.md (new)
├── PRODUCTION_READINESS_CHECKLIST.md (new)
├── OPERATIONS_MANUAL.md (new)
├── TROUBLESHOOTING_GUIDE.md (new, expanded)
└── KNOWN_ISSUES.md (new)

test/
├── integration/
│   ├── test_metric_flow.sh (new)
│   ├── test_log_flow.sh (new)
│   ├── test_trace_flow.sh (new)
│   └── test_uptime_flow.sh (new)
├── performance/
│   ├── baseline_test.sh (new)
│   ├── load_test.sh (new)
│   └── stress_test.sh (new)
├── security/
│   ├── access_control_test.sh (new)
│   └── data_privacy_test.sh (new)
└── operational/
    ├── startup_test.sh (new)
    ├── shutdown_test.sh (new)
    ├── backup_restore_test.sh (new)
    └── update_test.sh (new)
```

### Expected Output
- All test scripts completed and passing
- Test report documenting results
- Known issues documented
- Performance baselines documented
- Production readiness checklist complete
- Operations manual ready
- Team sign-off for production deployment

### Potential Issues and Solutions

| Issue | Prevention Strategy |
|-------|-------------------|
| **Test environment differs from production** | Use same docker-compose configuration; use same .env structure; deploy to production-like hardware |
| **Performance tests inconclusive** | Run tests multiple times; eliminate variance; document baseline conditions; use load testing tools |
| **Operational procedures unclear** | Document step-by-step procedures; create checklists; practice procedures; gather team feedback |
| **Security vulnerabilities identified** | Address before production; document workarounds if cannot fix immediately; implement mitigations |
| **Documentation gaps** | Have team members follow documentation without author present; collect feedback; iterate |

### Success Criteria
- [ ] All functional tests passing (100%)
- [ ] All integration tests passing (100%)
- [ ] Performance baselines met or exceeded
- [ ] No critical security issues
- [ ] Zero data loss during testing
- [ ] Operational procedures validated
- [ ] Documentation reviewed and approved
- [ ] Team trained and certified
- [ ] Production readiness checklist signed off
- [ ] Go/no-go decision approved by stakeholders

---

## Post-Implementation: Ongoing Operations

### Monitoring and Observability
- Set up monitoring of the monitoring platform itself
- Implement runbook for critical monitoring system failures
- Regular review of alert effectiveness (false positive/negative rates)
- Quarterly capacity planning reviews

### Maintenance and Updates
- Monthly review of update availability for all submodules
- Test updates in staging environment first
- Document breaking changes
- Maintain compatibility matrix
- Schedule maintenance windows

### Team Operations
- Establish on-call rotation
- Monthly retrospectives on incident response
- Quarterly training for new team members
- Annual disaster recovery drills

### Continuous Improvement
- Quarterly review of dashboard effectiveness
- Annual architecture review
- Feedback collection from users
- Performance optimization initiatives

---

## Summary

| Phase | Duration | Deliverables | Team |
|-------|----------|--------------|------|
| 1 | 1 week | Repository structure, Base configs | DevOps |
| 2 | 1 week | Git submodules, Version management | DevOps |
| 3 | 1-2 weeks | Docker Compose orchestration |DevOps |
| 4 | 1 week | Service integration | DevOps + SRE |
| 5 | 1-2 weeks | Grafana dashboards | DevOps + SRE |
| 6 | 1-2 weeks | Data pipelines | DevOps + SRE + App |
| 7 | 1 week | Alerting system | DevOps + SRE |
| 8 | 1-2 weeks | Testing and validation | QA + DevOps + SRE |

**Total: 8 weeks for complete implementation**

Each phase builds on the previous, with minimal risk and regular validation checkpoints. The approach ensures:
- No modifications to upstream projects
- Minimal merge conflicts through submodules
- Incremental value delivery
- Easy version upgrades
- Clear testing and validation throughout


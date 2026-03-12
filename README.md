# Infra Health Monitor

**Infra Health Monitor** is an enterprise-style infrastructure monitoring platform that combines multiple open-source monitoring systems into a unified orchestration stack.
Instead of rewriting or modifying existing monitoring tools, this project integrates them using **Docker Compose, configuration connectors, and unified dashboards**.

The goal is to provide **centralized monitoring for laptops, desktops, and servers** with minimal custom development and maximum stability.

---

# Project Philosophy

This repository **does not merge or modify the source code of upstream monitoring projects**.

Instead, it follows a **stack orchestration approach**:

* Each monitoring system runs independently inside its own container.
* Integration happens through configuration, APIs, and shared dashboards.
* Docker Compose orchestrates the complete monitoring stack.

This approach ensures:

* minimal merge conflicts
* easier upgrades of upstream tools
* faster deployment
* high stability

---

# Integrated Monitoring Stack

The platform integrates the following monitoring systems:

| Tool         | Purpose                     |
| ------------ | --------------------------- |
| Prometheus   | Metrics collection          |
| Grafana      | Visualization dashboards    |
| Alertmanager | Alert routing               |
| Netdata      | Real-time system monitoring |
| SigNoz       | Logs and observability      |
| Uptime Kuma  | Uptime monitoring           |

Grafana acts as the **central monitoring interface**.

---

# Architecture

The monitoring platform uses a layered architecture.

Devices
↓
Monitoring Agents
↓
Metrics Collection
↓
Observability & Logs
↓
Visualization & Alerting

Monitoring flow:

Devices
→ Netdata Agents
→ Prometheus metrics
→ Grafana dashboards

Logs and traces:

Systems
→ OpenTelemetry
→ SigNoz

Uptime monitoring:

Services
→ Uptime Kuma
→ Grafana dashboards

---

# Integration Flow

The systems communicate using the following integrations.

### Metrics Pipeline

Netdata → Prometheus → Grafana

### Observability Pipeline

OpenTelemetry → SigNoz

### Uptime Monitoring

Uptime Kuma → Grafana

Grafana combines all data sources to create a **single monitoring interface**.

---

# Repository Structure

```
infra-health-monitor
│
├── stack
│   ├── dockprom
│   ├── netdata
│   ├── signoz
│   └── uptime-kuma
│
├── integration
│   ├── grafana-datasources
│   ├── prometheus-targets
│   └── api-connectors
│
├── configs
│   ├── prometheus
│   └── alertmanager
│
├── dashboards
│   └── grafana
│
├── scripts
│   ├── install-agents
│   └── remediation
│
└── docker-compose.yml
```

Each upstream monitoring project is isolated to prevent merge conflicts.

---

# Git Submodules Strategy

This repository uses **Git submodules** to include upstream monitoring tools without modifying their source code.

Example commands:

```
git submodule add https://github.com/stefanprodan/dockprom stack/dockprom
git submodule add https://github.com/netdata/netdata stack/netdata
git submodule add https://github.com/louislam/uptime-kuma stack/uptime-kuma
git submodule add https://github.com/SigNoz/signoz stack/signoz
```

Benefits:

* upstream repositories remain untouched
* updates are easy
* minimal merge conflicts

Update all submodules:

```
git submodule update --remote
```

---

# Deployment

The monitoring platform is deployed using **Docker Compose**.

Prerequisites:

* Docker
* Docker Compose

Start the monitoring stack:

```
docker compose up -d
```

Stop the stack:

```
docker compose down
```

This command launches the complete monitoring infrastructure.

---

# Services and Default Ports

| Service      | Purpose              | Default Port |
| ------------ | -------------------- | ------------ |
| Grafana      | dashboards           | 3000         |
| Prometheus   | metrics storage      | 9090         |
| Alertmanager | alert routing        | 9093         |
| Netdata      | real-time monitoring | 19999        |
| Uptime Kuma  | uptime monitoring    | 3001         |
| SigNoz       | logs & observability | 3301         |

If port conflicts occur, update the ports in **docker-compose.yml**.

---

# Monitoring Metrics

The platform collects telemetry from monitored systems.

## System Information

* hostname
* logged-in username
* IP address
* MAC address
* operating system version
* system architecture
* system uptime

## Hardware Health

* CPU usage percentage
* CPU core usage
* CPU temperature
* RAM usage
* disk usage per partition
* disk I/O
* SMART disk health
* battery health (laptops)
* fan speed (if supported)

## Network Monitoring

* internet connectivity status
* network throughput
* packet loss
* latency (ping)
* network interfaces
* DNS configuration

## Security Monitoring

* antivirus status
* firewall status
* disk encryption status
* Windows update status
* pending patches

## Performance Monitoring

* top processes by CPU usage
* top processes by memory usage
* running services
* failed services
* system crash reports
* event log alerts

---

# Alerting

Alert rules are defined in Prometheus and handled by Alertmanager.

Example alerts:

* CPU usage above threshold
* disk usage above threshold
* device offline
* service failure
* website downtime

Notifications can be sent to:

* email
* Slack
* Telegram
* webhooks

---

# Ports Conflict Strategy

If ports conflict with existing services, update the mapping in `docker-compose.yml`.

Example adjustments:

Grafana → 3000
Prometheus → 9090
Uptime Kuma → 3001
Netdata → 19999
SigNoz → 3301

---

# Development Guidelines

Important rules when working with this repository:

* do not modify upstream project source code
* perform integrations through configuration files
* keep monitoring components isolated
* prefer orchestration over rewriting code

This approach ensures long-term maintainability.

---

# Future Enhancements

Planned improvements may include:

* asset inventory management
* endpoint security monitoring
* automated remediation scripts
* anomaly detection using machine learning
* cloud monitoring integration

---

# License

This repository acts as an orchestration layer combining multiple open-source monitoring systems.

Each integrated monitoring component retains its own original license.

# High CPU Usage Runbook

**Alert**: HighCpuUsage

## What triggered the alert
CPU usage has been above 80% for 5 minutes on one or more hosts.

## Impact
Applications may degrade or slow down, autoscaling may trigger, tickets may pile up.

## How to verify
1. Open Grafana dashboard `Host Details` and inspect CPU graphs.
2. SSH into the affected host(s) and run `top` or `htop`.
3. Check `node_cpu_seconds_total` metrics in Prometheus.

## How to remediate
- Identify the process consuming CPU and kill or optimize it.
- Consider increasing instance size if load is legitimate.
- Add CPU autoscaling rules or redistribute workload.

## Escalation
If unable to resolve within 15 minutes or if critical system process is affected,
escalate to the infrastructure team.

## Links
- Grafana host metrics: http://localhost:3000/d/host-details
- Prometheus query: `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100`

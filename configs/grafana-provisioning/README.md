# Grafana Provisioning

This directory contains Grafana provisioning configurations for datasources and dashboards.

## Structure

```
grafana-provisioning/
├── datasources/
│   └── datasources.yaml    # Datasource definitions
└── dashboards/
    ├── provider.yaml       # Dashboard provisioning settings
    └── *.json              # Dashboard JSON files
```

## Datasources (Phase 3)

The `datasources/datasources.yaml` file will define:
- Prometheus datasource
- SigNoz datasource
- Other optional datasources

## Dashboards (Phase 5)

Phase 5 will add:
- Infrastructure overview dashboard
- Host-specific dashboards
- Application performance dashboards
- Alerting and uptime dashboards

## Reference

- Grafana provisioning docs: https://grafana.com/docs/grafana/latest/administration/provisioning/

---
Status: Directory structure in Phase 2
Next: Datasource provisioning in Phase 3, Dashboards in Phase 5

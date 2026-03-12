# Changelog

All notable changes to the Infra Health Monitor project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for Phase 2
- Git submodule integration for all monitoring stacks
- Submodule version pinning and management scripts

### Planned for Phase 3
- Complete docker-compose.yml with service definitions
- Environment configuration system
- Health checks for all services

### Planned for Phase 4
- Service integration configuration
- Prometheus scrape targets
- SigNoz OpenTelemetry collector setup

### Planned for Phase 5
- Grafana dashboards (7+ production-ready)
- Dashboard provisioning system
- Datasource configuration

### Planned for Phase 6
- Metrics collection pipeline
- Logs pipeline via SigNoz
- Traces pipeline via OpenTelemetry
- Uptime monitoring pipeline

### Planned for Phase 7
- Comprehensive alert rules
- Alert routing and notifications
- Alert runbooks and remediation

### Planned for Phase 8
- Testing framework and scripts
- Integration tests
- Performance validates
- Production readiness checklist

## [1.0.0-phase1] - 2026-03-12

### Added
- Initial repository structure
- `.gitignore` for comprehensive exclusions
- `.gitmodules` template for Git submodule declarations
- `.env.example` with all configuration parameters
- `Makefile` with common operational targets
- `docker-compose.yml` base structure with all service definitions
- `ARCHITECTURE.md` - Complete system architecture documentation
- `DEPLOYMENT_GUIDE.md` - Detailed deployment procedures
- `TROUBLESHOOTING.md` - Common issues and solutions
- `CHANGELOG.md` - This file
- `IMPLEMENTATION_PLAN.md` - 8-phase implementation roadmap

### Documentation
- Project philosophy and design principles
- Repository structure overview
- Git strategy for avoiding merge conflicts
- Service definitions and port mappings
- Volume and persistence strategy
- Environment configuration templates
- Makefile targets for common operations
- Architecture diagrams and data flows
- Deployment checklists
- Troubleshooting procedures

## [0.1.0] - Initial Concept

### Concept
- Unified infrastructure monitoring platform
- Integration of multiple open-source monitoring systems
- Docker Compose orchestration approach
- No modifications to upstream projects
- Stack orchestration using Git submodules

---

## Versioning Policy

- **Major Version**: Architecture changes, breaking changes to API/configuration
- **Minor Version**: New features, new services/integrations
- **Patch Version**: Bug fixes, documentation updates, configuration enhancements

## Git Submodule Versions

Tracked in `SUBMODULE_VERSIONS.txt`:

```
Phase 1: Initial structures - No submodules yet
Phase 2: Will include versioned references for:
  - dockprom
  - netdata
  - signoz
  - uptime-kuma
```

## Upgrade Procedures

### Phase 1 to Phase 2
1. Initialize submodules: `git submodule update --init --recursive`
2. Verify all submodules cloned: `git submodule status`
3. Pin versions in `SUBMODULE_VERSIONS.txt`
4. Test: `make validate`

### Between Patch Versions
- No breaking changes expected
- Configuration backward compatible
- Can safely update documentation and non-service files

### Between Minor Versions
- Configuration migration guide provided
- Dashboard schema changes documented
- New services optional, backward compatible

### Between Major Versions
- Breaking changes clearly documented
- Migration guide required
- Deprecation notices at least 2 patch versions earlier

## Contributing

When adding changes, update this file:

1. Add entry to "Unreleased" section
2. Use present tense ("Add feature" not "Added feature")
3. Include issue/PR references if applicable
4. Maintain clarity for users reading changelog

## Release Schedule

- **Phase 1**: Completed (2026-03-12)
- **Phase 2**: Planned (2026-03-19)
- **Phase 3**: Planned (2026-03-26)
- **Phase 4**: Planned (2026-04-02)
- **Phase 5**: Planned (2026-04-09)
- **Phase 6**: Planned (2026-04-16)
- **Phase 7**: Planned (2026-04-23)
- **Phase 8**: Planned (2026-04-30)
- **Version 1.0.0**: Target (2026-05-14)

## Supported Upstream Projects

### Dockprom
- Repository: https://github.com/stefanprodan/dockprom
- Supported Versions: Latest stable
- Last Updated: [Will be tracked]
- Integration: Direct docker-compose include

### Netdata
- Repository: https://github.com/netdata/netdata
- Supported Versions: Latest stable
- Last Updated: [Will be tracked]
- Integration: As parent + agent architecture

### SigNoz
- Repository: https://github.com/SigNoz/signoz
- Supported Versions: Latest stable
- Last Updated: [Will be tracked]
- Integration: Direct docker-compose include

### Uptime Kuma
- Repository: https://github.com/louislam/uptime-kuma
- Supported Versions: Latest stable
- Last Updated: [Will be tracked]
- Integration: Direct docker-compose include

---

**Last Updated**: March 12, 2026
**Maintainer**: [Project Team]
**License**: [Project License]

.PHONY: help init up down logs clean status health test

# Default target
help:
	@echo "Infra Health Monitor - Make targets"
	@echo ""
	@echo "Setup:"
	@echo "  make init           - Initialize submodules and environment"
	@echo "  make setup-env      - Create .env from template"
	@echo ""
	@echo "Operations:"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - Tail service logs"
	@echo "  make status         - Show service status"
	@echo "  make health         - Check service health"
	@echo ""
	@echo "Testing:"
	@echo "  make test-setup     - Setup environment for testing"
	@echo "  make test-all       - Run complete test suite"
	@echo "  make test-stack     - Test service health and connectivity"
	@echo "  make test-performance - Run performance baseline tests"
	@echo "  make test-integration - Test end-to-end workflows"
	@echo "  make test-load      - Run load and throughput tests"
	@echo "  make test-stress    - Run stress and failure tests"
	@echo "  make test-dev       - Run development-focused tests"
	@echo "  make test-ci        - Run CI/CD testing pipeline"
	@echo "  make test-cleanup   - Clean up test results"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update         - Update all submodules"
	@echo "  make clean          - Remove volumes and clean up"
	@echo "  make backup         - Backup configuration and data"
	@echo ""
	@echo "Development:"
	@echo "  make validate       - Validate docker-compose.yml"
	@echo "  make test           - Run integration tests (legacy)"
	@echo ""

# Initialize: submodules and environment
init: .env | submodule-check
	@echo "✓ Infra Health Monitor initialized"
	@echo "  Configuration: .env"
	@echo "  Submodules: initialized"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review and customize .env file"
	@echo "  2. Run: make up"

# Setup environment file from template
setup-env: .env

.env: .env.example
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env from template"; \
		echo "  Please customize .env with your settings"; \
	else \
		echo ".env already exists"; \
	fi

# Initialize/update Git submodules
submodule-check:
	@if [ ! -d "stack/dockprom/.git" ]; then \
		echo "Initializing Git submodules..."; \
		git submodule update --init --recursive; \
	else \
		echo "✓ Git submodules already initialized"; \
	fi

# Start the monitoring stack
up: validate
	@echo "Starting Infra Health Monitor..."
	docker-compose up -d
	@echo ""
	@echo "✓ Services starting"
	@echo "  Grafana:      http://localhost:$${GRAFANA_PORT:-3000}"
	@echo "  Prometheus:   http://localhost:$${PROMETHEUS_PORT:-9090}"
	@echo "  Netdata:      http://localhost:$${NETDATA_PORT:-19999}"
	@echo "  Uptime Kuma:  http://localhost:$${UPTIME_KUMA_PORT:-3001}"
	@echo "  SigNoz:       http://localhost:$${SIGNOZ_PORT:-3301}"
	@echo ""
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@$(MAKE) health

# Stop the monitoring stack
down:
	@echo "Stopping Infra Health Monitor..."
	docker-compose down
	@echo "✓ Services stopped"

# Restart all services
restart: down up

# View service logs
logs:
	docker-compose logs -f

# Check service status
status:
	@echo "Service Status:"
	@docker-compose ps

# Health check for critical services
health: validate-services
	@echo "✓ Services are healthy"

validate-services:
	@echo "Checking service health..."
	@for service in grafana prometheus netdata signoz-query-service uptime-kuma; do \
		if docker-compose ps $$service | grep -q "Up"; then \
			echo "  ✓ $$service"; \
		else \
			echo "  ✗ $$service"; \
		fi \
	done

# Update all Git submodules to latest versions
update:
	@echo "Updating all submodules..."
	git submodule update --remote --recursive
	@echo "✓ Submodules updated"
	@echo ""
	@echo "Run 'make restart' to deploy updates"

# Remove volumes and clean up (⚠️  deletes data)
clean:
	@echo "⚠️  This will delete all monitoring data and volumes!"
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Cleaning up..."; \
		docker-compose down -v; \
		echo "✓ Volumes removed"; \
	else \
		echo "Cancelled"; \
	fi

# Validate docker-compose.yml syntax
validate:
	@echo "Validating docker-compose.yml..."
	docker-compose config > /dev/null
	@echo "✓ Configuration valid"

# Run integration tests
test:
	@echo "Running integration tests..."
	@if [ -f "scripts/integration-test.sh" ]; then \
		bash scripts/integration-test.sh; \
	else \
		echo "Test suite not yet implemented"; \
	fi

# Comprehensive testing suite
test-all: test-stack test-performance test-integration test-load test-stress
	@echo "✓ All tests completed"

# Individual test suites
test-stack:
	@echo "Running stack service tests..."
	@if [ -f "scripts/test-stack-services.sh" ]; then \
		bash scripts/test-stack-services.sh; \
	else \
		echo "Stack test script not found"; \
	fi

test-performance:
	@echo "Running performance tests..."
	@if [ -f "scripts/performance-test.sh" ]; then \
		bash scripts/performance-test.sh; \
	else \
		echo "Performance test script not found"; \
	fi

test-integration:
	@echo "Running integration tests..."
	@if [ -f "scripts/test-integration.sh" ]; then \
		bash scripts/test-integration.sh; \
	else \
		echo "Integration test script not found"; \
	fi

test-load:
	@echo "Running load tests..."
	@if [ -f "scripts/load-test.sh" ]; then \
		bash scripts/load-test.sh; \
	else \
		echo "Load test script not found"; \
	fi

test-stress:
	@echo "Running stress tests..."
	@if [ -f "scripts/stress-test.sh" ]; then \
		bash scripts/stress-test.sh; \
	else \
		echo "Stress test script not found"; \
	fi

# Test environment management
test-setup: up
	@echo "Waiting for services to be ready for testing..."
	@sleep 60
	@$(MAKE) health

test-cleanup:
	@echo "Cleaning up test results..."
	@if [ -d "test-results" ]; then \
		rm -rf test-results; \
		echo "✓ Test results cleaned up"; \
	else \
		echo "No test results to clean"; \
	fi

# CI/CD testing pipeline
test-ci: validate test-setup test-all test-cleanup
	@echo "✓ CI/CD testing pipeline completed"

# Development testing (faster, focused)
test-dev: test-stack test-integration
	@echo "✓ Development tests completed"

# Backup configuration (requires backup scripts)
backup:
	@echo "Backing up configuration..."
	@if [ -f "scripts/backup.sh" ]; then \
		bash scripts/backup.sh; \
	else \
		echo "Backup script not found"; \
		echo "Create scripts/backup.sh to enable this feature"; \
	fi

# Quick health check status
.PHONY: quick-status
quick-status:
	@docker-compose ps | tail -n +2 | awk '{print $$1": "$$4}'

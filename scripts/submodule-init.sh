#!/bin/bash
# scripts/submodule-init.sh
# Initialize all Git submodules for first-time setup
# Usage: ./scripts/submodule-init.sh

set -e

echo "=========================================="
echo "Infra Health Monitor - Git Submodule Init"
echo "=========================================="
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed"
    exit 1
fi

# Initialize submodules
echo "Initializing Git submodules..."
git submodule update --init --recursive

echo ""
echo "Verifying submodule versions..."
echo ""

# Verify each submodule is at expected version
EXPECTED_VERSIONS="SUBMODULE_VERSIONS.txt"

if [ ! -f "$EXPECTED_VERSIONS" ]; then
    echo "⚠️  Warning: $EXPECTED_VERSIONS not found, skipping version verification"
else
    # Read versions from file (skip comments and empty lines)
    cat "$EXPECTED_VERSIONS" | grep -v "^#" | grep -v "^$" | while IFS='=' read -r module version; do
        if [ -z "$module" ] || [ -z "$version" ]; then
            continue
        fi
        
        if [ ! -d "stack/$module" ]; then
            echo "  ⚠️  stack/$module not found"
            continue
        fi
        
        cd "stack/$module"
        current=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
        cd ../..
        
        if [[ "$current" == "$version"* ]]; then
            echo "  ✓ $module: $current"
        else
            echo "  ⚠️  $module: expected $version, got $current"
            echo "      Run: cd stack/$module && git checkout $version && cd ../.."
        fi
    done
fi

echo ""
echo "Submodule status:"
git submodule status

echo ""
echo "✓ Submodule initialization complete"
echo ""
echo "Next steps:"
echo "  1. Review and customize .env file"
echo "  2. Run: docker-compose up -d"
echo "  3. Access dashboards:"
echo "     - Grafana: http://localhost:3000"
echo "     - Prometheus: http://localhost:9090"

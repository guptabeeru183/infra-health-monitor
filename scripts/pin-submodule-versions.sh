#!/bin/bash
# scripts/pin-submodule-versions.sh
# Pin all submodules to versions specified in SUBMODULE_VERSIONS.txt
# Usage: ./scripts/pin-submodule-versions.sh

set -e

VERSIONS_FILE="SUBMODULE_VERSIONS.txt"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "❌ Error: $VERSIONS_FILE not found"
    echo ""
    echo "Create $VERSIONS_FILE with content like:"
    echo "  dockprom=v9.2.0"
    echo "  netdata=v2.9.0"
    echo "  signoz=v0.115.0"
    echo "  uptime-kuma=2.2.1"
    exit 1
fi

echo "=========================================="
echo "Infra Health Monitor - Pin Submodules"
echo "=========================================="
echo ""
echo "Pinning submodules to versions in: $VERSIONS_FILE"
echo ""

failed_pins=()

# Read versions from file (skip comments and empty lines)
cat "$VERSIONS_FILE" | grep -v "^#" | grep -v "^$" | while IFS='=' read -r module version; do
    if [ -z "$module" ] || [ -z "$version" ]; then
        continue
    fi
    
    if [ ! -d "stack/$module" ]; then
        echo "⚠️  stack/$module not found, skipping"
        continue
    fi
    
    echo "Pinning $module to $version..."
    
    cd "stack/$module"
    
    # Fetch from upstream first
    if ! git fetch origin; then
        echo "  ⚠️  Failed to fetch from upstream"
        failed_pins+=("$module")
        cd ../..
        continue
    fi
    
    # Try checking out the version
    if ! git checkout "$version" 2>/dev/null; then
        # Try with tags
        if ! git checkout "tags/$version" 2>/dev/null; then
            echo "  ⚠️  Failed to checkout $version"
            failed_pins+=("$module")
        fi
    fi
    
    current=$(git describe --tags --always)
    echo "  ✓ $module: $current"
    
    cd ../..
done

echo ""
echo "Pinning complete."

if [ ${#failed_pins[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Failed to pin:"
    for module in "${failed_pins[@]}"; do
        echo "  - $module"
    done
else
    echo ""
    echo "✓ All submodules pinned successfully."
    echo ""
    echo "Commit the changes:"
    echo "  git add stack/ .gitmodules"
    echo "  git commit -m \"Pin submodules to versions from SUBMODULE_VERSIONS.txt\""
fi

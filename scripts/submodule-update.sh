#!/bin/bash
# scripts/submodule-update.sh
# Check for and optionally update all Git submodules
# Usage: ./scripts/submodule-update.sh [--apply]

set -e

APPLY_UPDATES=false
if [ "$1" = "--apply" ]; then
    APPLY_UPDATES=true
fi

echo "=========================================="
echo "Infra Health Monitor - Submodule Update"
echo "=========================================="
echo ""

echo "Checking for upstream updates..."
echo ""

changed_count=0
modules_array=()
versions_array=()

for module_path in stack/*/; do
    module=$(basename "$module_path")
    
    cd "$module_path"
    
    # Fetch latest from upstream
    git fetch origin > /dev/null 2>&1
    
    # Get current and latest tags
    current=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
    latest=$(git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null || echo "unknown")
    
    cd ../..
    
    if [ "$current" != "$latest" ] && [ "$latest" != "unknown" ]; then
        echo "✓ Update available: $module"
        echo "    Current: $current"
        echo "    Latest:  $latest"
        modules_array+=("$module")
        versions_array+=("$latest")
        changed_count=$((changed_count + 1))
    else
        echo "✓ $module: up to date ($current)"
    fi
    
    echo ""
done

if [ $changed_count -eq 0 ]; then
    echo "All submodules are up to date!"
    exit 0
fi

echo "$changed_count submodule(s) have updates available."
echo ""

if [ "$APPLY_UPDATES" = true ]; then
    echo "Applying updates..."
    for i in "${!modules_array[@]}"; do
        module="${modules_array[$i]}"
        version="${versions_array[$i]}"
        
        echo "  Updating $module to $version..."
        cd "stack/$module"
        git checkout "$version" > /dev/null 2>&1 || git fetch origin "$version" > /dev/null 2>&1 && git checkout "$version"
        cd ../..
    done
    
    echo ""
    echo "Running tests..."
    if [ -f "Makefile" ]; then
        make validate 2>/dev/null || true
    fi
    
    echo ""
    echo "✓ Updates applied. Please review CHANGELOG and test thoroughly:"
    echo "  1. Review stack compatibility"
    echo "  2. Run: make down && make up"
    echo "  3. Run: make health"
    echo "  4. Run: make test (when available)"
    echo ""
    echo "Then commit changes:"
    echo "  git add .gitmodules stack/"
    echo "  git commit -m \"Upgrade submodules\""
else
    echo "To apply these updates, run:"
    echo "  ./scripts/submodule-update.sh --apply"
    echo ""
    echo "Or manually update specific submodules:"
    for module in "${modules_array[@]}"; do
        echo "  cd stack/$module && git checkout <version> && cd ../.."
    done
fi

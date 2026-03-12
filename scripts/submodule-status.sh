#!/bin/bash
# scripts/submodule-status.sh
# Show detailed status of all Git submodules
# Usage: ./scripts/submodule-status.sh

set -e

echo "=========================================="
echo "Infra Health Monitor - Submodule Status"
echo "=========================================="
echo ""

for module_path in stack/*/; do
    module=$(basename "$module_path")
    
    cd "$module_path"
    
    echo "Module: $module"
    echo "--------"
    
    # Get repository URL
    url=$(git config --get remote.origin.url)
    echo "  URL:       $url"
    
    # Get current branch/tag
    branch=$(git rev-parse --abbrev-ref HEAD)
    echo "  Detached:  $branch"
    
    # Get current commit
    commit=$(git rev-parse --short HEAD)
    echo "  Commit:    $commit"
    
    # Get tags
    tags=$(git describe --tags --always 2>/dev/null || echo "no tags")
    echo "  Tags:      $tags"
    
    # Check for uncommitted changes (should never happen with submodules)
    if [ -n "$(git status --porcelain)" ]; then
        echo "  ⚠️  ALERT: Uncommitted changes detected!"
        git status --short | sed 's/^/     /'
    fi
    
    # Get last upstream fetch time
    if [ -f ".git/refs/remotes/origin/HEAD" ]; then
        last_fetch=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' .git/FETCH_HEAD 2>/dev/null || echo "unknown")
        echo "  Last fetch: $last_fetch"
    fi
    
    echo ""
    
    cd ../..
done

echo "Summary:"
git submodule status
echo ""

echo "To check for updates, run:"
echo "  ./scripts/submodule-update.sh"
echo ""
echo "To initialize/update submodules, run:"
echo "  ./scripts/submodule-init.sh"

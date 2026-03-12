# Git Submodules Strategy

This guide explains how to manage Git submodules in the Infra Health Monitor project, ensuring we can integrate upstream monitoring projects without modifying their source code and with minimal merge conflicts.

## Overview

Infra Health Monitor uses **Git submodules** to include four upstream monitoring projects as read-only dependencies:

1. **dockprom** - Prometheus + Grafana + Alertmanager stack
2. **netdata** - Real-time system monitoring
3. **signoz** - Logs, metrics, and traces observability
4. **uptime-kuma** - Uptime and availability monitoring

This approach provides:
- ✓ No modifications to upstream code
- ✓ Easy updates from upstream
- ✓ Minimal merge conflicts
- ✓ Clear separation of concerns
- ✓ Version control for component versions

## Architecture

```
infra-health-monitor/
├── stack/
│   ├── dockprom/           ← Git submodule
│   ├── netdata/            ← Git submodule
│   ├── signoz/             ← Git submodule
│   └── uptime-kuma/        ← Git submodule
├── configs/                ← Our customizations
│   ├── dockprom-overrides/
│   ├── netdata-overrides/
│   ├── signoz-overrides/
│   └── uptime-kuma-overrides/
├── scripts/                ← Automation
│   ├── submodule-init.sh
│   ├── submodule-update.sh
│   └── ...
└── .gitmodules             ← Submodule declarations
```

## Getting Started

### First Time Clone

To clone the repository with all submodules initialized:

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/your-org/infra-health-monitor.git
cd infra-health-monitor

# Or if already cloned, initialize submodules
git submodule update --init --recursive
```

### Check Submodule Status

```bash
# View all submodules
git config --file .gitmodules --get-regexp path

# Status of each submodule
git submodule status

# Output example:
# a1b2c3d4 stack/dockprom (v1.5.0)
# e5f6a7b8 stack/netdata (v1.45.0)
# c9d0e1f2 stack/signoz (v0.20.0)
# 3a4b5c6d stack/uptime-kuma (v1.20.0)
```

## Managing Submodules

### Adding Configuration to Submodule Directories

Since we don't modify submodule code, all customizations go in `configs/` directory:

```bash
# Instead of modifying stack/dockprom/prometheus/prometheus.yml
# Create configs/dockprom-overrides/prometheus.yml

# In docker-compose.yml, reference our override:
volumes:
  - ./stack/dockprom/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
  - ./configs/dockprom-overrides/additional-config.yml:/etc/prometheus/extra.yml:ro
```

### Updating a Single Submodule

```bash
# Navigate to submodule
cd stack/dockprom

# Fetch latest from upstream
git fetch origin

# Check available versions
git tag | tail -20

# Switch to specific version
git checkout v1.6.0

# Return to repo root
cd ../..

# Stage the change
git add stack/dockprom

# Commit
git commit -m "Update dockprom to v1.6.0"
```

### Updating All Submodules

```bash
# Update all submodules to latest remote version
git submodule update --remote --recursive

# Review changes
git status

# If satisfied with updates:
git add .gitmodules stack/
git commit -m "Update all submodules to latest remote versions"
```

### Pinning to Specific Versions

Create `SUBMODULE_VERSIONS.txt` to track pinned versions:

```
# Submodule Version Pinning
# Format: submodule_name=version
# Last Updated: 2026-03-12

dockprom=v1.5.0
netdata=v1.45.0
signoz=v0.20.0
uptime-kuma=v1.20.0

# Version pinning ensures all team members use same components
# Update script: scripts/pin-submodule-versions.sh
```

### Version Pinning Script

Create `scripts/pin-submodule-versions.sh`:

```bash
#!/bin/bash
# Pin all submodules to specific versions

VERSIONS_FILE="SUBMODULE_VERSIONS.txt"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: $VERSIONS_FILE not found"
    exit 1
fi

while IFS='=' read -r module version; do
    # Skip comments and empty lines
    [[ "$module" =~ ^#.*$ ]] && continue
    [[ -z "$module" ]] && continue
    
    echo "Pinning $module to $version..."
    cd "stack/$module"
    git checkout "$version" || git fetch origin && git checkout "$version"
    cd ../..
done < "$VERSIONS_FILE"

git add stack/
git commit -m "Pin submodules to versions from $VERSIONS_FILE"
echo "✓ All submodules pinned"
```

## Sync Upstream with Local

### Scenario 1: Upstream Branch Changed

```bash
# Inside submodule
cd stack/dockprom

# Fetch latest
git fetch origin

# Check what changed
git log --oneline main..origin/main

# Merge upstream changes
git merge origin/main

# Or rebase on main
git rebase origin/main

cd ../..
git add stack/dockprom
git commit -m "Sync dockprom with upstream main"
```

### Scenario 2: Upgrade to Latest Release

```bash
# Check available releases
cd stack/dockprom
git fetch --tags origin
git tag | sort -V | tail -5

# Switch to latest release
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))

# Or specific version
git checkout v1.6.0

cd ../..
git add stack/dockprom
git commit -m "Upgrade dockprom to v1.6.0"

# Update SUBMODULE_VERSIONS.txt
echo "dockprom=v1.6.0" >> SUBMODULE_VERSIONS.txt
git add SUBMODULE_VERSIONS.txt
git commit -m "Update version tracking"
```

## Avoiding Common Pitfalls

### ⚠️ Prevent Detached HEAD State

Submodules check out at specific commits (not branches). Always check before modifying:

```bash
cd stack/dockprom
git status

# Output: HEAD detached at a1b2c3d4
# This is expected for submodules!

# If you accidentally create new commits:
git checkout v1.5.0  # Return to tagged version
```

### ⚠️ Don't Commit Submodule Code Changes

If you modify a submodule file, don't commit it:

```bash
# DON'T do this:
cd stack/dockprom
# Edit prometheus.yml
git commit -m "Fix prometheus config"  # ❌ This modifies upstream!

# DO this instead:
cd ../..
# Create copy in configs/
cp configs/dockprom-overrides/prometheus.yml prometheus-override.yml
# Update docker-compose.yml to use override
```

### ⚠️ Skip Submodule Updates in Feature Branches

To avoid merge conflicts when working on platform code (not submodules):

```bash
# Clone without submodules for feature work (faster)
git clone --no-recurse-submodules <repo>

# Or configure to skip submodule fetch
git config --global status.submoduleSummary true

# In feature branch, don't change submodule commits
# Only modify configs/, scripts/, documentation
```

## Automation Scripts

### scripts/submodule-init.sh

```bash
#!/bin/bash
# Initialize all submodules for new team members

echo "Initializing Git submodules..."
git submodule update --init --recursive

echo "Verifying submodule versions..."
cat SUBMODULE_VERSIONS.txt | grep -v "^#" | grep -v "^$" | while IFS='=' read -r module version; do
    cd "stack/$module"
    current=$(git describe --tags --always)
    if [ "$current" = "$version" ]; then
        echo "  ✓ $module: $current"
    else
        echo "  ⚠ $module: expected $version, got $current"
    fi
    cd ../..
done

echo "✓ Submodules initialized"
```

### scripts/submodule-status.sh

```bash
#!/bin/bash
# Show detailed status of all submodules

echo "Submodule Status:"
echo "================"
echo ""

for module_path in stack/*/; do
    module=$(basename "$module_path")
    cd "$module_path"
    
    echo "$module:"
    echo "  URL: $(git config --get remote.origin.url)"
    echo "  Branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "  Commit: $(git rev-parse --short HEAD)"
    echo "  Tags: $(git describe --tags --always)"
    
    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "  ⚠ Uncommitted changes detected"
    fi
    
    cd ../..
    echo ""
done
```

### scripts/submodule-update.sh

```bash
#!/bin/bash
# Safely update all submodules

echo "Checking for upstream updates..."
echo ""

changed=0

for module_path in stack/*/; do
    module=$(basename "$module_path")
    cd "$module_path"
    
    git fetch origin
    latest=$(git describe --tags $(git rev-list --tags --max-count=1))
    current=$(git describe --tags --always)
    
    if [ "$current" != "$latest" ]; then
        echo "✓ Update available for $module: $current → $latest"
        changed=$((changed + 1))
    else
        echo "✓ $module: up to date ($current)"
    fi
    
    cd ../..
done

echo ""
if [ $changed -eq 0 ]; then
    echo "All submodules are up to date."
else
    echo "Run 'git submodule update --remote' to pull updates"
fi
```

## Best Practices

### 1. Regular Upstream Monitoring

```bash
# Weekly: Check for updates
scripts/submodule-status.sh

# Monthly: Pull and test major updates
git submodule update --remote --recursive
make test
```

### 2. Version Pinning Strategy

- **Development**: Latest tags (test bleeding edge)
- **Staging**: One version behind latest (safety margin)
- **Production**: Tagged stable versions (no auto-updates)

### 3. Update Testing

```bash
# Test in feature branch first
git checkout -b Update/submodule-versions
git submodule update --remote
make down
docker system prune -a  # Clean old images
make up
make health
make test              # Run integration tests
# If all pass:
git commit -am "Update submodules"
git push origin Update/submodule-versions
# Then PR and merge
```

### 4. Conflict Resolution

If merge conflicts occur with `.gitmodules`:

```bash
# View conflict
cat .gitmodules

# Typically, keep ours (local) if just version differences
git checkout --ours .gitmodules
git add .gitmodules

# For complex conflicts, manually merge both versions
```

## Troubleshooting

### Submodule Clone Failed

```bash
# Retry initialization
git submodule update --init --recursive --depth=1

# Or with timeout handling
timeout 600 git submodule update --init --recursive
```

### Submodule at Wrong Version

```bash
# Reset to version in SUBMODULE_VERSIONS.txt
cd stack/submodule_name
git fetch origin
git checkout $(grep "submodule_name=" ../../SUBMODULE_VERSIONS.txt | cut -d= -f2)
cd ../..
```

### Detached HEAD in Submodule

```bash
# This is normal! Submodules are always detached to specific commits
# To update to latest tag:
cd stack/submodule_name
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
cd ../..
```

## Workflow Summary

| Task | Command |
|------|---------|
| Clone with submodules | `git clone --recurse-submodules <repo>` |
| Initialize submodules | `git submodule update --init --recursive` |
| Check status | `git submodule status` |
| Update all to latest | `git submodule update --remote --recursive` |
| Update one submodule | `cd stack/<module> && git checkout v1.x.x && cd ../..` |
| Check for updates | `scripts/submodule-status.sh` |
| Pin versions | `scripts/pin-submodule-versions.sh` |

## External Resources

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Managing Submodules Guide](https://git-scm.com/docs/git-submodule)
- [Submodule Best Practices](https://github.blog/2016-02-01-working-with-submodules/)

---

**Last Updated**: March 2026
**Submodule Strategy Version**: 1.0

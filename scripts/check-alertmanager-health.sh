#!/bin/bash
# check-alertmanager-health.sh
# ============================
# Simple check that Alertmanager is reachable and has loaded its configuration

set -e

AM_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

if curl -s -f "$AM_URL/-/healthy" > /dev/null; then
    echo "Alertmanager is healthy"
else
    echo "Alertmanager not reachable or unhealthy" >&2
    exit 1
fi

echo "Fetching loaded config..."
curl -s "$AM_URL/api/v2/status" | jq .config

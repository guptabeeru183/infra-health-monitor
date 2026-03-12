#!/bin/bash
# validate-alert-rules.sh
# =======================
# Validate Prometheus alert rule syntax using promtool (inside container if available)

set -e

RULE_FILE="${1:-/etc/prometheus/alert-rules.yml}"

if command -v promtool &> /dev/null; then
    echo "Using local promtool to check $RULE_FILE"
    promtool check rules "$RULE_FILE"
else
    echo "promtool not found locally, attempting docker run"  
    docker run --rm -v "$PWD/configs/prometheus-overrides":/etc/prometheus prom/prometheus:v2.44.0 promtool check rules "$RULE_FILE"
fi

#!/bin/bash
# test-alerts.sh
# ==============
# Send synthetic alerts to Alertmanager and verify delivery to configured channels
# Requires Alertmanager running locally (or URL via ALERTMANAGER_URL)

set -e

ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

echo "Firing test critical alert..."
curl -s -X POST "$ALERTMANAGER_URL/api/v1/alerts" \
    -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]' \
    | jq .

echo "Firing test warning alert..."
curl -s -X POST "$ALERTMANAGER_URL/api/v1/alerts" \
    -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]' \
    | jq .

echo "Alerts sent. Check your notification channels for delivery."

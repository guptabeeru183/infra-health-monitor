#!/bin/bash
# generate-alert-report.sh
# =========================
# Query Alertmanager for current alerts and output a simple report

set -e

AM_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

echo "Fetching active alerts..."
alerts=$(curl -s "$AM_URL/api/v2/alerts")

echo "$alerts" | jq -r '.[] | "- [\(.labels.severity)] \(.labels.alertname): \(.annotations.summary) (starts at \(.startsAt))"'

echo "Total: $(echo "$alerts" | jq length) alerts"

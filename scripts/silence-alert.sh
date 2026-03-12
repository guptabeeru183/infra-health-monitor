#!/bin/bash
# silence-alert.sh
# =================
# Create or remove silences via Alertmanager API
# Usage: ./silence-alert.sh <create|delete> [options]

set -e

AM_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

function create_silence() {
    read -p "Alertname to silence: " name
    read -p "Duration (e.g. 1h): " dur
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ends=$(date -u -d "+$dur" +%Y-%m-%dT%H:%M:%SZ)
    payload=$(cat <<EOF
{
  "matchers": [
    {"name": "alertname", "value": "$name", "isRegex": false}
  ],
  "startsAt": "$now",
  "endsAt": "$ends",
  "createdBy": "${USER:-script}",
  "comment": "Silenced via script"
}
EOF
)
    curl -s -X POST "$AM_URL/api/v2/silences" -d "$payload" | jq .
}

function delete_silence() {
    read -p "Silence ID to delete: " id
    curl -s -X DELETE "$AM_URL/api/v2/silence/$id" | jq .
}

case "$1" in
  create)
    create_silence
    ;;
  delete)
    delete_silence
    ;;
  *)
    echo "Usage: $0 {create|delete}"
    exit 1
    ;;
esac

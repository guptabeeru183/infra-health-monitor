#!/bin/bash
# manage-uptime-monitors.sh
# =========================
# Simple helper for importing and listing monitors in Uptime Kuma via its API.
# Requires UPTIME_KUMA_URL and API_KEY environment variables.

set -e

API_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"/api
API_KEY="${API_KEY:-}"

if [ -z "$API_KEY" ]; then
    echo "Error: set UPTIME_KUMA_URL and API_KEY environment variables"
    exit 1
fi

function list_monitors() {
    curl -s -H "Authorization: Bearer $API_KEY" "$API_URL/monitor" | jq .
}

function import_monitors() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: $0 import <file>"
        exit 1
    fi
    curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        --data-binary "@$file" \
        "$API_URL/monitor/import" | jq .
}

case "$1" in
    list)
        list_monitors
        ;;
    import)
        import_monitors "$2"
        ;;
    *)
        echo "Usage: $0 {list|import <file>}"
        exit 1
        ;;
esac

#!/bin/bash
# send-sample-telemetry.sh
# =========================
# Sends a small set of sample logs and traces to the OpenTelemetry Collector
# so that the logging and tracing pipelines can be exercised during tests.
#
# Usage: ./scripts/send-sample-telemetry.sh [<collector_url>]
# Collector default: http://localhost:4318

set -e

COLLECTOR_URL="${1:-http://localhost:4318}"

log() { echo "[telemetry] $*"; }

# minimal trace payload in OTLP JSON format
send_trace() {
    log "sending test trace to $COLLECTOR_URL/v1/traces"
    curl -s -X POST "$COLLECTOR_URL/v1/traces" \
        -H "Content-Type: application/json" \
        -d '{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "telemetry-test"}}
        ]
      },
      "instrumentationLibrarySpans": [
        {
          "instrumentationLibrary": {"name": "testlib", "version": "0.1.0"},
          "spans": [
            {
              "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
              "spanId": "00f067aa0ba902b7",
              "name": "test-span",
              "kind": "SPAN_KIND_INTERNAL",
              "startTimeUnixNano": "1638465721000000000",
              "endTimeUnixNano": "1638465722000000000"
            }
          ]
        }
      ]
    }
  ]
}'
    log "trace sent"
}

send_log() {
    log "sending test log to $COLLECTOR_URL/v1/logs"
    curl -s -X POST "$COLLECTOR_URL/v1/logs" \
        -H "Content-Type: application/json" \
        -d '{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "telemetry-test"}}
        ]
      },
      "instrumentationLibraryLogs": [
        {
          "instrumentationLibrary": {"name": "testlib", "version": "0.1.0"},
          "logs": [
            {
              "timeUnixNano": "1638465721000000000",
              "severityText": "INFO",
              "body": {"stringValue": "sample log entry"}
            }
          ]
        }
      ]
    }
  ]
}'
    log "log sent"
}

send_trace
send_log

log "sample telemetry transmission complete"
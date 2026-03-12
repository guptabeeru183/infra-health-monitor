# Disk Space Critical Runbook

**Alert**: DiskSpaceCritical

## What triggered the alert
A filesystem has less than 5% free space for over 2 minutes.

## Impact
Services may fail, databases could corrupt, new logs cannot be written.

## How to verify
- Grafana `Host Details` dashboard -> disk usage panel.
- SSH to host and run `df -h`.
- Prometheus query: `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.05`.

## How to remediate
- Clean up old log files, rotate or archive data.
- Increase disk size or attach additional volumes.
- Investigate runaway processes producing large files.

## Escalation
Notify storage team if additional provisioning is required.

## Links
- Host details dashboard

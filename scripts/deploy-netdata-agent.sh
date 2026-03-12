#!/bin/bash
# Deploy Netdata child agent to remote host
# Usage: ./deploy-netdata-agent.sh <host> [ssh-user]

set -e

HOST="$1"
USER="${2:-root}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <host> [ssh-user]"
  exit 1
fi

echo "Deploying Netdata child agent to $HOST as $USER"

ssh ${USER}@${HOST} bash -s <<'EOF'
set -e

# install prerequisites
if ! command -v curl >/dev/null; then
  apk add --no-cache curl || apt-get update && apt-get install -y curl
fi

# install Netdata child
bash <(curl -s https://my-netdata.io/kickstart.sh) --dont-wait --disable-telemetry \
  --child -> /etc/netdata/netdata.conf

# configure stream to parent
cat <<CONFIG >/etc/netdata/stream.conf
[stream]
    enabled = yes
    destination = PARENT_HOST:19999
    api key = YOUR_API_KEY_HERE
CONFIG

systemctl enable --now netdata || true

EOF

echo "Netdata agent deployed to $HOST"

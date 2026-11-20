#!/usr/bin/env bash
# Runs as a Compute Engine VM startup script after the public GitHub repository exists.
set -euo pipefail
exec > >(tee -a /var/log/hw8-bootstrap.log) 2>&1
md() { curl -fsS -H 'Metadata-Flavor: Google' "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1"; }
REPO_URL="$(md hw8-repo-url)"
PROJECT_ID="$(md hw8-project)"
BUCKET="$(md hw8-bucket)"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 python3-venv curl
mkdir -p /opt/hw8
curl -fsSL "$REPO_URL/server.py" -o /opt/hw8/server.py
curl -fsSL "$REPO_URL/requirements.txt" -o /opt/hw8/requirements.txt
python3 -m venv /opt/hw8/venv
/opt/hw8/venv/bin/pip install --disable-pip-version-check -r /opt/hw8/requirements.txt
cat >/etc/systemd/system/hw8.service <<EOF
[Unit]
Description=CS528 HW8 Python HTTP Server
After=network-online.target
Wants=network-online.target
[Service]
WorkingDirectory=/opt/hw8
Environment=PROJECT_ID=$PROJECT_ID
Environment=BUCKET=$BUCKET
Environment=TOPIC=hw4-forbidden
Environment=PORT=8080
ExecStart=/opt/hw8/venv/bin/python /opt/hw8/server.py
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now hw8
# First launch can take a few seconds to initialize cloud API clients.
for i in {1..30}; do
 if curl -fsS http://127.0.0.1:8080/health; then exit 0; fi
 sleep 2
done
journalctl -u hw8 -n 40 --no-pager
exit 1

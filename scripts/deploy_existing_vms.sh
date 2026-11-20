#!/usr/bin/env bash
# Redeploy to already-provisioned, configured HW8 VMs without creating/deleting them.
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-directed-fabric-508221-d2}"
gcloud config set project "$PROJECT_ID"
for vm_zone in 'hw8-server-1 us-central1-a' 'hw8-server-2 us-central1-b'; do
 read -r vm zone <<< "$vm_zone"
 gcloud compute scp server.py "$vm:/tmp/hw8-server.py" --zone="$zone"
 gcloud compute ssh "$vm" --zone="$zone" --command="sudo install -m 0644 /tmp/hw8-server.py /opt/hw8/server.py && sudo systemctl restart hw8 && sleep 4 && curl -fsSi http://127.0.0.1:8080/health"
done

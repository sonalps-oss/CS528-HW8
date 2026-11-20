#!/usr/bin/env bash
# Removes resources specifically created for HW8. Does not delete shared HW4 bucket/topic.
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-directed-fabric-508221-d2}"
REGION="${REGION:-us-central1}"
ZONE1="${ZONE1:-us-central1-a}"
ZONE2="${ZONE2:-us-central1-b}"
BUCKET="${BUCKET:-sonal-graph-2026-sps}"
SA="hw8-server@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud config set project "$PROJECT_ID"
echo 'WARNING: This deletes the two HW8 VMs and their default boot disks, plus HW8 load-balancing resources.'
read -r -p 'Type DELETE-HW8 to continue: ' confirm
[[ "$confirm" == 'DELETE-HW8' ]] || { echo 'Cancelled'; exit 1; }
if gcloud compute forwarding-rules describe hw8-forwarding --region="$REGION" >/dev/null 2>&1; then
 gcloud compute forwarding-rules delete hw8-forwarding --region="$REGION" --quiet
fi
if gcloud compute target-pools describe hw8-pool --region="$REGION" >/dev/null 2>&1; then
 gcloud compute target-pools delete hw8-pool --region="$REGION" --quiet
fi
if gcloud compute http-health-checks describe hw8-health >/dev/null 2>&1; then
 gcloud compute http-health-checks delete hw8-health --quiet
fi
if gcloud compute addresses describe hw8-lb-ip --region="$REGION" >/dev/null 2>&1; then
 gcloud compute addresses delete hw8-lb-ip --region="$REGION" --quiet
fi
for vm_zone in "hw8-server-1 $ZONE1" "hw8-server-2 $ZONE2"; do
 read -r vm zone <<<"$vm_zone"
 if gcloud compute instances describe "$vm" --zone="$zone" >/dev/null 2>&1; then
  gcloud compute instances delete "$vm" --zone="$zone" --quiet
 fi
done
for fw in hw8-allow-health hw8-allow-http; do
 if gcloud compute firewall-rules describe "$fw" >/dev/null 2>&1; then
  gcloud compute firewall-rules delete "$fw" --quiet
 fi
done
if gcloud iam service-accounts describe "$SA" >/dev/null 2>&1; then
 # IAM references can be removed first to avoid dangling bindings.
 gcloud projects remove-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role=roles/logging.logWriter --quiet >/dev/null || true
 gcloud storage buckets remove-iam-policy-binding "gs://$BUCKET" --member="serviceAccount:$SA" --role=roles/storage.objectViewer >/dev/null || true
 if gcloud pubsub topics describe hw4-forbidden >/dev/null 2>&1; then
  gcloud pubsub topics remove-iam-policy-binding hw4-forbidden --member="serviceAccount:$SA" --role=roles/pubsub.publisher >/dev/null || true
 fi
 gcloud iam service-accounts delete "$SA" --quiet
fi
echo 'HW8 resource cleanup requested. Verify with: gcloud compute instances list --filter="name~hw8"'

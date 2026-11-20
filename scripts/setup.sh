#!/usr/bin/env bash
# Recreates the HW8 experiment from scratch. Run from the repository root in Cloud Shell.
# Requires a PUBLIC GitHub repository containing this code and owner permissions in GCP.
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-directed-fabric-508221-d2}"
REGION="${REGION:-us-central1}"
ZONE1="${ZONE1:-us-central1-a}"
ZONE2="${ZONE2:-us-central1-b}"
BUCKET="${BUCKET:-sonal-graph-2026-sps}"
REPO="${REPO:-sonalps-oss/CS528-HW8}"
REPO_URL="https://raw.githubusercontent.com/${REPO}/main"
SA="hw8-server@${PROJECT_ID}.iam.gserviceaccount.com"
# Refuse to deploy if expected files are not published yet.
curl -fsSL "${REPO_URL}/server.py" -o /dev/null
curl -fsSL "${REPO_URL}/requirements.txt" -o /dev/null
gcloud config set project "$PROJECT_ID"
gcloud services enable compute.googleapis.com iam.googleapis.com storage.googleapis.com logging.googleapis.com pubsub.googleapis.com
if ! gcloud iam service-accounts describe "$SA" >/dev/null 2>&1; then
 gcloud iam service-accounts create hw8-server --display-name='CS528 HW8 HTTP Server'
fi
# Project-level logging writer and bucket-scoped read-only access.
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role=roles/logging.logWriter --quiet >/dev/null
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" --member="serviceAccount:$SA" --role=roles/storage.objectViewer >/dev/null
# The HW4 server retains its existing forbidden-country publishing behavior.
if gcloud pubsub topics describe hw4-forbidden >/dev/null 2>&1; then
 gcloud pubsub topics add-iam-policy-binding hw4-forbidden --member="serviceAccount:$SA" --role=roles/pubsub.publisher >/dev/null
else
 echo 'ERROR: existing HW4 Pub/Sub topic hw4-forbidden is required.' >&2; exit 1
fi
for vm_zone in "hw8-server-1 $ZONE1" "hw8-server-2 $ZONE2"; do
 read -r VM ZONE <<<"$vm_zone"
 if gcloud compute instances describe "$VM" --zone="$ZONE" >/dev/null 2>&1; then
  echo "Existing VM $VM found; will not overwrite its configuration."
 else
  gcloud compute instances create "$VM" \
   --zone="$ZONE" --machine-type=e2-small --image-family=debian-12 --image-project=debian-cloud \
   --boot-disk-size=10GB --network=default --tags=hw8-backend \
   --service-account="$SA" --scopes=cloud-platform \
   --metadata="hw8-project=$PROJECT_ID,hw8-bucket=$BUCKET,hw8-repo-url=$REPO_URL" \
   --metadata-from-file=startup-script=scripts/bootstrap.sh
 fi
done
if ! gcloud compute firewall-rules describe hw8-allow-health >/dev/null 2>&1; then
 gcloud compute firewall-rules create hw8-allow-health --network=default --direction=INGRESS \
  --action=ALLOW --rules=tcp:8080 --source-ranges=35.191.0.0/16,130.211.0.0/22 --target-tags=hw8-backend
fi
if ! gcloud compute firewall-rules describe hw8-allow-http >/dev/null 2>&1; then
 # For the external passthrough LB, backend ingress must allow actual client source addresses.
 # This lab uses the internet as client source; restrict to known client ranges where possible.
 gcloud compute firewall-rules create hw8-allow-http --network=default --direction=INGRESS \
  --action=ALLOW --rules=tcp:8080 --source-ranges=0.0.0.0/0 --target-tags=hw8-backend
fi
if ! gcloud compute http-health-checks describe hw8-health >/dev/null 2>&1; then
 gcloud compute http-health-checks create hw8-health --port=8080 --request-path=/health \
  --check-interval=5s --timeout=3s --healthy-threshold=2 --unhealthy-threshold=2
fi
if ! gcloud compute target-pools describe hw8-pool --region="$REGION" >/dev/null 2>&1; then
 gcloud compute target-pools create hw8-pool --region="$REGION" --http-health-check=hw8-health
fi
# add-instances is idempotent for this purpose: it ensures each backend is a member.
gcloud compute target-pools add-instances hw8-pool --instances=hw8-server-1 --instances-zone="$ZONE1" --region="$REGION"
gcloud compute target-pools add-instances hw8-pool --instances=hw8-server-2 --instances-zone="$ZONE2" --region="$REGION"
if ! gcloud compute addresses describe hw8-lb-ip --region="$REGION" >/dev/null 2>&1; then
 gcloud compute addresses create hw8-lb-ip --region="$REGION"
fi
if ! gcloud compute forwarding-rules describe hw8-forwarding --region="$REGION" >/dev/null 2>&1; then
 gcloud compute forwarding-rules create hw8-forwarding --region="$REGION" --ports=8080 \
  --address=hw8-lb-ip --target-pool=hw8-pool
fi
LB_IP="$(gcloud compute addresses describe hw8-lb-ip --region="$REGION" --format='value(address)')"
echo "Load balancer: http://${LB_IP}:8080/health"
echo 'Health state may take time to transition to HEALTHY after bootstrap.'
gcloud compute target-pools get-health hw8-pool --region="$REGION" --format=json

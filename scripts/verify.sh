#!/usr/bin/env bash
set -euo pipefail
REGION="${REGION:-us-central1}"
echo '=== VMs ==='
gcloud compute instances list --filter='name~hw8-server'
echo '=== LB target pool ==='
gcloud compute target-pools describe hw8-pool --region="$REGION"
echo '=== LB backend health ==='
gcloud compute target-pools get-health hw8-pool --region="$REGION" --format=json
echo '=== Forwarding rule ==='
gcloud compute forwarding-rules describe hw8-forwarding --region="$REGION"
LB_IP="$(gcloud compute addresses describe hw8-lb-ip --region="$REGION" --format='value(address)')"
echo "=== GET http://${LB_IP}:8080/health ==="
curl --noproxy '*' -i --max-time 10 "http://${LB_IP}:8080/health"

#!/usr/bin/env bash
set -euo pipefail

[[ -f k8s/02-secrets.yaml ]] || { echo "FATAL: k8s/02-secrets.yaml manquant. Lance scripts/gen-secrets.sh"; exit 1; }
[[ -f k8s/10-tls-secret.yaml ]] || { echo "FATAL: k8s/10-tls-secret.yaml manquant. Lance scripts/gen-tls.sh app.local"; exit 1; }

kubectl apply -f k8s/
kubectl wait --for=condition=available --timeout=180s \
  deployment/postgres deployment/backend deployment/frontend -n todo-app

echo "[deploy] OK"
kubectl get pods,svc,ingress -n todo-app

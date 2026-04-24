#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
OUT="k8s/02-secrets.yaml"

[[ -f "$ENV_FILE" ]] || { echo "FATAL: $ENV_FILE manquant. Copie .env.example vers .env et remplis."; exit 1; }

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${POSTGRES_USER:?}"; : "${POSTGRES_PASSWORD:?}"; : "${POSTGRES_DB:?}"

DB_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"

cat > "$OUT" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: todo-app
type: Opaque
stringData:
  POSTGRES_USER: "${POSTGRES_USER}"
  POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
  DATABASE_URL: "${DB_URL}"
EOF

echo "[gen-secrets] écrit dans $OUT (gitignoré)"

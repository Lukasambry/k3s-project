#!/usr/bin/env bash
set -euo pipefail

CN="${1:-app.local}"
OUT_DIR="$(mktemp -d)"
CRT="$OUT_DIR/tls.crt"
KEY="$OUT_DIR/tls.key"
OUT="k8s/10-tls-secret.yaml"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY" -out "$CRT" \
  -subj "/CN=$CN" \
  -addext "subjectAltName=DNS:$CN"

CRT_B64=$(base64 -w0 < "$CRT")
KEY_B64=$(base64 -w0 < "$KEY")

cat > "$OUT" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-tls
  namespace: todo-app
type: kubernetes.io/tls
data:
  tls.crt: ${CRT_B64}
  tls.key: ${KEY_B64}
EOF

rm -rf "$OUT_DIR"
echo "[gen-tls] écrit dans $OUT (gitignoré)"

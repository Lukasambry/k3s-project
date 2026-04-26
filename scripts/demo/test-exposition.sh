#!/usr/bin/env bash
# Démo barème : Exposition — Ingress Traefik + DNS local + HTTPS.

source "$(dirname "$0")/_common.sh"
require_cluster
require_cmd curl

step "Ingress app-ingress — règles host + path vers les Services"
run kubectl get ingress -n todo-app
run kubectl describe ingress app-ingress -n todo-app

step "Services ClusterIP exposés en interne (frontend, backend, postgres)"
run kubectl get svc -n todo-app

step "Résolution DNS locale dans /etc/hosts"
if grep -q app.local /etc/hosts; then
  grep app.local /etc/hosts
  ok "Entrée trouvée."
else
  warn "Ajoute : echo '192.168.56.10 app.local' | sudo tee -a /etc/hosts"
fi

step "Page web servie via Ingress (TLS auto-signé, code 200)"
run curl -sk -o /dev/null \
  -w "  HTTP %{http_code}  TLS %{ssl_verify_result}  taille %{size_download} octets\n" \
  https://app.local/

step "API REST joignable derrière l'Ingress (path /api → service backend)"
run curl -sk https://app.local/api/todos
echo

ok "App accessible depuis le host via https://app.local."

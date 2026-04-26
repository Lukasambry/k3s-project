#!/usr/bin/env bash
# Bonus 2 (étape 1/2) : pousser une image cassée pour démontrer
# que maxUnavailable: 0 + readiness probe protègent l'app.

source "$(dirname "$0")/_common.sh"
require_cluster
require_cmd curl

step "Historique des révisions du frontend avant l'incident"
run kubectl rollout history deploy/frontend -n todo-app

step "Image actuellement déployée"
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

step "Pousser volontairement une image inexistante (badversion)"
run kubectl set image deploy/frontend \
  frontend=lukasambry/todo-front:badversion -n todo-app

step "Le rollout stagne — un nouveau pod cycle en ImagePullBackOff (15 s)"
sleep 15
run kubectl get pods -n todo-app -l app=frontend

step "Mais l'app reste accessible — les anciens pods continuent à servir"
for i in 1 2 3 4 5; do
  run curl -sk -o /dev/null \
    -w "Tentative $i  HTTP %{http_code}  $(date +%T)\n" https://app.local/
done

step "Statut du Deployment (Progressing=False attendu après 5 min)"
run kubectl rollout status deploy/frontend -n todo-app --timeout=5s || true

info "Aucune dégradation côté utilisateur grâce à maxUnavailable: 0."
ok "Étape 1 OK. ./bonus-2-rollback-restore.sh pour rollback automatique."

#!/usr/bin/env bash
# Bonus 3 (étape 1/2) : rolling update v1 → v2 sans downtime.
# Étape 2 : ./bonus-3-rolling-update-revert.sh

source "$(dirname "$0")/_common.sh"
require_cluster
require_cmd curl

step "Image actuelle (v1, bouton bleu)"
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

step "Stratégie de déploiement (RollingUpdate, maxSurge=1, maxUnavailable=0)"
kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.strategy}' | sed 's/,/\n  /g'
echo

step "Lancer le rolling update vers v2 (bouton vert)"
run kubectl set image deploy/frontend \
  frontend=lukasambry/todo-front:v2 -n todo-app

step "Mesurer le downtime pendant la transition (15 s de curl en boucle)"
end=$((SECONDS + 15))
total=0
ok_count=0
while (( SECONDS < end )); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' https://app.local/)
  total=$((total + 1))
  [[ "$code" == "200" ]] && ok_count=$((ok_count + 1))
  printf '%s ' "$code"
done
echo
info "$ok_count / $total réponses HTTP 200 pendant le rolling update."

step "Statut final du rollout"
run kubectl rollout status deploy/frontend -n todo-app --timeout=120s

step "Tous les pods sont en v2"
run kubectl get pods -n todo-app -l app=frontend
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

ok "Étape 1 OK : v2 déployé. ./bonus-3-rolling-update-revert.sh pour repasser en v1."

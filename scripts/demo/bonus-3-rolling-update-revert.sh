#!/usr/bin/env bash
# Bonus 3 (étape 2/2) : retour en v1 (rolling update inverse).

source "$(dirname "$0")/_common.sh"
require_cluster

step "Image actuellement déployée"
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

step "Rolling update inverse vers v1"
run kubectl set image deploy/frontend \
  frontend=lukasambry/todo-front:v1 -n todo-app

step "Suivre le rollout"
run kubectl rollout status deploy/frontend -n todo-app --timeout=120s

step "Tous les pods sont en v1"
run kubectl get pods -n todo-app -l app=frontend
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

ok "Frontend revenu en v1, état pré-démo restauré."

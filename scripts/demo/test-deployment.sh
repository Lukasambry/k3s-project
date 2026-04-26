#!/usr/bin/env bash
# Démo barème : Déploiement et réplicas — 3 frontend + 2 backend + 1 postgres.
# Inclut un test de self-healing (kill d'un pod backend, recréation auto).

source "$(dirname "$0")/_common.sh"
require_cluster

step "Deployments dans le namespace todo-app"
run kubectl get deploy -n todo-app

step "Pods déployés et leur répartition sur les workers"
run kubectl get pods -n todo-app -o wide

step "Self-healing : on tue un pod backend au hasard"
pod=$(kubectl get pods -n todo-app -l app=backend \
  -o jsonpath='{.items[0].metadata.name}')
info "Pod cible : $pod"
run kubectl delete pod "$pod" -n todo-app

step "Kubernetes recrée immédiatement le pod manquant (attente 20 s)"
sleep 20
run kubectl get pods -n todo-app -l app=backend

step "Confirmation : 2 pods backend Ready, comme avant"
ready=$(kubectl get pods -n todo-app -l app=backend \
  -o jsonpath='{.items[*].status.containerStatuses[0].ready}' \
  | tr ' ' '\n' | grep -c true)
info "Pods backend Ready : $ready / 2"

if [[ "$ready" -eq 2 ]]; then
  ok "Self-healing validé : Kubernetes a maintenu le ReplicaSet à 2."
else
  warn "Le self-healing n'est pas encore terminé — ./test-deployment.sh ou attends quelques secondes."
fi

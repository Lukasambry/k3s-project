#!/usr/bin/env bash
# Démo le PVC survit à la destruction du pod.

source "$(dirname "$0")/_common.sh"
require_cluster
require_cmd curl

step "PersistentVolumeClaim postgres-data + son PV (provisionné par local-path)"
run kubectl get pvc -n todo-app
run kubectl get pv

step "Liste des TODOs avant destruction (preuve qu'il y a de la donnée)"
run curl -sk https://app.local/api/todos
echo

step "Tuer le pod Postgres (l'unique replica)"
pod=$(kubectl get pods -n todo-app -l app=postgres \
  -o jsonpath='{.items[0].metadata.name}')
info "Pod cible : $pod"
run kubectl delete pod "$pod" -n todo-app

step "Attendre que le nouveau pod Postgres soit Ready (jusqu'à 2 min)"
sleep 3
run kubectl wait --for=condition=Ready pod \
  -l app=postgres -n todo-app --timeout=120s

step "Le PVC est resté bound, le nouveau pod a remonté la même donnée"
run kubectl get pvc -n todo-app
sleep 3  # laisse Postgres accepter les connexions
run curl -sk https://app.local/api/todos
echo

ok "Données persistées : le PersistentVolumeClaim (PVC) découple le stockage du cycle de vie du pod."

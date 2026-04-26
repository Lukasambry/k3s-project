#!/usr/bin/env bash
# Bonus 4 (étape 2/2) : arrêter le loadgen et observer le scale-down.

source "$(dirname "$0")/_common.sh"
require_cluster

step "État du HPA avant l'arrêt"
run kubectl get hpa -n todo-app

step "Supprimer le loadgen"
run kubectl delete pod loadgen -n todo-app --ignore-not-found

step "État du HPA juste après (le CPU va retomber)"
sleep 5
run kubectl get hpa -n todo-app

info "Le scale-down attend 5 min (stabilizationWindowSeconds) avant de redescendre"
info "à minReplicas. Pour suivre en arrière-plan :"
info "  kubectl get hpa -n todo-app -w"

ok "Loadgen arrêté. Scale-up automatique sous charge."

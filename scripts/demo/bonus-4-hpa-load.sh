#!/usr/bin/env bash
# Bonus 4 (étape 1/2) : générer une charge CPU et observer le scale-up HPA.
# Étape 2 : ./bonus-4-hpa-stop.sh

source "$(dirname "$0")/_common.sh"
require_cluster

step "État initial des HPA (REPLICAS = minReplicas)"
run kubectl get hpa -n todo-app

step "Suppression d'un éventuel loadgen précédent"
kubectl delete pod loadgen -n todo-app --ignore-not-found >/dev/null

step "Lancer un pod loadgen qui hammer le backend en boucle"
run kubectl run loadgen --image=busybox --restart=Never -n todo-app -- \
  /bin/sh -c "while true; do wget -q -O- http://backend:3000/api/todos > /dev/null; done"

step "Observer la montée du CPU et le scale-up (60 s, 6 itérations)"
for i in 1 2 3 4 5 6; do
  echo "── itération $i / 6 ──"
  kubectl get hpa -n todo-app
  echo "  Pods backend : $(kubectl get pods -n todo-app -l app=backend --no-headers | wc -l)"
  sleep 10
done

step "État final des pods backend (devrait être > 2)"
run kubectl get pods -n todo-app -l app=backend -o wide

info "Charge maintenue. ./bonus-4-hpa-stop.sh pour observer le scale-down."
ok "Étape 1 OK."

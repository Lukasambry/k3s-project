#!/usr/bin/env bash
# Bonus 1 : Resource Requests & Limits + QoS class.
source "$(dirname "$0")/_common.sh"
require_cluster

step "QoS class de chaque pod (Burstable = requests < limits)"
run kubectl get pods -n todo-app \
  -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName'

step "Détail des requests/limits sur le backend"
kubectl describe pod -n todo-app -l app=backend \
  | awk '/^Containers:/,/^Conditions:/' \
  | grep -A2 'Limits:\|Requests:'

step "Idem pour postgres et frontend"
for app in postgres frontend; do
  echo "── $app ──"
  kubectl describe pod -n todo-app -l "app=$app" \
    | awk '/^Containers:/,/^Conditions:/' \
    | grep -A2 'Limits:\|Requests:' \
    | head -10
done

step "Consommation CPU/mémoire en temps réel (metrics-server)"
run kubectl top pods -n todo-app

ok "Bonus 1 démontré : tous les pods ont des resources et la QoS Burstable."

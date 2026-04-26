#!/usr/bin/env bash
# Bonus 2 (étape 2/2) : rollback vers la dernière révision saine.

source "$(dirname "$0")/_common.sh"
require_cluster

step "Historique avant le rollback"
run kubectl rollout history deploy/frontend -n todo-app

step "Rollback : kubectl rollout undo (revient à la révision N-1)"
run kubectl rollout undo deploy/frontend -n todo-app

step "Suivre le redéploiement de la version saine"
run kubectl rollout status deploy/frontend -n todo-app --timeout=120s

step "Tous les pods sont Ready, l'image est revenue à v1"
run kubectl get pods -n todo-app -l app=frontend
run kubectl get deploy frontend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo

ok "Bonus 2 démontré : rollback en une commande, zéro downtime durant l'incident."

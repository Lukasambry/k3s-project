#!/usr/bin/env bash
# Démo barème : Cluster k3s — 1 master + 2 workers, control plane + Traefik OK.

source "$(dirname "$0")/_common.sh"
require_cluster

step "Topologie du cluster — 1 master + 2 workers, tous Ready"
run kubectl get nodes -o wide

step "Rôles des nœuds (control-plane sur master, agent sur workers)"
run kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,ROLES:.metadata.labels.node-role\.kubernetes\.io/control-plane,KERNEL:.status.nodeInfo.kernelVersion,K3S:.status.nodeInfo.kubeletVersion'

step "Composants du control plane (kube-system)"
run kubectl get pods -n kube-system -o wide

step "Traefik (Ingress Controller intégré k3s) tourne sur le master"
run kubectl get pods -n kube-system -l 'app.kubernetes.io/name=traefik' -o wide

ok "Cluster k3s sain : control plane, agents et Ingress opérationnels."

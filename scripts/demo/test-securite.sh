#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"
require_cluster
require_cmd openssl

step "Secrets du namespace (jamais en clair dans les manifests)"
run kubectl get secrets -n todo-app

step "Métadonnées du secret app-secrets (les valeurs ne s'affichent pas)"
run kubectl describe secret app-secrets -n todo-app

step "ConfigMap app-config — paramètres non-sensibles (DB_HOST, DB_NAME, ...)"
run kubectl get configmap app-config -n todo-app -o yaml

step "Le backend consomme le mot de passe via envFrom (pas dans le manifest)"
run kubectl get deploy backend -n todo-app \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom}'
echo

step "Certificat TLS auto-signé stocké en Secret (kubernetes.io/tls)"
run kubectl get secret app-tls -n todo-app
kubectl get secret app-tls -n todo-app \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates

step "Trafic uniquement chiffré : HTTP redirige vers HTTPS"
run curl -skI https://app.local/

ok "Mots de passe, TLS et config séparés du code."

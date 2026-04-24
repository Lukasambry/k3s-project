#!/usr/bin/env bash
set -euo pipefail

kubectl delete namespace todo-app --ignore-not-found
echo "[teardown] namespace todo-app supprimé (les PV local-path restent sur le disque du master)"

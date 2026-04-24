#!/usr/bin/env bash
set -euo pipefail

: "${DOCKERHUB_USER:?DOCKERHUB_USER non défini (export DOCKERHUB_USER=lukasambry)}"
TAG="${1:-v1}"

echo "[build-and-push] user=$DOCKERHUB_USER tag=$TAG"

docker build -t "$DOCKERHUB_USER/todo-back:$TAG" app/backend
docker build -t "$DOCKERHUB_USER/todo-front:$TAG" app/frontend

docker push "$DOCKERHUB_USER/todo-back:$TAG"
docker push "$DOCKERHUB_USER/todo-front:$TAG"

echo "[build-and-push] OK — images poussées :"
echo "  - $DOCKERHUB_USER/todo-back:$TAG"
echo "  - $DOCKERHUB_USER/todo-front:$TAG"

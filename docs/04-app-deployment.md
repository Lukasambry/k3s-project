# 04 — Déploiement de l'application

Prérequis : cluster k3s opérationnel selon [03-k3s-install.md](03-k3s-install.md), `kubectl` configuré sur le host.

## Vue d'ensemble

L'application est composée de :
- **Frontend** (3 replicas) : React SPA servie par nginx
- **Backend** (2 replicas) : Node.js + Express, expose `/api/todos` (CRUD) et `/health`
- **PostgreSQL** (1 replica, pinned sur le master) : avec `PersistentVolumeClaim` de 2 Gi

Tous les composants vivent dans le namespace `todo-app`. Les images sont publiées sur Docker Hub (`userambry/todo-back:v1`, `userambry/todo-front:v1`).

## Étape 1 — Build et push des images Docker

Sur le host :

```bash
# Générer les package-lock.json (nécessaires pour npm ci dans les Dockerfiles)
cd app/backend && npm install && cd ../..
cd app/frontend && npm install && cd ../..

# Login Docker Hub
docker login

# Build et push
export DOCKERHUB_USER=userambry
./scripts/build-and-push.sh v1
```

## Étape 2 — Préparer les secrets

```bash
# Créer .env à partir de l'exemple (avec un mot de passe fort)
cp .env.example .env
# Éditer .env : remplacer POSTGRES_PASSWORD par un mot de passe fort
# Tip : openssl rand -base64 24 | tr -d '/+='

# Générer le Secret Kubernetes à partir du .env
./scripts/gen-secrets.sh
# → écrit k8s/02-secrets.yaml (gitignoré)
```

## Étape 3 — Générer le certificat TLS auto-signé

```bash
./scripts/gen-tls.sh app.local
# → écrit k8s/10-tls-secret.yaml (gitignoré)
```

## Étape 4 — Déployer

Tout est dans `k8s/`, fichiers numérotés pour respecter l'ordre :
- `00-namespace.yaml`
- `01-configmap.yaml`
- `02-secrets.yaml` (généré)
- `03-postgres-pvc.yaml`
- `04-postgres-deployment.yaml`
- `05-postgres-service.yaml`
- `06-backend-deployment.yaml`
- `07-backend-service.yaml`
- `08-frontend-deployment.yaml`
- `09-frontend-service.yaml`
- `10-tls-secret.yaml` (généré)
- `11-ingress.yaml`

Le script `scripts/deploy.sh` les applique tous dans l'ordre :

```bash
./scripts/deploy.sh
```

Ou en manuel :
```bash
kubectl apply -f k8s/
kubectl wait --for=condition=available --timeout=180s \
  deployment/postgres deployment/backend deployment/frontend -n todo-app
```

`kubectl apply -f <dir>` ne matche que `.yaml` / `.yml` / `.json` — les fichiers `.example` sont ignorés automatiquement.

## Étape 5 — Configurer le DNS local

Sur le host :
```bash
echo "192.168.56.10 app.local" | sudo tee -a /etc/hosts
```

## Étape 6 — Vérification

```bash
kubectl get pods,svc,ingress -n todo-app
```

Attendu :
- 1 pod postgres `Running` sur `k3s-master`
- 2 pods backend `Running` sur worker1 et worker2
- 3 pods frontend `Running` sur les 3 nœuds (un par nœud)
- Services `postgres`, `backend`, `frontend` (ClusterIP)
- Ingress `app-ingress` avec ADDRESS = les 3 IPs des nœuds

Test depuis le navigateur : `https://app.local` → l'UI de la todo-list. Le navigateur affichera un warning "certificat non sécurisé" (cert auto-signé) → "Avancé" → "Accepter le risque".

Test depuis le terminal :
```bash
curl -k https://app.local/api/todos
# → []  (ou la liste si tu as déjà créé des todos)
```

## Pourquoi Postgres est pinned sur le master

Voir [01-architecture.md](01-architecture.md). Résumé : le provisioner `local-path` lie le PV à un nœud spécifique. Pinning sur master = volume toujours sur le master = test "panne d'un worker" déterministe (les workers n'ont pas de données).

## Teardown

Pour repartir d'un état propre :
```bash
./scripts/teardown.sh
# → kubectl delete namespace todo-app (les PV restent sur le disque du master)
```

Pour aussi virer les PV physiques sur le master :
```bash
ssh user@192.168.56.10 'sudo rm -rf /var/lib/rancher/k3s/storage/pvc-*'
```

## Personnalisation

Pour pousser une nouvelle version de l'app :

```bash
./scripts/build-and-push.sh v2
# Éditer k8s/06-backend-deployment.yaml et k8s/08-frontend-deployment.yaml :
# image: userambry/todo-back:v1  →  v2
kubectl apply -f k8s/06-backend-deployment.yaml -f k8s/08-frontend-deployment.yaml
# k3s fait un rolling update automatique
```

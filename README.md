# Clusterisation de container — Projet final ESGI 5IW

Déploiement d'une application web (frontend React, backend Node.js/Express, base de données PostgreSQL) sur un cluster **k3s** (Kubernetes allégé) composé de 3 machines virtuelles VirtualBox.

Le projet démontre la maîtrise de l'orchestration de conteneurs : haute disponibilité (réplicas, rescheduling automatique), persistance (PersistentVolumeClaim), sécurité (Secrets Kubernetes, HTTPS), et exposition (Ingress Traefik).

## Architecture cible

- **1 nœud master** (`k3s-master`, 192.168.56.10) : control plane k3s, héberge l'Ingress Traefik et la base Postgres (pinned via `nodeSelector`).
- **2 nœuds workers** (`k3s-worker1` / `k3s-worker2`, 192.168.56.11 / 192.168.56.12) : exécutent les pods stateless du frontend et du backend.
- **Réseau** : adaptateur NAT (accès internet sortant) + adaptateur Host-only `vboxnet0` (communication inter-VM et host ↔ VMs).
- **Réplicas** : 3 pods frontend, 2 pods backend, 1 pod Postgres.
- **Exposition** : `https://app.local` via Ingress Traefik + certificat auto-signé, résolution DNS locale via `/etc/hosts`.

## Prérequis

- Ubuntu 24.04 (ou équivalent Linux)
- VirtualBox 7.x
- Docker 20.x et un compte Docker Hub pour publier les images
- `kubectl` (installé sur le host, piloté via la kubeconfig du master)
- `openssl` (génération du certificat TLS auto-signé)

## Structure du dépôt

```
clusterisation/
├── app/              Code de l'application (frontend, backend)
├── k8s/              Manifests Kubernetes (Deployments, Services, Ingress, PVC, Secrets)
├── scripts/          Scripts utilitaires (build-and-push, deploy, teardown, gen-secrets, gen-tls)
```

## Stack technique

| Couche | Technologie |
|---|---|
| Orchestration | k3s (Kubernetes compatible) |
| Ingress / Load Balancer | Traefik (intégré à k3s) |
| Runtime conteneurs | containerd (intégré à k3s) |
| Frontend | React (Vite) servi par nginx |
| Backend | Node.js 20 + Express + `pg` |
| Base de données | PostgreSQL 16 Alpine |
| Stockage persistant | local-path provisioner (intégré à k3s) |

## Documentation

Tous les détails de mise en place et de validation sont dans `docs/` :

- [`01-architecture.md`](docs/01-architecture.md) — schéma d'architecture, choix techniques, limitations
- [`02-vm-setup.md`](docs/02-vm-setup.md) — création des 3 VMs VirtualBox (Ubuntu Server 24.04)
- [`03-k3s-install.md`](docs/03-k3s-install.md) — installation du cluster k3s (1 master + 2 workers)
- [`04-app-deployment.md`](docs/04-app-deployment.md) — build des images, déploiement des manifests
- [`05-tests-ha.md`](docs/05-tests-ha.md) — 8 tests de haute disponibilité avec captures
- [`06-troubleshooting.md`](docs/06-troubleshooting.md) — pièges rencontrés et solutions

## Quickstart (reproduction)

Pour un correcteur qui clone le dépôt et veut tout rejouer :

1. **VirtualBox 7.1+**, ISO Ubuntu Server 24.04 téléchargée, `kubectl` et `docker` installés sur le host.
2. Suivre [`docs/02-vm-setup.md`](docs/02-vm-setup.md) pour créer les 3 VMs (≈ 4-5 h la première fois).
3. Suivre [`docs/03-k3s-install.md`](docs/03-k3s-install.md) pour installer k3s et copier la kubeconfig sur le host.
4. Sur le host, dans le repo cloné :
   ```bash
   # Code applicatif (génère les package-lock.json nécessaires aux Dockerfiles)
   (cd app/backend && npm install) && (cd app/frontend && npm install)

   # Login Docker Hub + build/push avec ton propre user
   docker login
   export DOCKERHUB_USER=<votre-user-dockerhub>
   ./scripts/build-and-push.sh v1
   # Puis adapter k8s/06-backend-deployment.yaml et k8s/08-frontend-deployment.yaml
   # pour pointer sur <votre-user>/todo-back:v1 et <votre-user>/todo-front:v1

   # Secrets et certif TLS
   cp .env.example .env                       # remplir POSTGRES_PASSWORD avec un mot de passe fort
   ./scripts/gen-secrets.sh
   ./scripts/gen-tls.sh app.local

   # DNS local
   echo "192.168.56.10 app.local" | sudo tee -a /etc/hosts

   # Déployer
   ./scripts/deploy.sh
   ```
5. Ouvrir `https://app.local` (accepter le certificat auto-signé).
6. Rejouer les tests HA : voir [`docs/05-tests-ha.md`](docs/05-tests-ha.md).

## Contexte

Projet final du module *Clusterisation de container* (ESGI 5IW, intervenant Vincent LAINE). Énoncé complet dans [`SUJET_DU_PROJET.pdf`](./SUJET_DU_PROJET.pdf).


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


# 01 — Architecture

## Vue d'ensemble

Application web 3-tiers (frontend React, backend Node.js/Express, base de données PostgreSQL) déployée sur un cluster **k3s** de 3 nœuds VirtualBox. L'objectif est de démontrer la maîtrise de l'orchestration de conteneurs : haute disponibilité, persistance, sécurité, exposition externe.

## Schéma logique

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Host Ubuntu 24.04 (poste de dev)                                         │
│                                                                          │
│   Navigateur ──── https://app.local ───▶ /etc/hosts → 192.168.56.10      │
│                                                                          │
│   kubectl ──── KUBECONFIG → cluster                                      │
└──────────────────────────────────────────────────────────────────────────┘
                                          │
                          Réseau Host-only vboxnet0 (192.168.56.0/24)
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│  k3s-master      │          │  k3s-worker1     │          │  k3s-worker2     │
│  192.168.56.10   │          │  192.168.56.11   │          │  192.168.56.12   │
│  (control plane) │          │                  │          │                  │
│                  │          │                  │          │                  │
│  Traefik (LB)    │          │                  │          │                  │
│  + Ingress       │          │                  │          │                  │
│                  │          │                  │          │                  │
│  Postgres × 1 ◄──┼──┐       │                  │          │                  │
│  (pinned)        │  │       │                  │          │                  │
│                  │  │       │                  │          │                  │
│  Frontend × 1    │  │       │  Frontend × 1    │          │  Frontend × 1    │
│                  │  │       │  Backend × 1 ────┼─────────►│  Backend × 1     │
│                  │  │       │                  │          │                  │
│  PV local-path ──┘──┘       │                  │          │                  │
└──────────────────┘          └──────────────────┘          └──────────────────┘
```

## Topologie physique

| VM | Rôle | vCPU | RAM | Disque | IP host-only |
|---|---|---|---|---|---|
| `k3s-master` | Control plane k3s | 2 | 2 Go | 20 Go | 192.168.56.10 |
| `k3s-worker1` | Worker | 2 | 2 Go | 20 Go | 192.168.56.11 |
| `k3s-worker2` | Worker | 2 | 2 Go | 20 Go | 192.168.56.12 |

**Réseau** : chaque VM a deux interfaces :
- `enp0s3` (NAT) → accès internet (apt, pull images)
- `enp0s8` (Host-only `vboxnet0`) → communication inter-VM + accès depuis le host

## Choix techniques

### Orchestrateur : k3s

[k3s](https://k3s.io) est une distribution légère de Kubernetes (~100 Mo, single binary). Avantages pour ce projet :
- Installation en une commande, pas de configuration manuelle de etcd/kubeadm.
- Embarque par défaut Traefik (Ingress), CoreDNS, local-path-provisioner, metrics-server.
- 100 % compatible API Kubernetes — `kubectl`, manifests YAML, et compétences transférables.

### Stockage : `local-path-provisioner`

Provisioner par défaut de k3s. Crée des `PersistentVolume` de type `hostPath` sur le nœud où le pod est ordonnancé. Suffisant pour ce projet (PostgreSQL mono-replica).

**Limitation** : les volumes ne sont pas répliqués entre nœuds. Si le nœud du PV tombe en panne définitive, les données sont perdues. C'est pour cela que **Postgres est pinned sur le master** via `nodeSelector: kubernetes.io/hostname: k3s-master` — le test "panne d'un worker" (Chunk 7) reste déterministe car les workers n'hébergent pas de données.

### Ingress : Traefik (intégré à k3s)

Traefik écoute sur les ports 80 et 443 de chaque nœud (DaemonSet `svclb-traefik`). On expose un `Ingress` sur `app.local` avec terminaison TLS via un certificat auto-signé. La résolution DNS est faite via `/etc/hosts` côté host.

**Stratégie HTTPS-only** : l'Ingress n'écoute que sur l'entrypoint `websecure` (443). Pas de redirection HTTP→HTTPS automatique (nécessiterait une `Middleware` CRD Traefik, complexité non justifiée pour ce projet).

### Distribution des images

Images publiées sur Docker Hub (compte `lukasambry`, repos publics) :
- `lukasambry/todo-back:v1`
- `lukasambry/todo-front:v1`

Les manifests référencent des **tags immuables** (`v1`, jamais `latest`).

## Réplicas et résilience

| Composant | Replicas | Justification |
|---|---|---|
| `frontend` | 3 | Servi par nginx (stateless), 1 par nœud assure la HA |
| `backend` | 2 | Stateless, 2 replicas suffisent pour la résilience |
| `postgres` | 1 | Stateful, mono-instance (volume non répliqué) |

Chaque Deployment a des `livenessProbe`/`readinessProbe` pour que k3s redémarre automatiquement les pods non-fonctionnels et ne route le trafic que vers les pods prêts.

## Flux d'une requête utilisateur

1. Navigateur → `https://app.local`
2. `/etc/hosts` résout en `192.168.56.10`
3. Traefik (sur `:443`) reçoit la requête, présente le cert auto-signé
4. Selon le path :
   - `/api/*` → Service `backend:3000` (load-balancé entre les 2 pods backend)
   - `/*` → Service `frontend:80` (load-balancé entre les 3 pods frontend → nginx → SPA React)
5. Le backend interroge Postgres via le DNS interne `postgres.todo-app.svc.cluster.local`

## Limitations connues

- **Postgres mono-nœud** : si le master tombe en panne définitive, les données sont perdues. Mitigation hors périmètre : réplication (Patroni), volume partagé (NFS/Longhorn).
- **Certificat auto-signé** : warning navigateur inévitable. Let's Encrypt non utilisé (cluster non exposé publiquement).
- **Ingress sur le master uniquement** : `app.local` pointe sur 192.168.56.10. Si le master tombe, l'entrée du cluster tombe. Mitigation hors périmètre : IP virtuelle (keepalived, MetalLB).

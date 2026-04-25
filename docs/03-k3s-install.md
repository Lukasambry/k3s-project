# 03 — Installation du cluster k3s

Prérequis : 3 VMs configurées selon [02-vm-setup.md](02-vm-setup.md), accessibles en SSH passwordless depuis le host.

## Vue d'ensemble

| Nœud | Rôle | Commande |
|---|---|---|
| `k3s-master` (192.168.56.10) | `k3s server` (control plane) | `curl -sfL https://get.k3s.io | sh -` avec flags server |
| `k3s-worker1` (192.168.56.11) | `k3s agent` | idem avec flags agent + token |
| `k3s-worker2` (192.168.56.12) | `k3s agent` | idem |

## Étape 1 — Installation du master

```bash
ssh user@192.168.56.10 "curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC='server \
  --node-ip=192.168.56.10 \
  --node-external-ip=192.168.56.10 \
  --flannel-iface=enp0s8 \
  --tls-san=192.168.56.10 \
  --write-kubeconfig-mode=644' sh -"
```

**Explications des flags critiques :**

| Flag | Pourquoi |
|---|---|
| `--node-ip=192.168.56.10` | Force k3s à utiliser l'interface host-only (pas la NAT) pour l'identification du nœud |
| `--flannel-iface=enp0s8` | Force le CNI Flannel sur l'interface host-only. Sans ça, il prend `enp0s3` (NAT) et les pods ne peuvent pas se parler entre nœuds |
| `--tls-san=192.168.56.10` | Ajoute l'IP host-only aux Subject Alternative Names du certif API. **Sans ce flag**, `kubectl` depuis le host échoue avec `x509: certificate valid for ... not 192.168.56.10` |
| `--write-kubeconfig-mode=644` | Permet à `user` de lire la kubeconfig sans sudo |

Vérification :
```bash
ssh user@192.168.56.10 'sudo systemctl is-active k3s'
# → active
ssh user@192.168.56.10 'sudo k3s kubectl get nodes'
# → k3s-master   Ready   control-plane   ...
```

## Étape 2 — Récupération du token de jonction

```bash
TOKEN=$(ssh user@192.168.56.10 'sudo cat /var/lib/rancher/k3s/server/node-token')
echo "$TOKEN"
```

Format attendu : `K10712757...::server:bc3b5b9a...` (chaîne longue).

## Étape 3 — Installation des workers

Sur chaque worker, en remplaçant l'IP :

```bash
# worker1
ssh user@192.168.56.11 "curl -sfL https://get.k3s.io | sudo K3S_URL=https://192.168.56.10:6443 K3S_TOKEN='$TOKEN' INSTALL_K3S_EXEC='agent \
  --node-ip=192.168.56.11 \
  --node-external-ip=192.168.56.11 \
  --flannel-iface=enp0s8' sh -"

# worker2 (même commande, .12 partout)
ssh user@192.168.56.12 "curl -sfL https://get.k3s.io | sudo K3S_URL=https://192.168.56.10:6443 K3S_TOKEN='$TOKEN' INSTALL_K3S_EXEC='agent \
  --node-ip=192.168.56.12 \
  --node-external-ip=192.168.56.12 \
  --flannel-iface=enp0s8' sh -"
```

Vérification du cluster (depuis le master) :
```bash
ssh user@192.168.56.10 'sudo k3s kubectl get nodes -o wide'
```
Attendu : 3 nœuds `Ready` (capture `docs/screenshots/test1-nodes.png`).

## Étape 4 — Installer kubectl sur le host

```bash
sudo snap install kubectl --classic
# ou
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

## Étape 5 — Copier la kubeconfig sur le host

```bash
mkdir -p ~/.kube
ssh user@192.168.56.10 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/k3s-vbox-config
sed -i 's/127.0.0.1/192.168.56.10/g' ~/.kube/k3s-vbox-config
chmod 600 ~/.kube/k3s-vbox-config

# Persistance dans le shell
echo 'export KUBECONFIG=$HOME/.kube/k3s-vbox-config' >> ~/.zshrc   # ou ~/.bashrc
source ~/.zshrc
```

**Important** : utiliser `$HOME` et pas `~` dans `KUBECONFIG` (kubectl ne fait pas l'expansion tilde sur cette variable).

## Étape 6 — Vérification finale

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Tous les pods système (`coredns`, `traefik`, `local-path-provisioner`, `metrics-server`, `svclb-traefik`) doivent être `Running`. Le cluster est prêt pour le déploiement de l'application ([04-app-deployment.md](04-app-deployment.md)).

## Troubleshooting

**Worker `NotReady`** : vérifier l'agent.
```bash
ssh user@192.168.56.11 'sudo systemctl status k3s-agent'
ssh user@192.168.56.11 'sudo journalctl -u k3s-agent -n 50 --no-pager'
```

Causes fréquentes :
- Token incorrect → re-vérifier `sudo cat /var/lib/rancher/k3s/server/node-token` sur le master
- Mauvaise interface Flannel → ajouter `--flannel-iface=enp0s8`
- Reste d'une installation précédente → `sudo /usr/local/bin/k3s-agent-uninstall.sh` puis réinstaller

**`kubectl` depuis le host : `x509: certificate signed by unknown authority`** : oublié de mettre `--tls-san=192.168.56.10` à l'installation du master. Solution : réinstaller le master avec ce flag, ou ajouter `--tls-san` post-install via `/etc/systemd/system/k3s.service.env` puis `systemctl restart k3s`.

**`The connection to the server localhost:8080 was refused`** : `KUBECONFIG` n'est pas défini. Faire `source ~/.zshrc` ou ouvrir un nouveau terminal.

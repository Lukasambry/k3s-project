# 06 — Troubleshooting

Pièges rencontrés pendant la mise en place du projet, avec leur solution.

## VirtualBox : `vboxdrv` introuvable

**Symptôme** : `WARNING: The character device /dev/vboxdrv does not exist`.

**Cause** : VirtualBox 7.0.x ne sait pas compiler son module noyau contre kernel 6.17 (Ubuntu 24.04 HWE récent).

**Solution** : passer sur VirtualBox 7.1+ depuis le repo Oracle officiel (cf. [02-vm-setup.md](02-vm-setup.md) §Prérequis host).

## Clones avec la même `machine-id`

**Symptôme** : un seul nœud apparaît dans `kubectl get nodes` même après installation des agents sur les 3 VMs.

**Cause** : `clonevm` copie aussi `/etc/machine-id`, qui sert d'identifiant unique. k3s utilise cet ID, donc les 3 nœuds sont vus comme un seul.

**Solution** : régénérer la machine-id sur chaque clone :
```bash
sudo rm /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo dbus-uuidgen --ensure
```

## Deux IPs sur `enp0s8` (statique + DHCP)

**Symptôme** : `ip -4 addr show enp0s8` retourne deux lignes, une `192.168.56.10/24` et une `192.168.56.<dynamic>/24 metric 100`.

**Cause** : netplan a `dhcp4: true` ET `addresses` au lieu de `dhcp4: false`. Erreur de frappe fréquente.

**Solution** :
```bash
sudo tee /etc/netplan/50-cloud-init.yaml >/dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false       # ← bien false !
      addresses:
        - 192.168.56.10/24
EOF
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
```

## `kubectl` depuis le host : `x509: certificate signed by unknown authority`

**Symptôme** : `kubectl get nodes` depuis le host échoue avec une erreur de certificat.

**Cause** : le master a été installé sans `--tls-san=192.168.56.10`. Le cert API n'inclut pas l'IP host-only.

**Solution** : réinstaller le master avec :
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server ... --tls-san=192.168.56.10 ..." sh -
```

Ou ajouter le SAN à chaud en éditant `/etc/systemd/system/k3s.service.env` puis `sudo systemctl restart k3s`.

## `KUBECONFIG=~/.kube/...` ne marche pas

**Symptôme** : `kubectl` retourne `connection refused` sur `localhost:8080` même avec la kubeconfig copiée.

**Cause** : kubectl ne fait pas l'expansion tilde sur le contenu de la variable `KUBECONFIG`. Il cherche littéralement le fichier `~/.kube/...`.

**Solution** : utiliser `$HOME` :
```bash
export KUBECONFIG=$HOME/.kube/k3s-vbox-config
```

## `npm ci` échoue : `package-lock.json` introuvable

**Symptôme** : `docker build` échoue dans `app/backend/Dockerfile` ou `app/frontend/Dockerfile` avec un message lié à `npm ci`.

**Cause** : `npm ci` requiert un `package-lock.json`. Or il n'est généré que par `npm install`.

**Solution** : lancer `npm install` dans `app/backend/` et `app/frontend/` au moins une fois avant le premier `docker build`. Commiter les `package-lock.json` produits.

## Postgres `Pending` indéfiniment

**Symptôme** : `kubectl get pods -n todo-app` montre `postgres-...` en `Pending`.

**Causes possibles** :
1. **`nodeSelector: kubernetes.io/hostname: k3s-master`** sans label correspondant. Vérifier avec `kubectl get nodes --show-labels | grep hostname`. Le label est appliqué automatiquement par kubelet, donc en principe OK.
2. PVC non bound. Vérifier `kubectl get pvc -n todo-app`. Si `Pending`, vérifier que le storage class `local-path` existe : `kubectl get storageclass`.
3. Ressources CPU/RAM insuffisantes sur le master. `kubectl describe pod ... -n todo-app` indique la raison.

## L'Ingress ne route pas

**Symptôme** : `curl -k https://app.local/` retourne 404 ou timeout.

**Causes** :
- `/etc/hosts` n'a pas l'entrée `192.168.56.10 app.local`. Vérifier avec `getent hosts app.local`.
- Tu tapes `http://app.local` au lieu de `https://`. L'Ingress n'écoute que sur le port 443.
- Le service Traefik ne tourne pas. `kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik` doit montrer un pod `Running`.
- Mauvais `ingressClassName`. Doit être `traefik` (pas `nginx`).

## Le navigateur affiche "DNS_PROBE_FINISHED_NXDOMAIN"

**Cause** : le navigateur ne trouve pas `app.local` car `/etc/hosts` n'a pas été modifié, ou il a son propre cache DNS.

**Solution** :
```bash
# Vérifier
getent hosts app.local
# Si vide, ajouter
echo "192.168.56.10 app.local" | sudo tee -a /etc/hosts
# Vider le cache DNS du navigateur (Chrome : chrome://net-internals/#dns)
```

## Pod `tmp` collision

**Symptôme** : `kubectl run tmp ...` retourne `pods "tmp" already exists`.

**Cause** : un pod `tmp` précédent n'a pas été supprimé proprement (Ctrl+C interrompu).

**Solution** : utiliser un nom unique :
```bash
kubectl run "tmp-$RANDOM" --rm -i --restart=Never --image=curlimages/curl -n todo-app -- ...
```

## Test "panne d'un worker" : pods restent `Running` longtemps

**Symptôme** : worker2 est `NotReady` mais ses pods sont toujours `Running` (pas `Terminating`) après plusieurs minutes.

**Cause** : c'est le comportement normal de Kubernetes. Les `tolerations` par défaut sur tous les pods incluent `node.kubernetes.io/unreachable:NoExecute` avec `tolerationSeconds: 300`. Donc Kubernetes attend **5 minutes** avant d'évincer.

**Solution** : patience. Pendant ces 5 min, les autres replicas (sur master/worker1) prennent le trafic, donc l'app reste accessible.

## `apt update` : `ImportError: ... sqlite3 ... undefined symbol`

**Cause** : une installation Python tierce (souvent une distribution conda ou un packageur custom) a écrasé la lib partagée sqlite3 du système.

**Impact** : aucun sur les opérations APT elles-mêmes. C'est juste le hook `command-not-found` post-install qui échoue.

**Solution** : ignorer le warning. Si gênant en permanence : réparer le binding sqlite Python avec `pip install --force-reinstall pysqlite3`.

## Limitations connues du projet (non bugs)

- **Postgres mono-nœud** : si le master tombe en panne définitive, les données sont perdues (cf. [01-architecture.md](01-architecture.md) §Limitations).
- **Cert TLS auto-signé** : warning navigateur inévitable. Attendu.
- **Ingress sur le master uniquement** : `app.local` pointe sur 192.168.56.10. Si le master tombe, l'entrée extérieure tombe.
- **Pas de redirect HTTP→HTTPS automatique** : volontaire (simplification). Le client doit taper `https://`.

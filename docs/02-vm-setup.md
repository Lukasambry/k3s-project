# 02 — Création des 3 VMs VirtualBox

## Prérequis host (Ubuntu 24.04)

1. **VirtualBox 7.1+** (la 7.0 ne sait pas compiler son module noyau contre kernel 6.17). Installation depuis le repo Oracle :
   ```bash
   wget -qO /tmp/vbox.asc https://www.virtualbox.org/download/oracle_vbox_2016.asc
   sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg /tmp/vbox.asc
   echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] http://download.virtualbox.org/virtualbox/debian noble contrib' | sudo tee /etc/apt/sources.list.d/virtualbox.list
   sudo apt update && sudo apt install -y virtualbox-7.2
   sudo usermod -aG vboxusers $USER
   sudo /sbin/vboxconfig
   ```

2. **Réseau host-only**. Une fois VBox installé :
   ```bash
   sudo VBoxManage hostonlyif create
   sudo VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
   sudo mkdir -p /etc/vbox
   echo '* 0.0.0.0/0 ::/0' | sudo tee /etc/vbox/networks.conf
   ```

3. **ISO Ubuntu Server 24.04** (la dernière .x du moment, ex : 24.04.4) :
   ```bash
   cd ~/Téléchargements
   ISO_NAME=$(curl -s https://releases.ubuntu.com/24.04/ | grep -oE 'ubuntu-24\.04(\.[0-9]+)?-live-server-amd64\.iso' | sort -Vu | tail -1)
   wget "https://releases.ubuntu.com/24.04/$ISO_NAME"
   ```

## Méthode : créer une VM de base puis cloner

On crée **une seule VM** (`k3s-base`), on l'installe et on la configure proprement, puis on la clone 3 fois.

### Création de la VM de base

```bash
VBoxManage createvm --name "k3s-base" --ostype "Ubuntu_64" --register
VBoxManage modifyvm "k3s-base" \
  --memory 2048 --cpus 2 --vram 16 \
  --nic1 nat \
  --nic2 hostonly --hostonlyadapter2 vboxnet0 \
  --boot1 dvd --boot2 disk --boot3 none --boot4 none

VBoxManage createmedium disk \
  --filename "$HOME/VirtualBox VMs/k3s-base/k3s-base.vdi" \
  --size 20480 --format VDI

VBoxManage storagectl "k3s-base" --name "SATA" --add sata --bootable on
VBoxManage storageattach "k3s-base" --storagectl "SATA" --port 0 --device 0 \
  --type hdd --medium "$HOME/VirtualBox VMs/k3s-base/k3s-base.vdi"
VBoxManage storageattach "k3s-base" --storagectl "SATA" --port 1 --device 0 \
  --type dvddrive --medium "$HOME/Téléchargements/$ISO_NAME"

VBoxManage startvm "k3s-base"
```

### Installation Ubuntu Server

Suivre l'installeur avec ces choix :
- **Langue** : English (évite des bugs CLI avec accents)
- **Clavier** : French
- **Type** : Ubuntu Server (pas Minimal)
- **Réseau** : DHCP sur les deux interfaces (on fixera dans les clones)
- **Storage** : Use entire disk, sans LVM
- **Profil** : `user` / `user` / mot de passe noté
- **SSH** : ✅ Install OpenSSH server (crucial)
- **Featured snaps** : ne rien cocher

Au reboot, détacher l'ISO :
```bash
VBoxManage storageattach "k3s-base" --storagectl "SATA" --port 1 --device 0 \
  --type dvddrive --medium emptydrive
```

### Configuration post-install (dans la VM, en SSH ou console)

```bash
# Update + outils
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim net-tools iputils-ping

# Désactiver swap (requis par Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Modules noyau pour le CNI
echo -e 'br_netfilter\noverlay' | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe br_netfilter
sudo modprobe overlay

# Sysctl pour le forwarding réseau
echo -e 'net.bridge.bridge-nf-call-iptables  = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Vérifications
sudo sysctl net.ipv4.ip_forward       # → 1
lsmod | grep -E 'br_netfilter|overlay'  # 2 lignes

# Éteindre proprement
sudo poweroff
```

## Clonage en 3 VMs

```bash
for n in master worker1 worker2; do
  VBoxManage clonevm "k3s-base" --name "k3s-$n" --register --mode machine
  VBoxManage modifyvm "k3s-$n" --macaddress2 auto
done
VBoxManage list vms
```

## Personnalisation de chaque clone

Démarrer chaque VM **une à la fois** et exécuter le bloc suivant en adaptant `NEW_HOSTNAME` et l'IP. **Étape critique : régénérer la `machine-id`** sinon k3s refusera d'enregistrer les workers (tous les nœuds auraient le même ID).

```bash
# Régénérer machine-id (CRITIQUE)
sudo rm /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo dbus-uuidgen --ensure

# Hostname (à adapter : k3s-master, k3s-worker1, k3s-worker2)
NEW_HOSTNAME=k3s-master
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
sudo sed -i "s/127.0.1.1.*k3s-base/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts

# Régénérer les clés SSH host
sudo rm /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server

# Désactiver la régénération réseau de cloud-init
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# Netplan IP fixe (à adapter : .10, .11, .12)
sudo tee /etc/netplan/50-cloud-init.yaml >/dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.56.10/24
EOF

sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo reboot
```

**Attention** : `dhcp4: false` (pas `true`) — sinon tu te retrouves avec deux IPs sur la même interface (statique + DHCP), ce qui perturbe k3s.

## Vérification depuis le host

```bash
# Ping des 3 VMs
for ip in 10 11 12; do ping -c 1 192.168.56.$ip; done

# SSH passwordless (clé publique copiée sur les 3 VMs)
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519  # si pas déjà fait
for ip in 10 11 12; do
  ssh-copy-id -o StrictHostKeyChecking=accept-new user@192.168.56.$ip
done

# Vérif hostnames
for ip in 10 11 12; do ssh user@192.168.56.$ip hostname; done
# → k3s-master, k3s-worker1, k3s-worker2
```

## Sudoers NOPASSWD (optionnel mais recommandé pour l'admin)

Pour éviter de retaper le mot de passe sudo à chaque commande d'administration depuis le host, sur chaque VM :

```bash
ssh user@192.168.56.10
echo 'user ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/user-nopasswd
sudo chmod 440 /etc/sudoers.d/user-nopasswd
exit
# Répéter pour .11 et .12
```

À ce stade, les 3 VMs sont prêtes pour l'installation de k3s ([03-k3s-install.md](03-k3s-install.md)).

#!/usr/bin/env bash
# Lance les 3 VMs (k3s-master, k3s-worker1, k3s-worker2) en mode GUI
# et attend que le cluster k3s soit Ready (3 nœuds).
# Sans argument, à exécuter depuis le host.

source "$(dirname "$0")/_common.sh"

VMS=(k3s-master k3s-worker1 k3s-worker2)
HOSTONLY_IF=vboxnet0
HOSTONLY_IP=192.168.56.1
HOSTONLY_MASK=255.255.255.0

require_cmd VBoxManage
require_cmd kubectl

ensure_hostonly_if() {
  if VBoxManage list hostonlyifs | awk '/^Name:/{print $2}' | grep -qx "$HOSTONLY_IF"; then
    info "$HOSTONLY_IF déjà présent."
    return 0
  fi

  warn "$HOSTONLY_IF absent — réparation en cours..."

  # Module kernel manquant après reboot ? (besoin sudo)
  if ! lsmod | grep -q '^vboxnetadp'; then
    info "Chargement des modules kernel (sudo) : vboxnetadp + vboxnetflt"
    sudo modprobe vboxnetadp vboxnetflt
  fi

  # Création de l'interface — produit "vboxnetN" avec N libre, normalement 0
  local created
  created=$(VBoxManage hostonlyif create 2>&1 \
    | sed -n "s/.*'\\([^']*\\)'.*/\\1/p" | head -1)
  if [[ -z "$created" ]]; then
    warn "Création échouée. Sortie de VBoxManage :"
    VBoxManage hostonlyif create
    exit 1
  fi
  info "Interface créée : $created"

  if [[ "$created" != "$HOSTONLY_IF" ]]; then
    warn "Nom différent de $HOSTONLY_IF (les VMs sont configurées sur $HOSTONLY_IF)."
    warn "Suppression et nouvelle tentative après nettoyage des interfaces orphelines..."
    VBoxManage hostonlyif remove "$created" || true
    # Supprimer toute autre interface vboxnetN avant de retenter
    while read -r n; do
      [[ -n "$n" ]] && VBoxManage hostonlyif remove "$n" || true
    done < <(VBoxManage list hostonlyifs | awk '/^Name:/{print $2}')
    created=$(VBoxManage hostonlyif create 2>&1 \
      | sed -n "s/.*'\\([^']*\\)'.*/\\1/p" | head -1)
    if [[ "$created" != "$HOSTONLY_IF" ]]; then
      warn "Toujours pas $HOSTONLY_IF (obtenu : $created). Reboote VirtualBox ou le host."
      exit 1
    fi
  fi

  VBoxManage hostonlyif ipconfig "$HOSTONLY_IF" \
    --ip "$HOSTONLY_IP" --netmask "$HOSTONLY_MASK"
  ok "$HOSTONLY_IF configuré : $HOSTONLY_IP/$HOSTONLY_MASK"
}

step "Vérification de l'interface host-only $HOSTONLY_IF"
ensure_hostonly_if

step "État initial des VMs"
for vm in "${VMS[@]}"; do
  state=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null \
    | awk -F= '/^VMState=/{gsub(/"/,"");print $2}')
  printf "  - %-15s %s\n" "$vm" "${state:-introuvable}"
done

step "Démarrage en mode GUI (3 fenêtres VirtualBox vont s'ouvrir)"
for vm in "${VMS[@]}"; do
  state=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null \
    | awk -F= '/^VMState=/{gsub(/"/,"");print $2}')
  if [[ "$state" == "running" ]]; then
    info "$vm déjà démarrée."
  else
    run VBoxManage startvm "$vm" --type gui >/dev/null
    ok "$vm lancée."
  fi
done

step "Attente que les 3 nœuds k3s soient Ready (jusqu'à 5 min)"
deadline=$((SECONDS + 300))
while (( SECONDS < deadline )); do
  ready=$(kubectl get nodes --no-headers 2>/dev/null \
    | awk '$2=="Ready"' | wc -l)
  if [[ "$ready" -eq 3 ]]; then
    ok "Cluster opérationnel."
    kubectl get nodes -o wide
    exit 0
  fi
  printf "."
  sleep 5
done
echo
warn "Timeout : les 3 nœuds ne sont pas tous Ready."
kubectl get nodes 2>/dev/null || true
exit 1

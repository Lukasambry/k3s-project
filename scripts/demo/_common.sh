# Helpers partagés par les scripts de démo. À sourcer en début de script :
#   source "$(dirname "$0")/_common.sh"
# Pour enchaîner sans pauses : DEMO_NO_PAUSE=1 ./scripts/demo/test-xxx.sh

set -euo pipefail

C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'
C_DIM=$'\033[2m'
C_RESET=$'\033[0m'

step() {
  echo
  echo "${C_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
  echo "${C_BLUE}▶ $*${C_RESET}"
  echo "${C_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
  if [[ -z "${DEMO_NO_PAUSE:-}" ]]; then
    read -rp "  ${C_DIM}(Entrée pour exécuter)${C_RESET} " _ || true
  fi
}

run() {
  echo "${C_DIM}\$ $*${C_RESET}"
  "$@"
}

info() { echo "${C_YELLOW}ℹ $*${C_RESET}"; }
ok()   { echo "${C_GREEN}✓ $*${C_RESET}"; }
warn() { echo "${C_RED}✗ $*${C_RESET}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { warn "Commande requise absente : $1"; exit 1; }
}

require_cluster() {
  require_cmd kubectl
  if ! kubectl get ns todo-app >/dev/null 2>&1; then
    warn "Namespace todo-app introuvable. Le cluster est-il déployé ?"
    exit 1
  fi
}

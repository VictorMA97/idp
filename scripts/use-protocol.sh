#!/usr/bin/env bash
# Cambia los remotos de idp y de los tres repos entre SSH y HTTPS (solo configuración local de git).
# Uso: scripts/use-protocol.sh ssh|https        (o: make use-ssh / make use-https)
# Los submódulos usan URLs relativas en .gitmodules, así que basta con cambiar el origin de idp y sincronizar.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
proto="${1:-}"
[[ "$proto" == "ssh" || "$proto" == "https" ]] || die "Uso: scripts/use-protocol.sh ssh|https"
cd "$ROOT_DIR"

url="$(git config --get remote.origin.url 2>/dev/null)" || die "idp no tiene remoto 'origin'"
# Extrae <usuario> de git@github.com:<usuario>/idp.git, ssh://git@github.com/<usuario>/idp.git o https://github.com/<usuario>/idp.git
if [[ "$url" =~ ^(ssh://)?git@github\.com[:/]([^/]+)/[^/]+$ ]]; then owner="${BASH_REMATCH[2]}"
elif [[ "$url" =~ ^https://github\.com/([^/]+)/[^/]+$ ]]; then owner="${BASH_REMATCH[1]}"
else die "No reconozco la URL de origin: $url (se esperaba github.com)"
fi

base_for() { if [[ "$proto" == ssh ]]; then echo "git@github.com:$owner"; else echo "https://github.com/$owner"; fi; }
base="$(base_for)"

git remote set-url origin "$base/idp.git"
log "idp: origin -> $base/idp.git"
git submodule sync --quiet
for r in "${REPOS[@]}"; do
  if [[ -e "$r/.git" ]]; then
    git -C "$r" remote set-url origin "$base/$r.git"
    log "$r: origin -> $base/$r.git"
  else
    warn "$r: sin descargar (make init); se usará $base/$r.git al descargarlo"
  fi
done
[[ "$proto" == ssh ]] && log "Comprueba la clave con: make ssh-check"

#!/usr/bin/env bash
# Comprueba que git por SSH funciona contra GitHub: protocolo de los remotos, clave cargada y acceso a cada repo.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"
fails=0
ok()   { printf '  \033[1;32mOK\033[0m    %s\n' "$*"; }
fail() { printf '  \033[1;31mFALLO\033[0m %s\n' "$*"; fails=$((fails+1)); }

log "Remotos"
for dir in . "${REPOS[@]}"; do
  [[ -e "$dir/.git" ]] || { fail "$dir: no descargado (make init)"; continue; }
  u="$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)"
  if [[ "$u" == git@github.com:* || "$u" == ssh://git@github.com/* ]]; then ok "$dir -> $u"; else fail "$dir usa $u (ejecuta: make use-ssh)"; fi
done

log "Clave SSH"
command -v ssh >/dev/null || die "Falta ssh (sudo apt install -y openssh-client)"
out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
if grep -q "successfully authenticated" <<<"$out"; then ok "$(head -1 <<<"$out")"
else
  fail "GitHub no acepta tu clave: $(head -1 <<<"$out")"
  echo "    Crea una clave:  ssh-keygen -t ed25519 -C \"tu@correo\"   y añade ~/.ssh/id_ed25519.pub en https://github.com/settings/keys"
  echo "    Cárgala:         eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
fi

log "Acceso a los repos (git ls-remote)"
for dir in . "${REPOS[@]}"; do
  [[ -e "$dir/.git" ]] || continue
  if git -C "$dir" ls-remote --exit-code origin HEAD >/dev/null 2>&1; then ok "$dir"; else fail "$dir: no se puede leer el remoto"; fi
done
(( fails == 0 )) || die "$fails comprobación(es) fallida(s)"
log "Todo correcto"

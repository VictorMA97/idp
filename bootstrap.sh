#!/usr/bin/env bash
# Convierte esta carpeta en el repo `idp` con los tres repos como submódulos. Se ejecuta UNA vez.
# Uso: ./bootstrap.sh <usuario-de-github>
# - Si idp-platform, idp-backstage o idp-sample-app ya existen aquí (clones tuyos), se usan tal cual,
#   con sus cambios sin commit incluidos (no se tocan).
# - Si faltan, se clonan de https://github.com/<usuario>/<repo>.git
# - Los submódulos usan URLs RELATIVAS (../idp-platform.git): siguen a la cuenta donde esté idp.
# No sube nada: al final te dice cómo crear el repo en GitHub y hacer push.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source scripts/lib.sh

OWNER="${1:-}"
[[ -n "$OWNER" ]] || die "Uso: ./bootstrap.sh <usuario-de-github>"
command -v git >/dev/null || die "Falta git"

# URL base: el repo idp vive junto a los otros (https://github.com/<usuario>/idp.git)
BASE="${IDP_BASE_URL:-https://github.com/$OWNER}"

for r in "${REPOS[@]}"; do
  if [[ -e "$r/.git" ]]; then
    log "$r: ya existe, se usa tal cual"
  elif [[ -e "$r" ]]; then
    die "$r existe pero no es un repo git"
  else
    log "$r: clonando"
    git clone "$BASE/$r.git" "$r"
  fi
done

git init -q -b main
git remote add origin "$BASE/idp.git"
for r in "${REPOS[@]}"; do
  git submodule add "../$r.git" "$r" >/dev/null
  log "submódulo añadido: $r"
done
chmod +x scripts/*.sh bootstrap.sh
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-$(git config user.name || echo idp)}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo idp@localhost)}" \
    commit -q -m "chore: repo paraguas idp con submódulos"
log "Repo idp creado en esta carpeta (rama main)."
cat <<MSG

Siguiente paso: crea el repo VACÍO 'idp' en GitHub y súbelo:
  gh repo create $OWNER/idp --public --source=. --remote=origin --push      # si tienes gh
  # o, a mano: crea https://github.com/$OWNER/idp (sin README) y luego:
  git push -u origin main

Para clonarlo en otro equipo:
  git clone --recurse-submodules https://github.com/$OWNER/idp.git && cd idp && make init
MSG

#!/usr/bin/env bash
# Convierte esta carpeta en el repo `idp` con los tres repos como submódulos. Se ejecuta UNA vez.
# Uso: ./bootstrap.sh <usuario-de-github> [--ssh]
#   --ssh  remotos git@github.com:<usuario>/... (también se activa solo si tus clones ya usan SSH)
# - Si idp-platform, idp-backstage o idp-sample-app ya existen aquí (clones tuyos), se usan tal cual,
#   con sus cambios sin commit incluidos (no se tocan).
# - Si faltan, se clonan de https://github.com/<usuario>/<repo>.git
# - Los submódulos usan URLs RELATIVAS (../idp-platform.git): siguen a la cuenta donde esté idp.
# No sube nada: al final te dice cómo crear el repo en GitHub y hacer push.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source scripts/lib.sh

OWNER=""; SSH="${SSH:-0}"
for a in "$@"; do case "$a" in --ssh) SSH=1 ;; -*) die "Opción desconocida: $a" ;; *) OWNER="$a" ;; esac; done
[[ -n "$OWNER" ]] || die "Uso: ./bootstrap.sh <usuario-de-github> [--ssh]"
# Si algún clon existente ya usa SSH, se mantiene el protocolo
for r in "${REPOS[@]}"; do
  [[ -e "$r/.git" ]] && [[ "$(git -C "$r" config --get remote.origin.url 2>/dev/null || true)" == git@github.com:* ]] && SSH=1
done
command -v git >/dev/null || die "Falta git"
[[ -e .git ]] && die "Esta carpeta ya es un repo git: no hace falta bootstrap (usa 'make init' en un clon nuevo)."

# URL base: el repo idp vive junto a los otros (https://github.com/<usuario>/idp.git)
if [[ "$SSH" == 1 ]]; then BASE="${IDP_BASE_URL:-git@github.com:$OWNER}"; else BASE="${IDP_BASE_URL:-https://github.com/$OWNER}"; fi
log "Protocolo: $([[ "$SSH" == 1 ]] && echo SSH || echo HTTPS) ($BASE)"

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
  # crea https://github.com/$OWNER/idp (sin README) y luego:
  git push -u origin main
  # (con gh: gh repo create $OWNER/idp --public   y después el git push de arriba)

Para clonarlo en otro equipo:
  git clone --recurse-submodules $BASE/idp.git && cd idp && make init
MSG

#!/usr/bin/env bash
# Deshace la puesta en marcha en los tres repos y destruye los clústeres, para empezar de cero.
# Muestra el plan de cada repo, pide UNA confirmación y ejecuta: primero los repos que solo cambian
# ficheros (idp-backstage, idp-sample-app) y al final idp-platform (que además borra los clústeres).
# Variables: DRY_RUN=1 (solo planes), FORCE=1 (sin preguntar), KEEP_CLUSTERS=1, KEEP_SERVICES=1.
# No hace commit ni push, no toca GHCR ni GitHub.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_repos
cd "$ROOT_DIR"

for r in idp-backstage idp-sample-app idp-platform; do
  printf '\n\033[1m── %s ──\033[0m\n' "$r"
  DRY_RUN=1 "./$r/scripts/rollback.sh" || true
done
[[ "${DRY_RUN:-0}" == "1" ]] && { log "DRY_RUN=1: no se ha cambiado nada"; exit 0; }

if [[ "${FORCE:-0}" != "1" ]]; then
  [[ -t 0 ]] || die "Hace falta confirmar y no hay terminal. Repite con FORCE=1 (o DRY_RUN=1)."
  read -r -p "¿Ejecutar el rollback de los tres repos? [y/N] " a
  [[ "$a" =~ ^[yYsS]$ ]] || { echo "Cancelado."; exit 1; }
fi

for r in idp-backstage idp-sample-app idp-platform; do
  printf '\n\033[1m── %s ──\033[0m\n' "$r"
  DRY_RUN=0 FORCE=1 "./$r/scripts/rollback.sh"
done
echo
log "Hecho. Revisa 'make repos' y súbelo: make commit MSG='volver a la plantilla' && make push"
warn "Para volver a empezar: make configure OWNER=<usuario>, commit y push, y las etapas del README de idp-platform."

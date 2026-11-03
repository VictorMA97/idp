#!/usr/bin/env bash
# Pone tu cuenta de GitHub en los repos: políticas de Kyverno (idp-platform), descubrimiento, catálogo,
# plantilla y node_id (idp-backstage) y la URL del repo de la plataforma para Argo CD.
# Uso: scripts/configure.sh <usuario>      (o: make configure OWNER=<usuario>)
# Solo edita ficheros; luego: make commit MSG='configura mi cuenta' && make push
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
OWNER="${1:-}"
[[ -n "$OWNER" ]] || die "Uso: scripts/configure.sh <usuario-de-github>"
require_repos
log "idp-platform: cuenta en las políticas de Kyverno"
"$ROOT_DIR/idp-platform/scripts/set-owner.sh" "$OWNER"
log "idp-platform: URL del repo para Argo CD"
make --no-print-directory -C "$ROOT_DIR/idp-platform" set-repo REPO_URL="https://github.com/$OWNER/idp-platform.git"
log "idp-backstage: cuenta, catálogo, plantilla y node_id"
"$ROOT_DIR/idp-backstage/scripts/set-owner.sh" "$OWNER"
warn "Revisa con 'make repos' y súbelo con: make commit MSG='configura mi cuenta' && make push"

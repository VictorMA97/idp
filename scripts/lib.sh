#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS=(idp-platform idp-backstage idp-sample-app)
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# Falla si un submódulo no está descargado
require_repos() {
  local r
  for r in "${REPOS[@]}"; do
    [[ -e "$ROOT_DIR/$r/.git" ]] || die "Falta el submódulo $r. Ejecuta: make init"
  done
}
# Rama por defecto de un repo (origin/HEAD; si no, main o master)
default_branch() {
  local r="$1" b
  b="$(git -C "$ROOT_DIR/$r" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "$b" ]]; then
    for b in main master; do git -C "$ROOT_DIR/$r" show-ref --verify --quiet "refs/remotes/origin/$b" && break || b=""; done
  fi
  echo "$b"
}
# Si el submódulo está en HEAD desacoplado (tras 'submodule update'), vuelve a su rama por defecto
ensure_branch() {
  local r="$1" b
  git -C "$ROOT_DIR/$r" symbolic-ref --quiet HEAD >/dev/null 2>&1 && return 0
  b="$(default_branch "$r")"
  [[ -n "$b" ]] || { warn "$r: no sé qué rama usar"; return 1; }
  git -C "$ROOT_DIR/$r" checkout -q "$b"
}

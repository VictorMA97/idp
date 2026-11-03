#!/usr/bin/env bash
# Operaciones de git sobre los tres repos y sobre el repo idp (que guarda a qué commit apunta cada uno).
# Uso: scripts/git-all.sh status | pull | commit "mensaje" | push
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"
action="${1:-status}"

case "$action" in
  status)
    require_repos
    for r in "${REPOS[@]}"; do
      printf '\033[1m%s\033[0m  (%s)\n' "$r" "$(git -C "$r" rev-parse --abbrev-ref HEAD)"
      git -C "$r" status -sb | sed 's/^/    /'
    done
    printf '\033[1midp\033[0m  (punteros de submódulos)\n'
    git status -sb | sed 's/^/    /'
    ;;
  pull)
    git submodule update --init
    for r in "${REPOS[@]}"; do
      ensure_branch "$r" || continue
      log "$r: git pull --ff-only"
      git -C "$r" pull --ff-only || warn "$r: no se pudo avanzar (cambios locales o ramas divergentes); revísalo a mano"
    done
    log "Para fijar en idp los commits nuevos: make commit MSG='...' && make push"
    ;;
  commit)
    msg="${2:-}"; [[ -n "$msg" ]] || die "Uso: scripts/git-all.sh commit \"mensaje\""
    require_repos
    for r in "${REPOS[@]}"; do
      ensure_branch "$r" || continue
      if [[ -n "$(git -C "$r" status --porcelain)" ]]; then
        git -C "$r" add -A && git -C "$r" commit -q -m "$msg" && log "$r: commit hecho"
      else
        echo "  $r: sin cambios"
      fi
    done
    git add -A "${REPOS[@]}" .gitmodules 2>/dev/null || true
    git add -A
    if git diff --cached --quiet; then echo "  idp: sin cambios"; else git commit -q -m "$msg" && log "idp: commit hecho"; fi
    ;;
  push)
    require_repos
    for r in "${REPOS[@]}"; do
      ensure_branch "$r" || continue
      log "$r: git push"
      git -C "$r" push || warn "$r: el push falló"
    done
    log "idp: git push"
    git push
    ;;
  *) die "Uso: scripts/git-all.sh status | pull | commit \"mensaje\" | push" ;;
esac

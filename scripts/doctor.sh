#!/usr/bin/env bash
# Comprueba que tu equipo tiene todo lo necesario para usar idp, y dice cómo instalar lo que falte.
# Uso: scripts/doctor.sh      (o: make doctor)      Sale con error si falta algo imprescindible.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
set +e
cd "$ROOT_DIR"

req_fail=0; warns=0
G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'; D=$'\033[2m'; N=$'\033[0m'
row()  { printf '  %s%-9s%s %-12s %-22s %s\n' "$1" "$2" "$N" "$3" "$4" "$5"; }
ok()   { row "$G" "OK" "$1" "$2" "$3"; }
miss() { row "$R" "FALTA" "$1" "-" "$2"; req_fail=$((req_fail+1)); }
rec()  { row "$Y" "RECOMEND." "$1" "-" "$2"; warns=$((warns+1)); }
opt()  { row "$D" "opcional" "$1" "-" "$2"; }
ver()  { # primer número de versión x.y[.z] de la salida de un comando
  "$@" 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }
ge()   { # ge <versión> <mínima>: ¿versión >= mínima? (compara con sort -V)
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

# check <binario> <comando de versión...> --min <x.y> --hint "<cómo instalar>" [--kind req|rec|opt] [--why "<para qué>"]
check() {
  local bin="$1"; shift; local cmd=() min="" hint="" kind=req why=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --min) min="$2"; shift 2;; --hint) hint="$2"; shift 2;; --kind) kind="$2"; shift 2;; --why) why="$2"; shift 2;; *) cmd+=("$1"); shift;; esac
  done
  if ! command -v "$bin" >/dev/null 2>&1; then
    case "$kind" in req) miss "$bin" "$hint";; rec) rec "$bin" "$hint${why:+  ($why)}";; *) opt "$bin" "$hint${why:+  ($why)}";; esac
    return
  fi
  local v; v="$(ver "${cmd[@]}")"
  if [[ -n "$min" && -n "$v" ]] && ! ge "$v" "$min"; then
    case "$kind" in req) miss "$bin" "versión $v demasiado antigua (mínimo $min). $hint";; *) rec "$bin" "versión $v (mínimo $min). $hint";; esac
    return
  fi
  ok "$bin" "${v:-instalado}" "${why}"
}

printf '\n\033[1mHerramientas imprescindibles\033[0m  (make up, make root, make backstage ...)\n'
check git       git --version        --hint "sudo apt install -y git"
check make      make --version       --hint "sudo apt install -y make"
check curl      curl --version       --hint "sudo apt install -y curl"
check openssl   openssl version      --hint "sudo apt install -y openssl" --why "secretos de Backstage"
check docker    docker --version     --hint "Docker Desktop con integración WSL2, o: curl -fsSL https://get.docker.com | sh"
check k3d       k3d version          --min 5.0 --hint "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
check kubectl   kubectl version --client --min 1.28 --hint "https://kubernetes.io/docs/tasks/tools/ (o: sudo snap install kubectl --classic)"

printf '\n\033[1mDocker\033[0m\n'
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "daemon" "responde" ""
  else
    out="$(docker info 2>&1 | head -2 | tr '\n' ' ')"
    if grep -qi "permission denied" <<<"$out"; then
      miss "daemon" "sin permisos: sudo usermod -aG docker \$USER y reabre la terminal (o activa la integración WSL en Docker Desktop)"
    else
      miss "daemon" "Docker no responde. Arranca Docker Desktop (con integración WSL2 activa) o: sudo service docker start"
    fi
  fi
fi

printf '\n\033[1mGit y GitHub\033[0m\n'
[[ -n "$(git config --get user.name)" && -n "$(git config --get user.email)" ]] \
  && ok "git config" "$(git config --get user.name)" "$(git config --get user.email)" \
  || rec "git config" "git config --global user.name \"Tu Nombre\" && git config --global user.email \"tu@correo\""
if command -v ssh >/dev/null 2>&1; then
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)"
  if grep -q "successfully authenticated" <<<"$out"; then ok "ssh" "clave aceptada" "$(grep -oE 'Hi [^!]+' <<<"$out")"
  else rec "ssh" "GitHub no acepta tu clave por SSH: ver 'make ssh-check' (solo necesario si usas remotos SSH)"; fi
else
  rec "ssh" "sudo apt install -y openssh-client (solo necesario si usas remotos SSH)"
fi
check gh gh --version --kind opt --hint "https://cli.github.com (crear repos y consultar node_id)"

printf '\n\033[1mDesarrollo local de Backstage\033[0m  (solo para yarn start / tests; el clúster no lo necesita)\n'
if command -v node >/dev/null 2>&1; then
  nv="$(node --version | tr -d v)"; nmaj="${nv%%.*}"
  if [[ "$nmaj" == 22 || "$nmaj" == 24 ]]; then ok "node" "$nv" "Backstage exige 22 o 24"
  else opt "node" "versión $nv; Backstage exige 22 o 24 (nvm install 22)"; fi
else opt "node" "no instalado; Backstage exige 22 o 24 (https://github.com/nvm-sh/nvm)"; fi
if command -v yarn >/dev/null 2>&1; then
  yv="$(yarn --version 2>/dev/null)"
  if [[ "${yv%%.*}" -ge 4 ]]; then ok "yarn" "$yv" "el repo fija yarn 4"
  else opt "yarn" "versión $yv; Backstage usa yarn 4: ejecuta 'corepack enable' dentro de idp-backstage"; fi
else opt "yarn" "no instalado: corepack enable (viene con Node)"; fi

printf '\n\033[1mEntorno\033[0m\n'
if grep -qi microsoft /proc/version 2>/dev/null; then
  ok "WSL" "detectado" ""
  case "$ROOT_DIR" in /mnt/*) rec "ubicación" "idp está en $ROOT_DIR (disco de Windows): muévelo a ~/ dentro de WSL, el I/O es mucho más lento";; *) ok "ubicación" "$ROOT_DIR" "dentro de WSL";; esac
else
  opt "WSL" "no detectado (si usas Linux o macOS nativo no hace falta)"
fi
mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0) / 1024 / 1024 ))
if (( mem_gb >= 14 )); then ok "memoria" "~${mem_gb} GB" "tres clústeres k3d"
else rec "memoria" "~${mem_gb} GB visibles; se recomiendan 14 o más (ver idp-platform/docs/wslconfig.example)"; fi

printf '\n\033[1mRepos\033[0m\n'
for r in "${REPOS[@]}"; do
  if [[ -e "$r/.git" ]]; then ok "$r" "descargado" "$(git -C "$r" config --get remote.origin.url 2>/dev/null)"
  else miss "$r" "submódulo sin descargar: make init"; fi
done

echo
if (( req_fail > 0 )); then
  printf '%s%d herramienta(s) imprescindible(s) sin resolver.%s Instálalas y repite: make doctor\n' "$R" "$req_fail" "$N"; exit 1
fi
(( warns > 0 )) && printf '%sTodo lo imprescindible está. %d recomendación(es) arriba.%s\n' "$Y" "$warns" "$N" || printf '%sTodo listo.%s\n' "$G" "$N"
echo "Siguiente: make preflight (comprueba además puertos libres) y las etapas del README de idp-platform."

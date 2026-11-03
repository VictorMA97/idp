# idp

Repo paraguas de la plataforma de desarrolladores (IDP). Reúne, como **submódulos de git**, los tres repos y
permite manejarlo todo desde aquí con `make`.

| Submódulo | Qué es |
|---|---|
| [`idp-platform`](idp-platform) | Infraestructura (k3d, Argo CD, Kyverno), scripts y documentación de puesta en marcha |
| [`idp-backstage`](idp-backstage) | Portal Backstage, su pipeline y la plantilla de servicios |
| [`idp-sample-app`](idp-sample-app) | *(Opcional)* app de ejemplo con su pipeline |

Los servicios `svc-*` que crea Backstage son repos aparte y **no** son submódulos.

## Cómo encaja con el resto

- Cada submódulo sigue siendo un repo independiente. **Argo CD lee `idp-platform` (y los repos de cada
  servicio) directamente de GitHub, y el CI corre en cada repo.** Este repo no interviene en ninguno de los dos.
- `idp` solo guarda *a qué commit* apunta cada submódulo. Cuando el CI de `idp-backstage` escribe un digest
  nuevo, `idp` sigue apuntando al commit anterior hasta que ejecutes `make pull`, `make commit` y `make push`.
- Los submódulos usan URLs **relativas** (`../idp-platform.git`): siempre apuntan a la misma cuenta en la que
  esté `idp`, también en un fork.

## Crearlo por primera vez (una sola vez)

En la carpeta donde ya tienes los tres repos clonados (o vacía: los clona), con estos ficheros dentro:

```bash
./bootstrap.sh <usuario>        # git init + submódulos + primer commit; no sube nada
gh repo create <usuario>/idp --public --source=. --remote=origin --push
# sin gh: crea https://github.com/<usuario>/idp vacío y: git push -u origin main
```

Tus clones existentes se usan tal cual, con sus cambios sin commit incluidos.

## Clonarlo en otro equipo

```bash
git clone --recurse-submodules https://github.com/<usuario>/idp.git     # o por SSH: git@github.com:<usuario>/idp.git
cd idp && make init
```

## SSH

Todo el git local (clonar, submódulos, `make pull`, `make push`) funciona por SSH:

```bash
./bootstrap.sh <usuario> --ssh     # al crearlo (se activa solo si tus clones ya usan SSH)
make use-ssh                       # o, si ya lo tienes en HTTPS: cambia los remotos de idp y de los 3 repos
make ssh-check                     # comprueba protocolo de los remotos, clave cargada y acceso a cada repo
make use-https                     # para volver
```

Los submódulos usan URLs relativas, así que siguen el protocolo del `origin` de `idp`. Necesitas una clave SSH
añadida a <https://github.com/settings/keys> y cargada en el agente (`ssh-add`); `make ssh-check` te dice qué falta.

**Argo CD sigue usando HTTPS**, con los repos públicos y sin credenciales: no tiene claves SSH. Por eso
`make set-repo`, `make backstage` y `make sample-app` convierten cualquier URL SSH a HTTPS en los manifiestos
(lo que va a Git y lee Argo). Si algún día un repo fuera privado, habría que darle a Argo CD una deploy key.

## Uso diario

| Comando | Qué hace |
|---|---|
| `make doctor` | Comprueba las herramientas instaladas (git, make, curl, openssl, docker y su daemon, k3d, kubectl; además ssh, gh, node y yarn) y dice cómo instalar lo que falte. Úsalo antes de `make up`; después, `make preflight` comprueba los puertos libres |
| `make help` | Todos los comandos (los de aquí y los de `idp-platform`) |
| `make configure OWNER=<usuario>` | Pone tu cuenta en los tres repos (Kyverno, descubrimiento, catálogo, `node_id`, URL de Argo CD) |
| `make use-ssh` / `make use-https` / `make ssh-check` | Protocolo de los remotos y comprobación de la clave SSH |
| `make repos` | `git status` de los tres repos y de los punteros de `idp` |
| `make pull` | Trae lo nuevo de los tres repos (p. ej. el digest que escribe el CI) |
| `make commit MSG="..."` | Commit en cada repo con cambios y luego en `idp` |
| `make push` | Push de los tres repos y de `idp` |
| `make rollback` (alias `rollout`) | Deshace la puesta en marcha en los tres repos **y borra los clústeres**: plan de cada repo, una confirmación. Opciones: `DRY_RUN=1`, `FORCE=1`, `KEEP_CLUSTERS=1`, `KEEP_SERVICES=1` |
| `make <cualquier otro>` | Se reenvía a `idp-platform`: `make up`, `make root`, `make backstage-secrets`, `make backstage BACKSTAGE_REPO_URL=...`, `make status`, `make urls`, `make policies-mode MODE=deny`, `make test-policies` ... |

## Puesta en marcha completa

0. `make doctor`: comprueba que tienes las herramientas.
1. Prerrequisitos y Etapas 1 a 6: [`idp-platform/README.md`](idp-platform/README.md).
2. Los comandos de ese README se ejecutan igual desde aquí (`make up`, `make root`...).
3. Para tu cuenta: `make configure OWNER=<usuario>` sustituye los pasos manuales de `set-owner` y `set-repo`;
   después `make commit MSG='configura mi cuenta' && make push`.

## Notas de git con submódulos

- Tras `git clone --recurse-submodules` o `make init`, cada submódulo queda en *HEAD desacoplado*.
  `make pull` y `make commit` los devuelven solos a su rama por defecto.
- Un cambio dentro de un submódulo hay que subirlo **dos veces**: en el propio repo y luego el puntero en `idp`.
  `make commit` y `make push` hacen las dos cosas.
- `make repos` mostrando `M idp-backstage` significa que ese repo tiene commits que `idp` aún no registra.
- No uses `git add -A` dentro de `idp` esperando guardar cambios de un submódulo: solo registra el puntero.

## Problemas

| Síntoma | Causa | Solución |
|---|---|---|
| `Falta el submódulo ...` | Clonado sin `--recurse-submodules` | `make init` |
| `make pull`: «no se pudo avanzar» | Cambios locales o ramas divergentes en ese repo | `cd <repo>`, resuélvelo con git y repite |
| `make push` falla en un repo | Sin permisos o la rama remota avanzó | `make pull` y repite |
| `Permission denied (publickey)` al hacer pull/push | GitHub no conoce tu clave o no está cargada en el agente | `make ssh-check` y sigue sus pasos |
| `make configure` no obtiene el `node_id` | Límite de la API de GitHub o sin red | `NODE_ID=$(gh api users/<usuario> --jq .node_id) make configure OWNER=<usuario>` |

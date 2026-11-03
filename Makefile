# Punto de entrada único. Los repos idp-platform, idp-backstage e idp-sample-app son submódulos:
# cada uno sigue siendo un repo independiente (Argo CD y el CI trabajan contra ellos, no contra este).
# Lo que no se define aquí se reenvía a idp-platform: `make up`, `make root`, `make backstage ...`, etc.
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help init pull repos commit push configure use-ssh use-https ssh-check rollback rollout

help: ## Esta ayuda
	@echo "idp: repo paraguas (submódulos: idp-platform, idp-backstage, idp-sample-app)"
	@echo
	@awk -F':.*## ' '/^[a-z-]+:.*## /{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Todo lo demás se reenvía a idp-platform (make up, make root, make backstage-secrets, ...):"
	@$(MAKE) --no-print-directory -C idp-platform help | grep -v -E 'rollback|rollout|set-owner'

init: ## Descarga los submódulos y deja los scripts ejecutables
	@git submodule update --init
	@chmod +x scripts/*.sh idp-platform/scripts/*.sh idp-backstage/scripts/*.sh idp-sample-app/scripts/*.sh 2>/dev/null || true

pull: ## Trae los cambios nuevos de los tres repos (p. ej. el digest que escribe el CI)
	@./scripts/git-all.sh pull

repos: ## Estado de git de los tres repos y de los punteros de idp
	@./scripts/git-all.sh status

commit: ## Commit en cada repo con cambios y en idp: make commit MSG="..."
	@./scripts/git-all.sh commit "$(MSG)"

push: ## Push de los tres repos y de idp
	@./scripts/git-all.sh push

configure: ## Pone tu cuenta de GitHub en todos los repos: make configure OWNER=<usuario>
	@./scripts/configure.sh "$(OWNER)"

use-ssh: ## Cambia los remotos de idp y los 3 repos a SSH (git@github.com:...)
	@./scripts/use-protocol.sh ssh

use-https: ## Cambia los remotos de idp y los 3 repos a HTTPS
	@./scripts/use-protocol.sh https

ssh-check: ## Comprueba que git por SSH funciona (remotos, clave y acceso a cada repo)
	@./scripts/ssh-check.sh

rollback: ## Deshace la puesta en marcha en los tres repos y borra los clústeres [DRY_RUN=1] [FORCE=1] [KEEP_CLUSTERS=1] [KEEP_SERVICES=1]
	@./scripts/rollback-all.sh

rollout: rollback ## Alias de rollback

# Reenvío de cualquier otro objetivo a idp-platform (las variables, como REPO_URL=..., pasan solas)
%:
	@$(MAKE) --no-print-directory -C idp-platform $@

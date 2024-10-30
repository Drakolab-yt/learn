HAS_DOCKER:=$(shell command -v docker 2> /dev/null)
# Executables (local)
DOCKER_COMP = docker compose

# Docker containers
# Check if docker is present, allow usage of this makefile inside the containers
ifdef HAS_DOCKER
	PHP_CONT = $(DOCKER_COMP) exec php
	NODE_CONT = $(DOCKER_COMP) run --rm --service-ports assets
	DB_CONT = $(DOCKER_COMP) exec db
else
	PHP_CONT =
	NODE_CONT =
	DB_CONT =
endif

# Executables
PHP      = $(PHP_CONT) php
COMPOSER = $(PHP_CONT) composer
SYMFONY  = $(PHP_CONT) bin/console
NPM      = $(NODE_CONT) npm


.DEFAULT_GOAL = help # make without any arguments will exec help task

##  ✩  First step if you are new: Setup the project
##     If the project is already installed, it will be entirely destroy and rebuild from scratch
##
setup: ## Setup all the project for dev: docker hub, vendor, migrations, fixtures, etc
setup: downv build start.daemon vendor db/create db/import db/update translations/pull # npm/install npm/dev
.PHONY: setup

ci_setup: ci_start vendor db/update # npm/install npm/dev
.PHONY: ci_setup

##
## ✩✩  Update the project (no need if you just setup)
##     This is the every day command to update the project installation on current sources (after pull or branch switch for ex.)
##
update: ## Same as setup but without destroying things that exist, idem potent
update: build start.daemon vendor db/update translations/pull # npm/install npm/dev
.PHONY: update

update@dist: vendor db/update translations/pull # npm/install npm/dev
	php bin/console fos:js-routing:dump --format=json
	php bin/console cache:clear
.PHONY: update@dist

##
## ✩✩✩ Start the docker hub the way you left it
##     make stop, to stop the hub
##
start: ## Start the docker hub
	$(DOCKER_COMP) up --remove-orphans
.PHONY: start

start.daemon: ## Start the docker hub in detached mode (no logs displayed)
	$(DOCKER_COMP) up -d --remove-orphans
.PHONY: start

ci_start:
	$(DOCKER_COMP) up --detach --remove-orphans db php nginx
.PHONY: ci_start

worker/start:
	$(SYMFONY) messenger:consume async -vv
.PHONY: worker

worker/stop:
	$(SYMFONY) messenger:stop-workers
.PHONY: worker/stop

##
## —— 🐳 Docker ——————————————————————————————————————————————————————————
##
build: ## Builds the Docker images (with cache if any)
	$(DOCKER_COMP) build --pull
.PHONY: build

rebuild: ## Builds the Docker images from scratch without cache
	$(DOCKER_COMP) build --pull --no-cache
.PHONY: rebuild

stop: ## Level 1. Stop the docker hub without touching anything
	$(DOCKER_COMP) stop
.PHONY: stop

down: ## Level 2. + destroy containers and networking
	$(DOCKER_COMP) down --remove-orphans
.PHONY: down

downv: ## Level 3. + destroy all volumes.
	$(DOCKER_COMP) down --remove-orphans --volumes
.PHONY: downv

uninstall: ## Level 4. + remove project docker images
	$(DOCKER_COMP) down --remove-orphans --volumes --rmi all
.PHONY: uninstall

logs: ## Show live logs, pass the parameter "s=" to select the service, example: make logs s=nginx
	@$(eval s ?=)
	$(DOCKER_COMP) logs --tail=100 --follow $(s)
.PHONY: logs

sh: ## Connect to a container, pass the parameter "s=" to select the service, example: make sh s=workers
	@$(eval s ?=)
	$(DOCKER_COMP) exec $(s) sh
.PHONY: sh

php: ## Short cut to connect to the php container, equivalent to make sh s=php
php: s=php
php: sh
.PHONY: php

##
## —— 🐬 Database️ ——————————————————————————————————————————————————————————
##
#db/import: ## Import a sql file, example: make db/import FILE=fixtures/file.sql
#	$(DOCKER_COMP) exec -T database psql -d app -U app < $(FILE)
#.PHONY: db/import

db/update: db/create ## Update the database to current migrations and fixtures
	$(SYMFONY) doctrine:migrations:migrate --no-interaction
.PHONY: db/update

db/diff: ## Generate a doctrine migration from the diff with the current schema
	$(SYMFONY) doctrine:migrations:diff
.PHONY: db/diff

db/fixtures: ## Purge database and insert fresh fixtures
	$(SYMFONY) doctrine:fixtures:load --ansi --no-interaction
.PHONY: db/fixtures

db/create: ## Create empty database
	$(SYMFONY) doctrine:database:create --if-not-exists
.PHONY: db/create

db/drop: ## Delete database
	$(SYMFONY) doctrine:schema:drop --force
	$(SYMFONY) doctrine:database:drop --force
.PHONY: db/drop

db/reset: ## Delete database and create it again
db/reset: db/drop db/create db/update db/fixtures
.PHONY: db/reset

##
## —— 🧙 Composer ——————————————————————————————————————————————————————————
##
composer: ## Run composer, pass the parameter "c=" to run a given command, example: make composer c='req symfony/orm-pack'
	@$(eval c ?=)
	@$(COMPOSER) $(c)
.PHONY: composer

vendor: ## Install vendors according to the current composer.lock file for a dev environment
vendor: c=install --prefer-dist --no-interaction
vendor: composer
.PHONY: vendor

##
## —— 🎵 Symfony ——————————————————————————————————————————————————————————
##
sf: ## List all Symfony commands or pass the parameter "c=" to run a given command, example: make sf c=about
	@$(eval c ?=)
	@$(SYMFONY) $(c)
.PHONY: sf

cc: c=cache:clear ## Clear the cache
cc: sf
.PHONY: cc

##
## —— 📦 Services ——————————————————————————————————————————————————————————
##

translations/push: ## Push all translation keys to Loco
	$(SYMFONY) translation:push loco
.PHONY: translations/push

translations/pull: ## Pull all translation keys from Loco
	$(SYMFONY) translation:pull loco --force
.PHONY: translations/pull

##
## —— 🧶 Front ——————————————————————————————————————————————————————————
##

node: ## Start a temporary node container and connect to it
	$(NODE_CONT) sh
.PHONY: node

npm/install: ## npm install
	$(NPM) install -no-audit
.PHONY: npm/install

npm/dev: ## Build assets for dev
	$(NPM) run dev
.PHONY: npm/dev

npm/dev-server: ## Start webpack dev server for hot reloading (Not very functional right now, prefer npm/watch)
	$(NPM) run dev-server
.PHONY: npm/dev-server

npm/watch: ## Watch and build assets for dev
	$(NPM) run watch
.PHONY: npm/watch

npm/prod: ## Build assets for prod
	$(NPM) run build
.PHONY: npm/prod

##
## —— 🐛 Tests ——————————————————————————————————————————————————————————
##
tests: ## Run the full test suite
tests: phpcs-check phpstan lint phpunit check_doctrine_schema check_composer check_php_dependencies
.PHONY: tests

phpcs: ## Run PHP CS fixer (config file ./php-cs-fixer.dist.php)
	$(PHP) vendor/bin/php-cs-fixer fix
.PHONY: phpcs

phpcs-check: ## Run PHP CS fixer without modifying the files (config file ./php-cs-fixer.dist.php)
	$(PHP) vendor/bin/php-cs-fixer fix --dry-run --diff
.PHONY: phpcs-check

phpstan: ## Run phpstan (config file ./phpstan.neon)
	$(PHP) vendor/bin/phpstan analyse --memory-limit 512M
.PHONY: phpstan

phpstan/baseline: ## Build phpstan baseline
	$(PHP) vendor/bin/phpstan analyse --memory-limit 512M --generate-baseline
.PHONY: phpstan/baseline

phpunit: ## Run phpunit test suite, pass command or options to phpunit: make phpunit c="--filter MyTest"
	@$(eval c ?=)
	$(PHP) bin/phpunit $(c)
.PHONY: phpunit

check_composer: ## Check the composer.json file
	$(COMPOSER) validate --no-check-publish
.PHONY: check_composer

check_php_dependencies: ## Check if php dependencies have known vulnerabilities
	$(PHP_CONT) local-php-security-checker
.PHONY: check_php_dependencies

lint: ## Check the syntax of Twig templates, config yaml files, etc
	$(SYMFONY) lint:twig templates/
	$(SYMFONY) lint:yaml config/
.PHONY: lint

check_doctrine_schema: ## Check the doctrine schema
	$(SYMFONY) doctrine:schema:validate
.PHONY: check_doctrine_schema

##
## —— 🐛 Déploiements ———————————————————————————————————————————————————
##

#
# Déploie sur le serveur de prod
#
deploy/prod:
	$(EXEC) vendor/bin/dep deploy stage=prod
.PHONY: deploy.prod

## Unlock deployment (prod)
unlock/prod:
	$(EXEC) vendor/bin/dep deploy:unlock stage=prod

## —————————————————————————————————————————————————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m %-25s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m ##/[33m/' && echo ""
.PHONY: help

# task used by deployer during deploy, see ./deploy.php
prod@build:
	composer dump-env prod
	composer run-script --no-dev post-install-cmd
	#bin/console translation:pull loco
	bin/console cache:clear
#	npm install --no-audit
#	npm run build

# Makefile — <PROJECT_NAME>
# Agents are autonomous: they may run every target here, including migrations and sqlc.
# Adapt DATABASE_URL / migration paths to the project.

MIGRATE       ?= migrate
SQLC          ?= sqlc
MIGRATIONS    ?= sql/migrations
DB_URL_DEV    ?= $(DATABASE_URL)
DB_URL_PROD   ?= $(DATABASE_URL_PROD)

.PHONY: help run build check lint test vet sqlc up-dev up-prod down-dev new-migration schema

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## --- Dev ---

run: ## Run the API
	go run ./cmd/api

build: ## Compile everything
	go build ./...

## --- Quality (run before declaring a task done) ---

check: vet test ## vet + tests

vet: ## go vet
	go vet ./...

test: ## Tests
	go test ./...

lint: ## golangci-lint + structural guards
	golangci-lint run ./...
	./scripts/check-cross-feature-imports.sh
	./scripts/check-file-size.sh
	./scripts/check-sommaire.sh

## --- Database (agents may run these) ---

sqlc: ## Generate internal/database/ from sql/queries/
	$(SQLC) generate

up-dev: ## Apply migrations in dev
	$(MIGRATE) -path $(MIGRATIONS) -database "$(DB_URL_DEV)" up

up-prod: ## Apply migrations in PRODUCTION — human only (agents blocked unless ALLOW_PROD=1)
	$(MIGRATE) -path $(MIGRATIONS) -database "$(DB_URL_PROD)" up

down-dev: ## Roll back 1 migration in dev
	$(MIGRATE) -path $(MIGRATIONS) -database "$(DB_URL_DEV)" down 1

new-migration: ## make new-migration name=create_users
	$(MIGRATE) create -ext sql -dir $(MIGRATIONS) -seq $(name)

schema: ## Regenerate sql/schema/ snapshot from the dev database (adapt to your tooling)
	@echo "Adapt this target to dump the dev schema into sql/schema/"

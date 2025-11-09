.PHONY: help all build test install installcheck clean fmt lint docker-build docker-test docker-shell

# Default Postgres version for local development
PG_VERSION ?= 17

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Standard targets for pgxnclient/pgxn compatibility
all: build ## Build the extension (standard target for packaging tools)

build: ## Build the extension for the default Postgres version
	cargo build --no-default-features --features pg$(PG_VERSION)

test: ## Run tests for the default Postgres version
	cargo pgrx test pg$(PG_VERSION)

test-all: ## Run tests for all supported Postgres versions
	@for v in 15 16 17; do \
		echo "Testing PostgreSQL $$v..."; \
		cargo pgrx test pg$$v || exit 1; \
	done

install: ## Install the extension for the default Postgres version
	cargo pgrx install --pg-config $$(brew --prefix postgresql@$(PG_VERSION))/bin/pg_config 2>/dev/null || \
	cargo pgrx install --pg-config /usr/lib/postgresql/$(PG_VERSION)/bin/pg_config

installcheck: test ## Run tests (standard target for packaging tools)

schema: ## Generate SQL schema for the default Postgres version
	cargo pgrx schema pg$(PG_VERSION) 2>/dev/null > sql/a5pg--0.6.1.sql

fmt: ## Format code with rustfmt
	cargo fmt --all

fmt-check: ## Check code formatting
	cargo fmt --all -- --check

lint: ## Run clippy linter
	cargo clippy --all-targets --no-default-features --features pg17 -- -D warnings

clean: ## Clean build artifacts
	cargo clean
	rm -rf target/

docker-build: ## Build Docker image for testing
	docker build -t a5pg:latest -f docker/Dockerfile .

docker-test: ## Run tests in Docker for all Postgres versions
	docker-compose -f docker/docker-compose.yml up --build --abort-on-container-exit

docker-shell: ## Open a shell in the Docker build environment
	docker run -it --rm -v $(PWD):/workspace -w /workspace a5pg:latest /bin/bash

docker-clean: ## Clean up Docker containers and images
	docker-compose -f docker/docker-compose.yml down -v
	docker rmi a5pg:latest || true

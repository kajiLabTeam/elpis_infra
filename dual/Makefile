# Makefile for managing Docker Compose services and running Go services locally

# Go services paths
CMD_PATH := ./cmd/server.go

# Define default targets
.PHONY: build up down restart clean help \
        run-proxy run-manager run-est-model run-est-api \
        restart-proxy restart-manager restart-est-api \
        run-test-est-api run-test-manager run-test-proxy run-test-web run-test-fingerprint \
        db-up db-down

# Default flags for running Go services locally
GO_FLAGS ?= -mode=local -port=8010

# General Docker Compose commands
build: ## Build the Docker images for all services
	docker compose build

up: ## Start all services in the background
	docker compose up -d

down: ## Stop all running services
	docker compose down

restart: down up ## Restart all services

clean: ## Stop all services and remove containers, networks, and volumes
	docker compose down --volumes --remove-orphans

# Run services locally
run-proxy: ## Run the proxy service locally with command-line flags
	@echo "Running Proxy Service Locally..."
	cd ./proxy && go run $(CMD_PATH)

run-manager: ## Run the manager service locally with command-line flags
	@echo "Running Manager Service Locally..."
	cd ./manager && go run $(CMD_PATH) $(GO_FLAGS)

run-est-model: ## Run the estimation model service locally with command-line flags
	@echo "Running Estimation Model Service Locally..."
	cd ./estimation && uv run src/estimation/main.py

run-est-api: ## Run the estimation API service locally with command-line flags
	@echo "Running Estimation API Service Locally..."
	cd ./estimation && uv run src/estimation/app.py 

# Restart individual services
restart-proxy: ## Restart only the proxy service
	docker compose restart proxy

restart-manager: ## Restart only the manager service
	docker compose restart manager

restart-est-api: ## Restart only the estimation API service
	docker compose restart estimation-api

# Database specific commands
db-up: ## Start only the database services
	docker compose up -d postgres_manager postgres_proxy

db-down: ## Stop and remove the database services and their volumes
	docker compose rm -s -v -f postgres_manager postgres_proxy

# Run end-to-end tests
run-test-est-api: ## Run the Estimation API e2e test
	bash ./e2e/est-api_test.sh

run-test-manager: ## Run the Manager e2e test
	bash ./e2e/manager_test.sh

run-test-proxy: ## Run the Proxy e2e test
	bash ./e2e/proxy_test.sh

run-test-web: ## Run the Web e2e test
	bash ./e2e/web_test.sh

run-test-fingerprint: ## Run the Fingerprint e2e test
	bash ./e2e/fingerprint_test.sh

# Help message
help: ## Display this help message
	@echo "Usage: make [target] [GO_FLAGS='-mode=local -port=8010']"
	@echo
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

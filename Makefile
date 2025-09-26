# Prosora Ghost Blog CMS - Makefile
# Convenient commands for managing the Ghost CMS deployment

.PHONY: help install start stop restart status logs backup restore update health clean deploy

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

# Project configuration
PROJECT_NAME := prosora-ghost-cms
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env

help: ## Show this help message
	@echo "$(BLUE)Prosora Ghost Blog CMS - Management Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  make install     # Initial setup and deployment"
	@echo "  make start       # Start all services"
	@echo "  make logs        # View logs from all services"
	@echo "  make backup      # Create a backup"
	@echo "  make health      # Run health checks"

check-env: ## Check if .env file exists
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(RED)Error: .env file not found. Run 'make install' first.$(NC)"; \
		exit 1; \
	fi

check-docker: ## Check if Docker is running
	@if ! docker info >/dev/null 2>&1; then \
		echo "$(RED)Error: Docker is not running. Please start Docker first.$(NC)"; \
		exit 1; \
	fi

install: check-docker ## Initial setup and deployment
	@echo "$(BLUE)Starting Prosora Ghost CMS installation...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)Running initial setup script...$(NC)"; \
		./scripts/deploy.sh; \
	else \
		echo "$(GREEN).env file already exists. Skipping initial setup.$(NC)"; \
		echo "$(YELLOW)Use 'make start' to start services or 'make deploy' to redeploy.$(NC)"; \
	fi

deploy: check-docker ## Deploy/redeploy the application
	@echo "$(BLUE)Deploying Prosora Ghost CMS...$(NC)"
	./scripts/deploy.sh

start: check-docker check-env ## Start all services
	@echo "$(BLUE)Starting all services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Services started successfully!$(NC)"
	@make status

stop: check-docker ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)Services stopped successfully!$(NC)"

restart: check-docker check-env ## Restart all services
	@echo "$(BLUE)Restarting all services...$(NC)"
	docker-compose restart
	@echo "$(GREEN)Services restarted successfully!$(NC)"
	@make status

status: check-docker ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Resource Usage:$(NC)"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" || true

logs: check-docker ## View logs from all services
	@echo "$(BLUE)Showing logs from all services (press Ctrl+C to exit):$(NC)"
	docker-compose logs -f

logs-ghost: check-docker ## View Ghost logs only
	@echo "$(BLUE)Showing Ghost logs (press Ctrl+C to exit):$(NC)"
	docker-compose logs -f ghost

logs-mysql: check-docker ## View MySQL logs only
	@echo "$(BLUE)Showing MySQL logs (press Ctrl+C to exit):$(NC)"
	docker-compose logs -f mysql

logs-caddy: check-docker ## View Caddy logs only
	@echo "$(BLUE)Showing Caddy logs (press Ctrl+C to exit):$(NC)"
	docker-compose logs -f caddy

logs-redis: check-docker ## View Redis logs only
	@echo "$(BLUE)Showing Redis logs (press Ctrl+C to exit):$(NC)"
	docker-compose logs -f redis

shell-ghost: check-docker check-env ## Open shell in Ghost container
	@echo "$(BLUE)Opening shell in Ghost container...$(NC)"
	docker-compose exec ghost /bin/bash

shell-mysql: check-docker check-env ## Open MySQL shell
	@echo "$(BLUE)Opening MySQL shell...$(NC)"
	docker-compose exec mysql mysql -u root -p

shell-redis: check-docker check-env ## Open Redis CLI
	@echo "$(BLUE)Opening Redis CLI...$(NC)"
	docker-compose exec redis redis-cli

backup: check-docker check-env ## Create a backup
	@echo "$(BLUE)Creating backup...$(NC)"
	./scripts/backup.sh
	@echo "$(GREEN)Backup completed successfully!$(NC)"

backup-quick: check-docker check-env ## Create a quick backup (database only)
	@echo "$(BLUE)Creating quick backup...$(NC)"
	./scripts/backup.sh --quick
	@echo "$(GREEN)Quick backup completed successfully!$(NC)"

restore: check-docker check-env ## Restore from backup (interactive)
	@echo "$(BLUE)Starting restore process...$(NC)"
	./scripts/restore.sh

list-backups: ## List available backups
	@echo "$(BLUE)Available backups:$(NC)"
	@if [ -d "backups" ]; then \
		ls -la backups/*.tar.gz 2>/dev/null | awk '{print "  " $$9 " (" $$5 " bytes, " $$6 " " $$7 " " $$8 ")"}' || echo "  No backups found"; \
	else \
		echo "  Backup directory not found"; \
	fi

update: check-docker check-env ## Update all components
	@echo "$(BLUE)Starting update process...$(NC)"
	./scripts/update.sh
	@echo "$(GREEN)Update completed successfully!$(NC)"

update-ghost: check-docker check-env ## Update Ghost only
	@echo "$(BLUE)Updating Ghost CMS...$(NC)"
	./scripts/update.sh --ghost
	@echo "$(GREEN)Ghost update completed successfully!$(NC)"

update-docker: check-docker check-env ## Update Docker images only
	@echo "$(BLUE)Updating Docker images...$(NC)"
	./scripts/update.sh --docker
	@echo "$(GREEN)Docker images updated successfully!$(NC)"

health: check-docker ## Run health checks
	@echo "$(BLUE)Running health checks...$(NC)"
	./scripts/health-check.sh

health-json: check-docker ## Run health checks (JSON output)
	@echo "$(BLUE)Running health checks (JSON output)...$(NC)"
	./scripts/health-check.sh --json

monitor: check-docker ## Start monitoring (daemon mode)
	@echo "$(BLUE)Starting monitoring daemon...$(NC)"
	./scripts/monitor.sh --daemon

manage: check-docker check-env ## Open management interface
	@echo "$(BLUE)Opening management interface...$(NC)"
	./scripts/manage.sh

clean: check-docker ## Clean up unused Docker resources
	@echo "$(BLUE)Cleaning up Docker resources...$(NC)"
	@echo "$(YELLOW)This will remove unused images, containers, and networks.$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -f; \
		docker volume prune -f; \
		echo "$(GREEN)Cleanup completed successfully!$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled.$(NC)"; \
	fi

clean-all: check-docker ## Clean up all Docker resources (including volumes)
	@echo "$(RED)WARNING: This will remove ALL Docker resources including data volumes!$(NC)"
	@echo "$(YELLOW)Make sure you have recent backups before proceeding.$(NC)"
	@read -p "Are you absolutely sure? Type 'yes' to confirm: " -r; \
	if [[ $$REPLY == "yes" ]]; then \
		docker-compose down -v; \
		docker system prune -a -f; \
		docker volume prune -f; \
		echo "$(GREEN)Complete cleanup finished!$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled.$(NC)"; \
	fi

pull: check-docker ## Pull latest Docker images
	@echo "$(BLUE)Pulling latest Docker images...$(NC)"
	docker-compose pull
	@echo "$(GREEN)Images pulled successfully!$(NC)"

build: check-docker ## Build custom images (if any)
	@echo "$(BLUE)Building custom images...$(NC)"
	docker-compose build
	@echo "$(GREEN)Build completed successfully!$(NC)"

config: check-docker check-env ## Validate and show Docker Compose configuration
	@echo "$(BLUE)Docker Compose Configuration:$(NC)"
	docker-compose config

ps: check-docker ## Show running containers
	@echo "$(BLUE)Running Containers:$(NC)"
	docker-compose ps

top: check-docker ## Show running processes in containers
	@echo "$(BLUE)Container Processes:$(NC)"
	docker-compose top

images: check-docker ## Show Docker images
	@echo "$(BLUE)Docker Images:$(NC)"
	docker images | grep -E "(ghost|mysql|redis|caddy|watchtower)" || echo "No related images found"

networks: check-docker ## Show Docker networks
	@echo "$(BLUE)Docker Networks:$(NC)"
	docker network ls | grep -E "($(PROJECT_NAME)|ghost)" || echo "No related networks found"

volumes: check-docker ## Show Docker volumes
	@echo "$(BLUE)Docker Volumes:$(NC)"
	docker volume ls | grep -E "($(PROJECT_NAME)|ghost|mysql|redis)" || echo "No related volumes found"

ssl-renew: check-docker check-env ## Renew SSL certificates
	@echo "$(BLUE)Renewing SSL certificates...$(NC)"
	docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
	@echo "$(GREEN)SSL certificates renewed successfully!$(NC)"

db-optimize: check-docker check-env ## Optimize database
	@echo "$(BLUE)Optimizing database...$(NC)"
	./scripts/manage.sh --optimize-db
	@echo "$(GREEN)Database optimization completed!$(NC)"

cache-clear: check-docker check-env ## Clear Redis cache
	@echo "$(BLUE)Clearing Redis cache...$(NC)"
	docker-compose exec redis redis-cli FLUSHALL
	@echo "$(GREEN)Cache cleared successfully!$(NC)"

ghost-cli: check-docker check-env ## Run Ghost CLI commands
	@echo "$(BLUE)Ghost CLI - Available commands:$(NC)"
	@echo "  version  - Show Ghost version"
	@echo "  status   - Show Ghost status"
	@echo "  restart  - Restart Ghost"
	@echo ""
	@read -p "Enter Ghost CLI command: " cmd; \
	docker-compose exec ghost ghost $$cmd

dev-setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		cp .env.example .env; \
		echo "$(YELLOW)Created .env file from template. Please edit it with your settings.$(NC)"; \
	fi
	@echo "$(GREEN)Development environment ready!$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Edit .env file with your configuration"
	@echo "  2. Run 'make start' to start services"

prod-deploy: check-env ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(NC)"
	@echo "$(YELLOW)Running pre-deployment checks...$(NC)"
	@make health
	@echo "$(YELLOW)Creating backup before deployment...$(NC)"
	@make backup
	@echo "$(YELLOW)Updating services...$(NC)"
	@make update
	@echo "$(GREEN)Production deployment completed!$(NC)"

info: ## Show system information
	@echo "$(BLUE)System Information:$(NC)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Compose File: $(COMPOSE_FILE)"
	@echo "Environment File: $(ENV_FILE)"
	@echo ""
	@echo "$(BLUE)Docker Information:$(NC)"
	@docker --version || echo "Docker not available"
	@docker-compose --version || echo "Docker Compose not available"
	@echo ""
	@echo "$(BLUE)System Resources:$(NC)"
	@echo "Disk Usage: $$(df -h . | tail -1 | awk '{print $$5}') of $$(df -h . | tail -1 | awk '{print $$2}')"
	@if command -v free >/dev/null 2>&1; then \
		echo "Memory Usage: $$(free -h | grep Mem | awk '{print $$3 "/" $$2}')"; \
	fi
	@if command -v uptime >/dev/null 2>&1; then \
		echo "Load Average: $$(uptime | grep -o 'load average: [0-9.]*' | cut -d' ' -f3)"; \
	fi

# Development helpers
dev: dev-setup start ## Quick development setup and start

prod: prod-deploy ## Quick production deployment

quick-start: check-docker ## Quick start without checks
	docker-compose up -d

quick-stop: check-docker ## Quick stop without checks
	docker-compose down

# Aliases for common commands
up: start ## Alias for start
down: stop ## Alias for stop
log: logs ## Alias for logs
ps-all: ps ## Alias for ps
# LiveLingo Docker Makefile

.PHONY: help build up down logs clean restart dev prod

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build all Docker images
	docker-compose build

up: ## Start all services in development mode
	docker-compose up -d
	@echo "Services started!"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend: http://localhost:8080"
	@echo "Database: localhost:5432"

down: ## Stop all services
	docker-compose down

logs: ## Show logs from all services
	docker-compose logs -f

logs-backend: ## Show backend logs
	docker-compose logs -f backend

logs-frontend: ## Show frontend logs
	docker-compose logs -f frontend

logs-db: ## Show database logs
	docker-compose logs -f db

clean: ## Stop services and remove volumes
	docker-compose down -v
	docker system prune -f

restart: ## Restart all services
	docker-compose restart

restart-backend: ## Restart backend service
	docker-compose restart backend

restart-frontend: ## Restart frontend service
	docker-compose restart frontend

dev: ## Start development environment
	@cp -n .env.docker.example .env.docker 2>/dev/null || true
	docker-compose up -d
	@echo "Development environment started!"

prod: ## Start production environment
	docker-compose -f docker-compose.prod.yml up -d --build
	@echo "Production environment started!"

ps: ## Show running containers
	docker-compose ps

shell-backend: ## Open shell in backend container
	docker-compose exec backend sh

shell-frontend: ## Open shell in frontend container
	docker-compose exec frontend sh

shell-db: ## Open PostgreSQL shell
	docker-compose exec db psql -U postgres -d livelingo

prisma-migrate: ## Run Prisma migrations
	docker-compose exec backend npx prisma migrate deploy

prisma-studio: ## Open Prisma Studio
	docker-compose exec backend npx prisma studio

prisma-generate: ## Generate Prisma client
	docker-compose exec backend npx prisma generate

rebuild: ## Rebuild and restart all services
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

status: ## Check service health
	@echo "=== Service Status ==="
	@docker-compose ps
	@echo ""
	@echo "=== Database Health ==="
	@docker-compose exec db pg_isready -U postgres || echo "Database not ready"
	@echo ""
	@echo "=== Frontend Health ==="
	@curl -s http://localhost:3000 > /dev/null && echo "Frontend: OK" || echo "Frontend: NOT RESPONDING"
	@echo ""
	@echo "=== Backend Health ==="
	@curl -s http://localhost:8080/health > /dev/null && echo "Backend: OK" || echo "Backend: NOT RESPONDING"

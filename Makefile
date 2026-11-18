OLLAMA_MODEL ?= qwen2.5:72b

.PHONY: install dev test lint format env up up-ui ollama-model ground-truth tokens down migrate migration

install:
	uv sync

migrate:
	uv run alembic upgrade head

migration:
	uv run alembic revision --autogenerate -m "$(m)"

dev:
	uv run uvicorn vigilant.main:app --reload --host 0.0.0.0 --port 8000

test:
	uv run pytest -v

lint:
	uv run ruff check .
	uv run mypy src

format:
	uv run ruff format .
	uv run ruff check --fix .

env:
	@test ! -e .env || { echo ".env already exists, keeping it"; exit 1; }
	@sed -e "s/^HERMES_API_SERVER_KEY=.*/HERMES_API_SERVER_KEY=$$(openssl rand -hex 24)/" \
	     -e "s/^HERMES_UID=.*/HERMES_UID=$$(id -u)/" \
	     -e "s/^HERMES_GID=.*/HERMES_GID=$$(id -g)/" env.example > .env
	@chmod 600 .env
	@echo ".env created"

up:
	docker compose up -d

up-ui:
	docker compose -f docker-compose.yml -f docker-compose.dev-ui.yml up -d

ollama-model:
	docker exec vigilant-ollama ollama pull $(OLLAMA_MODEL)

ground-truth:
	uv run --group ground-truth python scripts/ground_truth.py

tokens:
	@docker exec -i vigilant-hermes python3 - $(or $(N),10) $(if $(ALL),--all) < scripts/hermes_tokens.py

down:
	docker compose -f docker-compose.yml -f docker-compose.dev-ui.yml down

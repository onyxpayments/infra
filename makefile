pull:
	docker compose pull

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

logs-mock:
	docker compose logs -f mock-bank-service

logs-orchestrator:
	docker compose logs -f payment-orchestrator-service

up-core:
	docker compose up -d mock-bank-service payment-orchestrator-service

test-health:
	curl http://localhost:8001/health
	curl http://localhost:8002/health

test-process:
	curl -X POST http://localhost:8002/process-payment-test \
		-H "Content-Type: application/json" \
		-d '{"transaction_id":"trx_123","amount":10000,"currency":"COP","country":"CO"}'

reset:
	docker compose down -v
	docker compose pull
	docker compose up -d
# OnyxPay Infrastructure

Docker Compose stack for running the complete OnyxPay payment flow, persistence,
messaging, frontend, and observability services.

## Services

| Service | Host endpoint | Purpose |
| --- | --- | --- |
| Payment Frontend | `http://localhost:8080` | React payment form and Nginx API proxy |
| API Gateway | `http://localhost:8003` | Public payment API |
| Payment Request Service | `http://localhost:8004` | Request validation and event publishing |
| Payment Orchestrator API | `http://localhost:8002` | Provider callbacks and direct development API |
| Payment Orchestrator Worker | internal only | Payment event consumer |
| Orchestrator Migrations | one-shot | Alembic schema migrations |
| Mock Bank | `http://localhost:8001` | Asynchronous provider simulator |
| Webhook Service | internal only | Merchant webhook delivery worker |
| PostgreSQL | `localhost:5433` | Transaction and inbox persistence |
| RabbitMQ | `localhost:5672` | Application messaging |
| RabbitMQ Management | `http://localhost:15672` | Broker administration UI |
| Grafana | `http://localhost:3000` | Logs and transaction dashboards |
| Loki | `http://localhost:3100` | Log storage |
| Grafana Alloy | `http://localhost:12345` | Container log collection |

## Prerequisites

- Docker with the Compose plugin.
- Access to the `ghcr.io/onyxpayments` images.
- A populated `.env` file.

If the GHCR images are private, log in first:

```bash
echo "$GITHUB_TOKEN" | \
  docker login ghcr.io -u GITHUB_USERNAME --password-stdin
```

Create the local configuration:

```bash
cp .env.example .env
```

The Compose file requires valid values for PostgreSQL, RabbitMQ,
`DATABASE_URL`, and `BANK_SERVICE_URL`. The service repositories document their
complete optional settings.

For local Compose runs, `infra/.env` is the source of runtime configuration.
Compose injects that file into the containers; service-local `.env` files are
only used when a service is launched directly from its own repository. The
orchestrator image explicitly excludes `.env` from its build context.

The local `.env` file is intentionally ignored by Git. It is convenient for
development, but production deployments should inject only the secrets each
service needs from a dedicated secret manager.

At minimum, the resolved `.env` must provide values equivalent to:

```dotenv
POSTGRES_DB=transactions_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL=postgresql://postgres:postgres@orchestrator-db:5432/transactions_db
BANK_SERVICE_URL=http://mock-bank-service:8000
RABBITMQ_USER=onyxpay
RABBITMQ_PASSWORD=change-me
```

## Start the stack

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Open the frontend at `http://localhost:8080`.

Stop the stack without deleting data:

```bash
docker compose down
```

Delete containers and persistent volumes:

```bash
docker compose down -v
```

## Payment and webhook flow

```text
Browser
  │ POST /api/payments
  ▼
Nginx → API Gateway → Payment Request Service
                              │ payment.requested.v1
                              ▼
                           RabbitMQ
                              │
                              ▼
                    Orchestrator Worker
                      │             │
                      ▼             ▼
                 PostgreSQL     Mock Bank
                                      │ callback
                                      ▼
                              Orchestrator API
                                      │ payment.notification.requested.v1
                                      ▼
                                   RabbitMQ
                                      │
                                      ▼
                               Webhook Service
                                      │ POST notification_url
                                      ▼
                               Merchant endpoint
```

`notification_url` is required by the public payment contract and stored as a
non-nullable transaction field.

The Mock Bank development distribution produces approximately 30% approved,
15% declined, 25% error, and 30% pending transactions. Override its six
scenario probability variables in `.env` when a different test mix is needed.

## Process model

The orchestrator image runs as three coordinated services:

- `payment-orchestrator-migrations` applies Alembic migrations and exits.
- `payment-orchestrator-service` exposes HTTP callbacks and health endpoints.
- `payment-orchestrator-worker` consumes payment request events.

Both workers use manual acknowledgements. Transient failures pass through
delay queues, while invalid or exhausted messages are moved to dead-letter
queues.

## RabbitMQ topology

| Flow | Exchange | Queue | Routing key |
| --- | --- | --- | --- |
| Payment requests | `payment.events` | `orchestrator.payment-requested.q` | `payment.requested.v1` |
| Payment retries | `payment.retry` | `orchestrator.payment-requested.retry.q` | `payment.requested.retry` |
| Payment DLQ | `payment.dead-letter` | `orchestrator.payment-requested.dlq` | `payment.requested.failed` |
| Webhook requests | `payment.events` | `webhook.payment-notifications.q` | `payment.notification.requested.v1` |
| Webhook retries | `webhook.retry` | `webhook.payment-notifications.retry.q` | `webhook.notification.retry` |
| Webhook DLQ | `webhook.dead-letter` | `webhook.payment-notifications.dlq` | `webhook.notification.failed` |

Inspect queues through the management UI or:

```bash
docker exec infra-rabbitmq-1 rabbitmqctl list_queues
```

## Health and logs

```bash
docker compose ps
docker compose logs -f \
  payment-frontend \
  api-gateway \
  payment-request-service \
  payment-orchestrator-service \
  payment-orchestrator-worker \
  mock-bank-service \
  webhook-service
```

HTTP services expose liveness, startup, and readiness endpoints under
`/health`. Worker health checks run their respective Python health modules.

## Centralized logs

Grafana Alloy discovers Compose containers through the Docker socket and sends
their logs to Loki. Grafana provisions the `OnyxPay · Logs` dashboard and Loki
data source automatically.

1. Open `http://localhost:3000`.
2. Sign in with `admin` / `admin` on the first visit.
3. Open **Dashboards → OnyxPay → OnyxPay · Logs**.
4. Use the **Service** filter to select one or more services.

Alloy diagnostics are available at `http://localhost:12345`.

## Transaction dashboard

Grafana connects directly to the orchestrator PostgreSQL database through the
provisioned `OnyxPay Transactions` data source. The
`OnyxPay · Transactions` dashboard shows:

- Total transactions.
- Pending transactions (`NEW` and `PENDING`).
- Transactions in `ERROR`.
- Completed transactions (`APPROVED`, `DECLINED`, and `EXPIRED`).
- A time-range-aware stacked histogram grouped by status.

Open **Dashboards → OnyxPay → OnyxPay · Transactions**.

## Persistent volumes

Compose creates volumes for transaction data, RabbitMQ, Grafana, Loki, Alloy,
and the reserved webhook data volume. `docker compose down` preserves them;
`docker compose down -v` removes them.

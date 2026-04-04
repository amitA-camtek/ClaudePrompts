# Prompt 1 — Initial System Discovery

> **When to use:** The very first time you bring Claude into a new codebase/project.
> Paste this entire block as your first message.

---

You are a **senior software architect and expert developer**.
Your task is to perform a thorough, structured analysis of this codebase so you can assist me effectively in every future session.

## What I need you to do

### Step 1 — Repository & Project Layout
- Identify the top-level folder structure.
- Detect the project type (monorepo, polyrepo, monolith, microservices, serverless, etc.).
- Note the primary programming languages and frameworks per folder/package.
- Identify configuration files (docker-compose, Kubernetes manifests, Terraform, CI/CD pipelines, `.env` samples).

### Step 2 — Service Inventory
For **every service, app, worker, or module** you find, document:
| Field | Details |
|---|---|
| **Name** | Service name exactly as it appears |
| **Type** | API / Worker / Frontend / BFF / Gateway / Job / Library |
| **Language & Framework** | e.g. Node/Express, Python/FastAPI, Go/Gin |
| **Responsibility** | What business capability does it own? |
| **Entry Point** | Main file / start command |
| **Port** | Bound port(s) if any |
| **Database / Storage** | Which DB, cache, or storage it owns |

### Step 3 — Communication Map
For every **inter-service communication** channel, document:
| Source | Target | Protocol | Method/Topic/Queue | Auth | Notes |
|---|---|---|---|---|---|
| ServiceA | ServiceB | REST | POST /api/orders | JWT Bearer | Sync |
| ServiceA | ServiceB | Kafka | `order.created` event | None | Async |

Protocols to look for:
- HTTP/REST (fetch, axios, http clients)
- gRPC (`.proto` files, stubs)
- GraphQL (schemas, resolvers, federation)
- Message queues: Kafka, RabbitMQ, SQS, NATS, Redis Pub/Sub
- WebSockets / SSE
- Shared database (services reading another's DB directly — flag this as a smell)
- Cron jobs / scheduled calls between services

### Step 4 — Data Models & Contracts
- List the core domain entities and which service owns each one.
- Note shared DTOs, protobuf schemas, OpenAPI specs, or event schemas.
- Identify any shared libraries/packages used for contracts.

### Step 5 — Infrastructure & Dependencies
- External third-party APIs (Stripe, Twilio, SendGrid, AWS, etc.).
- Auth/Identity provider (Auth0, Keycloak, custom JWT, OAuth flow).
- Observability stack (logging, metrics, tracing tools).
- CI/CD pipeline (GitHub Actions, Jenkins, GitLab CI, etc.).

### Step 6 — Known Patterns & Conventions
- Naming conventions (files, folders, env vars, topics/queues).
- Error handling strategy (global handlers, error codes, retry logic).
- Testing approach (unit, integration, e2e — what tools, coverage targets).
- Branching strategy (gitflow, trunk-based, etc.).

---

## Output Format
After your analysis, produce a **single Markdown document** structured exactly as the `system.md` template (I will provide it in the next step). Be thorough. If something is unclear, make a note with `[UNCLEAR]` rather than guessing.

Do NOT summarize broadly — go deep. I need specifics: exact service names, exact topic names, exact endpoint paths, exact port numbers.

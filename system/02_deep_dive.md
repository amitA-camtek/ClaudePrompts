# Prompt 2 — Deep-Dive: Services & Communication Analysis

> **When to use:** After Prompt 1, once the initial map is built.
> Use this to drill deeper into one or more specific areas.
> Replace `[SERVICE_NAME]` placeholders with actual service names.

---

You are a **senior software architect**.
You have already done an initial scan of this codebase. Now I need you to go **deeper** on the following areas.

---

## Part A — Service Deep Dive: `[SERVICE_NAME]`

For the service named **[SERVICE_NAME]**, analyze and document:

1. **All exposed API endpoints / event handlers / queue consumers**
   - For REST: method, path, request body schema, response schema, status codes
   - For Kafka/RabbitMQ/SQS: topic/queue name, message schema (fields + types), consumer group
   - For gRPC: service name, RPC methods, request/response message types

2. **All outbound calls this service makes**
   - Which other service or external API it calls
   - When (on what trigger) it makes that call
   - What it sends and what it expects back

3. **Database schema** (if this service owns a DB)
   - Tables/collections and their key fields
   - Indexes
   - Foreign key relationships or references

4. **Environment variables this service requires**
   - Name, purpose, example value

5. **Error handling & retry behavior**
   - How failures are surfaced (exceptions, error codes, dead-letter queues)
   - Any retry logic or circuit breakers

6. **Security**
   - How incoming requests are authenticated/authorized
   - Any service-to-service token/secret approach

---

## Part B — Communication Flow Trace

Trace the **complete end-to-end flow** for the following user action or business event:

> **[DESCRIBE THE ACTION — e.g., "User places an order", "User resets password", "Payment is confirmed"]**

Show me:
- Every service involved, in sequence
- The exact call made at each step (endpoint / topic / queue)
- The data passed at each step
- Any async branches (fire-and-forget, event-driven side effects)
- The final state changes (DB writes, emails sent, etc.)

Use this format:

```
[1] Browser/Client
      → POST /api/checkout  { items: [...], userId: "u1" }
    → [2] api-gateway

[2] api-gateway
      validates JWT, extracts userId
      → POST /internal/orders/create  { items: [...], userId: "u1" }
    → [3] order-service

[3] order-service
      writes Order{id:"o1", status:"pending"} to orders DB
      → publishes Kafka topic `order.created` { orderId:"o1", userId:"u1", amount:99.99 }
    → [4] payment-service  (async)
    → [5] notification-service  (async)

...continue until flow is complete
```

---

## Part C — Identify Risks & Gaps

After analyzing the above, flag any architectural concerns:
- [ ] Services sharing a database (tight coupling)
- [ ] Missing retry / dead-letter handling on async messages
- [ ] No circuit breaker on synchronous calls
- [ ] Auth gaps (unauthenticated internal endpoints)
- [ ] Single points of failure
- [ ] Missing observability (no tracing, no structured logging)
- [ ] Circular dependencies between services

For each risk: name it, show where in the code it exists, and suggest a fix.

---

## Output
Update `system.md` with any new findings from this deep dive. Add a section under the relevant service. Mark anything newly discovered with `[NEW]`.

# Prompt 3 — Write / Update system.md

> **When to use:** After running Prompt 1 and/or Prompt 2, ask Claude to produce
> or update the persistent `system.md` knowledge file.

---

You are a **senior software architect and technical writer**.

Based on everything you have analyzed in this session, produce a **complete, up-to-date `system.md`** file using exactly the structure below.

Rules:
- Be **precise and specific** — no vague summaries.
- Use the **exact names** from the codebase (service names, topic names, table names, env vars).
- If something is unknown or unclear, write `[UNCLEAR — needs investigation]`.
- If something is a known risk, mark it with `⚠️`.
- Do NOT omit sections — fill every section, even if the answer is "N/A".

---

Produce the file now using this exact structure:

```markdown
# system.md — [PROJECT NAME] System Knowledge Base
> Last updated: [DATE]
> Generated from: [repo URL or folder name]

---

## 1. Project Overview
- **Type:** monorepo / polyrepo / monolith / microservices / serverless
- **Primary language(s):**
- **Primary framework(s):**
- **Short description:** (1–3 sentences on what the system does)

---

## 2. Repository Structure
\`\`\`
[paste the top-level folder tree here]
\`\`\`

---

## 3. Services Inventory

### [service-name]
- **Type:** API / Worker / Frontend / BFF / Gateway / Cron
- **Language & Framework:**
- **Responsibility:**
- **Entry point:**
- **Port:**
- **Database/Storage:**
- **Key env vars:**
- **Start command:**

_(repeat for every service)_

---

## 4. Communication Map

### Synchronous (HTTP / gRPC / GraphQL)
| Source | Target | Protocol | Endpoint / Method | Auth | Description |
|--------|--------|----------|--------------------|------|-------------|
|        |        |          |                    |      |             |

### Asynchronous (Events / Queues)
| Producer | Consumer(s) | Broker | Topic / Queue | Message Schema | Description |
|----------|-------------|--------|---------------|----------------|-------------|
|          |             |        |               |                |             |

---

## 5. Domain Entities & Ownership
| Entity | Owner Service | Storage | Key Fields |
|--------|--------------|---------|------------|
|        |              |         |            |

---

## 6. External Dependencies
| Name | Type | Used By | Purpose |
|------|------|---------|---------|
|      |      |         |         |

---

## 7. Auth & Security
- **Auth mechanism:**
- **Token format:**
- **Token issuer:**
- **Inter-service auth:**
- **Public endpoints (no auth):**

---

## 8. Infrastructure & DevOps
- **Container orchestration:**
- **CI/CD:**
- **Environments:** (local / staging / production)
- **Secrets management:**
- **Observability:** (logging / metrics / tracing tools)

---

## 9. Key Business Flows
_(Document the most important end-to-end flows)_

### Flow: [Name]
\`\`\`
Step 1 → Step 2 → Step 3 ...
\`\`\`

---

## 10. Architecture Risks & Notes
| Risk | Location | Severity | Suggested Fix |
|------|----------|----------|---------------|
|      |          |          |               |

---

## 11. Conventions & Standards
- **Naming conventions:**
- **Error handling:**
- **Testing approach:**
- **Branching strategy:**
- **Code style / linting:**

---

## 12. Glossary
| Term | Definition |
|------|------------|
|      |            |
```

Write the full file now. Output only the Markdown content, nothing else.

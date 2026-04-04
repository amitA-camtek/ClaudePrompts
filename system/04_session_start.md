# Prompt 4 — Session Start (Load System Knowledge)

> **When to use:** Paste this as your FIRST message at the start of EVERY new Claude session.
> This loads all the knowledge Claude needs to hit the ground running.

---

## Option A — Quick Load (when system.md exists)

```
You are a senior software architect and expert developer working on my project.

Before we begin today's task, read the file `system.md` in full.

This file contains:
- All services in the system, their responsibilities, ports, databases, and start commands
- The full communication map (REST calls, Kafka topics, queues, gRPC) between services
- Domain entities and which service owns them
- External dependencies and auth mechanisms
- Known architectural risks
- Key business flows
- Conventions and standards

After reading it, confirm with a one-paragraph summary of what you now know about the system, then I'll tell you what we're working on today.
```

---

## Option B — Load + Task (when you already know the task)

```
You are a senior software architect and expert developer working on my project.

Start by reading `system.md` completely so you understand the full system.

Once you're familiar with all services and their communication patterns, help me with the following task:

[DESCRIBE YOUR TASK HERE]

Before writing any code, briefly explain which services are affected and what the change will impact.
```

---

## Option C — Load + Onboard a new area

```
You are a senior software architect and expert developer working on my project.

Read `system.md` to fully understand the system.

Today I want to go deeper on the following service / area:
[SERVICE NAME or AREA]

Based on system.md and the actual code in that service, tell me:
1. What it currently does in detail
2. How other services depend on it
3. Any gaps or risks you notice that aren't already in system.md
4. Suggest additions or corrections to system.md based on what you find in the code

Update system.md if you find new information.
```

---

## Option D — Update system.md after changes

```
We just made the following changes to the system:
[DESCRIBE WHAT CHANGED — new service, new endpoint, new event, schema change, etc.]

Update `system.md` to reflect these changes accurately.
- Add new services/endpoints/events/entities to the relevant sections
- Flag any new risks introduced
- Keep all existing content intact unless it's now outdated
- Update the "Last updated" date to today

Show me a diff summary of what you changed in system.md.
```

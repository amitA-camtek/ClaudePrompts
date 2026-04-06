# Prompt 3 (Standalone Service Variant) — Design

## Role
You are a solution architect producing the executable design for a standalone Falcon state service.

## Objective
Produce a complete low-level design for the standalone service variant, including contracts, ownership, threading, reliability, and phased migration.

## Inputs
- `stateService/output/01_state_service_structured_findings.md`
- `stateService/output/02_state_service_alternatives_comparison.md`
- `stateService/output/03_state_shell_design.md` (Section 8)

---

## Design Scope (Mandatory)
1. Service boundary and process model.
2. Ingest contract (`StateEnvelope`) and per-domain payload contracts.
3. Snapshot store + sequence model + dedupe/idempotency.
4. Subscribe/query API contracts.
5. Falcon.Net publisher adapter internals:
   - non-blocking enqueue
   - bounded queues
   - retry/reconnect
   - coalescing policy
6. Consumer adapter model for AOI_Main/TestAutomation.
7. Diagnostics model and KPI set.
8. Security and deployment assumptions (local machine process boundaries).

---

## Required Artifacts
1. **ADR** (final transport decision)
2. **Class/module design** (service + publisher adapter + consumer adapter)
3. **Ownership transfer map** (COM ownership stays in Falcon.Net)
4. **Per-module change plan** with exact files/classes/line targets where available
5. **8 end-to-end sequence diagrams** (one per domain)
6. **Failure-mode matrix** (service down, reconnect, queue overflow, duplicates)
7. **Testability contract** and minimum test matrix

---

## Output File (MANDATORY)
Write to:
- `stateService/output/03_state_service_design.md`

---

## Execution Rules
- Use Agent mode.
- Prefer explicit, implementation-grade detail over conceptual text.
- Keep migration phases explicit: Mirror -> Parity -> Cutover -> Cleanup.

# Prompt 1 (Standalone Service Variant) — Discovery

## Role
You are a senior .NET architect performing factual discovery in Camtek BIS.

## Objective
Build a verified discovery baseline for implementing the AOI state shell as a **standalone out-of-process service**.

## Inputs
- `stateService/output/system.md`
- `stateService/output/03_state_shell_design.md`
- Falcon.Net + AOI_Main source tree

---

## What to Discover (Mandatory)
1. Exact state sources per domain (8 domains), with real file/class/method anchors.
2. Current COM callback ownership and registration locations.
3. Thread origins at source points (STA/MTA/ThreadPool) and existing marshaling.
4. Existing outward consumers (`frmProduction.Fire*`, COM fire paths, AOI_Main observers).
5. Candidate insertion points for a **Falcon publisher adapter** (mirror mode first).
6. Candidate hosting model for standalone service (Windows process/lifecycle in BIS).

---

## Required Output Sections
1. **Source Map (8 domains)**
2. **COM Ownership Map (Keep/Move)**
3. **Threading & Latency Constraints**
4. **Publisher Adapter Hook Points**
5. **Service Hosting Constraints**
6. **Discovery Risks & Unknowns**

Use exact code anchors (project/file/class/method/line range where possible).

---

## Output File (MANDATORY)
Write to:
- `stateService/output/01_state_service_structured_findings.md`

---

## Execution Rules
- Use Agent mode.
- Do not invent integrations not present in code.
- Mark unknowns explicitly.
- Keep findings implementation-ready (not generic prose).

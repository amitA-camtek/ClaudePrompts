# Prompt 2 (Standalone Service Variant) — Alternatives

## Role
You are a principal architect producing architecture alternatives for a standalone state service.

## Objective
Evaluate and select the best standalone-service architecture for Falcon state dissemination while preserving Falcon.Net COM callback ownership.

## Inputs
- `stateService/output/01_state_service_structured_findings.md`
- `stateService/output/system.md`
- `stateService/output/03_state_shell_design.md`

---

## Alternatives (Mandatory)
Evaluate at least these 3:

1. **Alt A — gRPC Streaming Service**
   - Falcon.Net publisher adapter -> gRPC service -> stream/query consumers
2. **Alt B — Named Pipes Service**
   - Falcon.Net publisher adapter -> named-pipe service -> stream/query consumers
3. **Alt C — Hybrid**
   - named pipe for local high-throughput ingest + gRPC for external consumers/diagnostics

---

## Evaluation Criteria
- Runtime compatibility with .NET Framework 4.8 producer side
- Operational complexity and deployment risk
- Latency and backpressure behavior under scan storms
- Failure isolation and restart behavior
- Testability and diagnostics visibility
- Migration complexity from current in-process flow

Provide weighted scoring and explicit winner.

---

## Required Output Sections
1. Option diagrams
2. Scoring matrix (weighted)
3. Risk matrix
4. Migration impact table (what changes in Falcon.Net, AOI_Main, service)
5. Decision and rationale

---

## Output File (MANDATORY)
Write to:
- `stateService/output/02_state_service_alternatives_comparison.md`

---

## Execution Rules
- Use Agent mode.
- If two options are close, include tie-breaker criteria and recommendation.

# Prompt 4 (Standalone Service Variant) — Implement Falcon State Service

## Role
You are a senior .NET architect and implementation agent working in Camtek BIS.
Implement the **standalone state service variant** defined in:
- `stateService/output/system.md`
- `stateService/output/03_state_shell_design.md` (especially **Section 8: Standalone Service Variant**)
- `stateService/output/03_state_service_design.md`

## Objective
Implement the state shell as an **out-of-process standalone service** instead of AOI_Main/in-process ownership.

The solution must keep COM callback ownership in Falcon.Net wrappers, and move only state dissemination/query to a dedicated service process.

---

## Non-Negotiable Constraints
1. Preserve existing COM registration points in Falcon.Net wrappers (`ScanManagerWrapper`, `RobotUIEventHandlerWrapper`, `AutoLoaderUIWrapper`, etc.).
2. Do **not** move COM callback ownership into AOI_Main.
3. Keep existing production behavior first; apply migration in safe phases (mirror first, switch later).
4. Do not break existing `frmProduction.Fire*` behavior in the same pass.
5. No placeholder code in delivery artifacts.
6. Use only technologies already acceptable in BIS; if adding a new dependency, justify explicitly.

---

## Implementation Target (High-Level)
Create a service-centric pipeline:

`Falcon.Net event sources -> Falcon publisher adapter -> IPC/gRPC -> Falcon.StateService -> snapshot + subscriptions -> AOI_Main/Test consumers`

---

## Required Design Decision (Step 1)
Decide and document transport with tradeoff table:
- Option A: gRPC (streaming)
- Option B: Named Pipes (duplex/events + request/response)

Choose one with explicit rationale for this repository constraints (.NET Framework 4.8 producer side, deployment complexity, diagnostics, latency, compatibility).

---

## Required Deliverables

### D1. Service Project(s)
- New standalone service project under Falcon app tree (example name: `Falcon.StateService`).
- Host process entrypoint + lifecycle (start/stop, graceful shutdown).
- State core:
  - `StateEnvelope`
  - Domain event contracts (8 domains)
  - `StateSnapshotStore`
  - `SequenceProvider`
  - `DiagnosticsProvider`

### D2. Falcon.Net Publisher Adapter
- In Falcon.Net, add adapter(s) that subscribe to existing in-process state events and publish to service.
- Non-blocking publish path from callback thread.
- Bounded queue + backpressure policy for high-frequency domains.

### D3. Service API
At minimum:
- `Publish(StateEnvelope)`
- `GetCurrentState()`
- `Subscribe(...)` (streaming/event feed)
- `GetDiagnostics()`

### D4. Reliability + Observability
- Retry policy when service unavailable.
- Idempotency using `(Domain, SequenceId)`.
- Coalescing policy for noisy scan progress.
- Structured logs + counters:
  - publish latency (p95)
  - dropped/coalesced counts
  - last sequence per domain
  - snapshot freshness per domain

### D5. Consumer Migration Adapter
- AOI_Main-facing adapter that consumes from service and exposes equivalent subscription/query semantics.
- Keep compatibility path so existing tests can still run during migration.

---

## Required Migration Phases
1. **Phase A (Mirror)**: Keep in-process path; mirror every domain event to service.
2. **Phase B (Parity Validation)**: Compare in-process snapshot vs service snapshot over representative flows.
3. **Phase C (Consumer Cutover)**: AOI_Main/TestAutomation consumers read from service.
4. **Phase D (Cleanup)**: remove redundant direct paths only after parity sign-off.

---

## Testing Requirements
Implement and run tests for:
1. Contract tests for all 8 domain payloads.
2. Publish/subscribe ordering and sequence monotonicity.
3. Backpressure behavior under event storm.
4. Service down/reconnect scenario with retry.
5. Snapshot correctness under concurrent updates.
6. End-to-end smoke: Falcon publisher adapter -> service -> consumer receives event.

---

## Output Files (MANDATORY)
Write all outputs to `stateService/output/`:

1. `stateService/output/04_state_service_implementation_delivery.md`
   - architecture decision (transport choice)
   - exact project/file/class/method changes
   - migration phase status

2. `stateService/output/04_state_service_codegen_manifest.md`
   - complete created/modified file list
   - for each file: purpose, owner, key symbols

3. `stateService/output/04_state_service_test_results.md`
   - executed tests
   - pass/fail
   - defects/blockers (if any)

4. `stateService/output/04_state_service_risks_and_rollout.md`
   - deployment risks
   - rollback plan
   - KPI thresholds and readiness checklist

---

## Execution Mode (MANDATORY)
Use Agent mode and perform the work end-to-end:
1. Read context files.
2. Implement code + tests.
3. Run validations.
4. Produce all 4 output artifacts above.

If blocked by missing dependencies or repo constraints, explicitly document:
- blocker
- attempted workaround
- exact next action required

---

## Definition of Done
Done means all are true:
- Standalone service path is implemented (not only described).
- Falcon.Net publisher adapter exists and is non-blocking.
- Consumers can query/subscribe through service API.
- Required tests are run and reported.
- All 4 output artifacts are saved under `stateService/output/`.

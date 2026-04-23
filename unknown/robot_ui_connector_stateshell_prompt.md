# Claude Script — Analyze `IRobotUIConnector` / `IRobotUIConnectorCB` and Extend `StateShell`

You are a **senior software engineer**.

I have run `AOI_main`.
Your task is to deeply analyze `IRobotUIConnector` and `IRobotUIConnectorCB`, then design how to use them to add more robot data into `StateShell`.

---

## Objective

1. Collect all information about:
   - `IRobotUIConnector`
   - `IRobotUIConnectorCB`
2. Explain the difference between them and how each one is used.
3. Design and propose a concrete `StateShell` integration plan to expose more robot data.

---

## Phase 1 — Discover and Extract

Search the full solution for:
- Interface definitions
- Implementations
- Registrations (DI/IoC)
- COM wrappers/proxies/adapters
- Events/callback hooks
- Command calls
- Bridge/state-shell references

### Search hints

- `IRobotUIConnector`
- `IRobotUIConnectorCB`
- `RobotUIConnector`
- `RobotUIConnectorCB`
- `StateShell`
- `StateShellBootstrapper`
- `Bridge`
- `RobotState`
- `RobotStatus`
- `Callback`
- `ComImport`, `Guid`, `InterfaceType`

For each interface, extract:
- Full method list (name + parameters + return type)
- Properties
- Events (if any)
- Threading assumptions (UI thread, COM apartment, background thread)
- Who calls it
- Who implements it

---

## Phase 2 — Explain the Difference

Provide a clear comparison:

| Aspect | IRobotUIConnector | IRobotUIConnectorCB |
|---|---|---|
| Role |  |  |
| Direction |  |  |
| Typical Caller |  |  |
| Typical Implementer |  |  |
| Data Type (commands/state/events) |  |  |
| Sync vs Async behavior |  |  |
| Lifetime/ownership |  |  |
| Threading model |  |  |
| Failure behavior |  |  |

Then summarize in plain words:
- Which one is "request/command" side?
- Which one is "notification/callback" side?
- Where they sit in runtime flow (UI ⇄ robot service ⇄ hardware)

---

## Phase 3 — Runtime Flow Mapping

Build a real flow map from current code:

1. How robot state is currently produced
2. How it moves through connector/callback
3. Where data is currently dropped or not forwarded to `StateShell`

Provide a sequence diagram (text/ASCII is fine), for at least:
- Robot connect/disconnect
- Robot state transition
- Robot motion/position update
- Robot alarm/error update

---

## Phase 4 — StateShell Integration Design

Design how to add more robot data into `StateShell` using these interfaces.

### 4.1 Data contract to add

Define the extra robot data items to expose, e.g.:
- Connection status
- Ready/Homed/Moving/Busy state
- Current recipe/job context
- Axis/joint/cartesian position
- Motion progress
- Alarm code/severity/message
- Last command + result
- Safety/interlock state
- Timestamp/source quality

For each item:
| Data Field | Source (Connector or Callback) | Type | Update Trigger | Frequency | Consumer |
|---|---|---|---|---|---|

### 4.2 Bridge design

Propose either:
- Extend existing `RobotStateBridge`, or
- Create `RobotUIConnectorStateBridge`

Include:
- Constructor dependencies
- Event/callback subscriptions
- Mapping logic from connector/callback payloads to state-shell model
- Debounce/throttle strategy for high-frequency updates (position)
- Error handling + retry policy
- Disposal/unsubscribe strategy

### 4.3 State model changes

Specify new state model fields and where they live.
If versioning is needed, define backward-compatible approach.

### 4.4 Bootstrapper changes

Show exact changes needed in `StateShellBootstrapper`:
- Registration order
- Lifecycle start/stop
- Dependency registration scope (singleton/transient)
- Health/diagnostic log lines to verify wiring

### 4.5 Callback/interface changes (if needed)

If `IRobotUIConnectorCB` lacks required events, propose additions with signatures and compatibility notes.

---

## Phase 5 — Implementation-Ready Output

Deliver:

1. **Difference summary** (short and precise)
2. **Master table** of all found methods/usage points
3. **Concrete design** for `StateShell` extension
4. **Code skeletons** (realistic, based on discovered architecture):
   - bridge class
   - bootstrapper registration
   - mapping handlers
5. **Risk list**:
   - threading/COM apartment issues
   - race conditions
   - event storms/high-frequency updates
   - null/stale callback targets
6. **Validation checklist**:
   - startup wiring checks
   - event firing checks
   - state propagation checks
   - stress test scenario

---

## Constraints

- Use actual code evidence (not guesses).
- If assumptions are necessary, label them explicitly.
- Prefer minimal, non-breaking changes.
- Keep naming consistent with existing code style.
- Highlight any COM interop caveats.

---

## Final response format

Use this exact structure:

1. `IRobotUIConnector` vs `IRobotUIConnectorCB` (difference)
2. Discovery table (definitions, implementations, call sites)
3. Runtime flow diagram
4. `StateShell` extension design
5. Proposed code skeletons
6. Risks and mitigations
7. Step-by-step rollout plan

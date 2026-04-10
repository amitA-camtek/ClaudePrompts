# Claude Debugging Script — Bridge State Change Issues in AOI_main

## Context

You are a **senior software engineer** debugging a state propagation issue in a .NET application.

**System Overview:**
- `AOI_main` is the application entry point.
- `StateShellBootstrapper` initializes and starts all bridges.
- Bridges (e.g., `JobStateBridge`, and others) should receive state-change notifications.
- `IFalconGuiCB` is a callback interface with methods like `JobLoaded` that should fire when a job is loaded.

**Observed Problem:**
- `StateShellBootstrapper` has initialized — all bridges report as started.
- A Job has been loaded successfully.
- `JobStateBridge` does **NOT** receive any state-change events.
- `IFalconGuiCB.JobLoaded` callback is **never invoked**.
- The same symptom occurs across **all other bridges** — none of them receive state changes.

---

## Diagnostic Plan — Execute These Steps In Order

### Step 1: Verify Bridge Registration & Subscription

Search for and inspect the following:

1. **How bridges register for state changes:**
   - Find where `JobStateBridge` (and other bridges) subscribe to state-change events/callbacks.
   - Look for patterns like:
     - Event subscription: `someEvent += handler`
     - Observer registration: `Register<IBridge>()`, `Subscribe()`, `AddListener()`
     - Callback interface registration: where `IFalconGuiCB` implementors are registered with the source.
   - **Key question:** Is the subscription happening **before** or **after** the job is loaded?

2. **Check `StateShellBootstrapper` initialization order:**
   - Read the bootstrapper code. List the exact order bridges are created and started.
   - Verify that the **event source** (the component that fires state changes) is initialized **before** bridges subscribe to it.
   - Look for any `async` initialization that could cause a race condition.

```
Search for:
- "StateShellBootstrapper" class definition and its Initialize/Start methods
- "JobStateBridge" class — constructor, Initialize, Subscribe, OnStateChanged methods
- "IFalconGuiCB" interface definition and all implementations
- "JobLoaded" — every place it is invoked or subscribed to
```

### Step 2: Trace the State-Change Notification Path

Map the **full chain** from "job loaded" to "bridge notified":

```
Job Loaded (source)
  → Who fires the event/callback?
    → What mechanism delivers it? (event, delegate, message bus, COM callback, direct call)
      → Who is supposed to receive it?
        → Is JobStateBridge / IFalconGuiCB in that receiver list?
```

Specifically check:
- Is there a **mediator**, **event aggregator**, or **message bus** between the source and bridges?
- Is the notification sent on the **correct thread**? (UI thread vs background thread mismatch)
- Are there any **null checks** or **guard clauses** that silently skip notification?

### Step 3: Check Common Root Causes (All Bridges Failing)

Since **ALL bridges** fail (not just one), the problem is systemic. Focus on:

1. **Event source not firing at all:**
   - Find the code that should fire after a job is loaded.
   - Add logging or confirm it executes:
     ```csharp
     // Example: Is this line ever reached?
     Console.WriteLine($"[DEBUG] About to notify {_callbacks?.Count ?? 0} listeners of JobLoaded");
     _callbacks?.ForEach(cb => cb.JobLoaded(jobInfo));
     ```

2. **Callback list is empty at notification time:**
   - The bridges may register themselves, but the registration target may be a **different instance** than the one firing events.
   - Check for:
     - Multiple instances of the event source (singleton misconfiguration)
     - DI container registering as `Transient` instead of `Singleton`
     - Bridges subscribing to a **prototype/factory instance** instead of the live instance

3. **Registration happens too late:**
   - If `StateShellBootstrapper` starts bridges **after** the job-load mechanism is already primed, the subscription window is missed.
   - Look for any `async void` or fire-and-forget patterns in the bootstrapper.

4. **Interface mismatch or wrong callback version:**
   - Verify `IFalconGuiCB` is the **same assembly version** across all references.
   - Check if there are multiple `IFalconGuiCB` interfaces (different namespaces or assemblies).
   - Look for `#if` preprocessor directives that might exclude the callback wiring.

5. **COM / Interop issues (if applicable):**
   - If `IFalconGuiCB` is a COM callback interface, check:
     - Is the COM object properly marshaled to the correct apartment?
     - Is `QueryInterface` succeeding for the callback interface?
     - Are there any `RPC_E_WRONG_THREAD` or `E_NOINTERFACE` errors being swallowed?

### Step 4: Add Targeted Diagnostics

Insert these diagnostic checks and share the output:

```csharp
// === DIAGNOSTIC 1: In StateShellBootstrapper after all bridges start ===
Console.WriteLine("[DIAG] === Bridge Registration Audit ===");
foreach (var bridge in _bridges)
{
    Console.WriteLine($"[DIAG] Bridge: {bridge.GetType().Name}, Initialized: {bridge.IsInitialized}");
}

// === DIAGNOSTIC 2: In the event source that should fire JobLoaded ===
Console.WriteLine($"[DIAG] === Callback List Audit ===");
Console.WriteLine($"[DIAG] Registered callback count: {_callbackList?.Count ?? -1}");
Console.WriteLine($"[DIAG] Callback list instance HashCode: {_callbackList?.GetHashCode()}");
// Compare with what the bridges subscribed to:
Console.WriteLine($"[DIAG] Event source instance HashCode: {this.GetHashCode()}");

// === DIAGNOSTIC 3: At the point where JobLoaded SHOULD fire ===
Console.WriteLine($"[DIAG] === JobLoaded Fire Point ===");
Console.WriteLine($"[DIAG] Thread: {Thread.CurrentThread.ManagedThreadId}, IsBackground: {Thread.CurrentThread.IsBackground}");
Console.WriteLine($"[DIAG] Job data valid: {job != null}, Job ID: {job?.Id}");
try
{
    foreach (var cb in _callbackList)
    {
        Console.WriteLine($"[DIAG] Calling JobLoaded on: {cb.GetType().Name} (HashCode: {cb.GetHashCode()})");
        cb.JobLoaded(job);
        Console.WriteLine($"[DIAG] JobLoaded returned successfully for: {cb.GetType().Name}");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"[DIAG] EXCEPTION during JobLoaded: {ex}");
}

// === DIAGNOSTIC 4: In JobStateBridge (and other bridges) ===
// Add to constructor:
Console.WriteLine($"[DIAG] JobStateBridge created. HashCode: {this.GetHashCode()}");
// Add to wherever it subscribes:
Console.WriteLine($"[DIAG] JobStateBridge subscribing to source HashCode: {source?.GetHashCode()}");
// Add to the callback method:
public void JobLoaded(IJobInfo job)
{
    Console.WriteLine($"[DIAG] >>> JobStateBridge.JobLoaded INVOKED! Job: {job?.Id} <<<");
    // ... existing code ...
}
```

### Step 5: Verify Fix

After identifying the root cause, confirm:

- [ ] `IFalconGuiCB.JobLoaded` fires on all registered bridges
- [ ] `JobStateBridge` receives the state change
- [ ] All other bridges receive their respective state changes
- [ ] No race conditions remain (test with rapid job load/unload cycles)
- [ ] No swallowed exceptions in the notification path

---

## Quick Checklist — Most Likely Root Causes (Ranked)

| # | Cause | How to Verify |
|---|-------|---------------|
| 1 | **Event source never fires** | Add log right before notification loop |
| 2 | **Callback list is empty** (wrong instance) | Log callback count at fire time + compare instance HashCodes |
| 3 | **Registration race condition** | Log timestamps of registration vs. first fire |
| 4 | **Singleton misconfiguration** | Check DI container — source must be singleton |
| 5 | **Exception swallowed in notification** | Wrap notification in try/catch with logging |
| 6 | **Thread marshaling issue** | Log thread IDs at subscribe and fire points |
| 7 | **Interface version mismatch** | Check all assemblies reference same IFalconGuiCB |

---

## What to Provide Back

After running diagnostics, share:
1. The **full console output** of the `[DIAG]` lines.
2. The **code** for `StateShellBootstrapper.Initialize()` (or equivalent start method).
3. The **code** where `IFalconGuiCB.JobLoaded` is supposed to be invoked.
4. The **code** where `JobStateBridge` registers/subscribes for callbacks.
5. Your **DI/IoC container registration** for the event source and bridges.

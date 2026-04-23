# Claude Analysis Script — Camera & Robot Integration into StateShell (AOI_main)

## Role

You are a **senior software engineer** performing a full architectural audit of the **Camera** and **Robot** subsystems in `AOI_main`. Your goal is to catalog every touchpoint these subsystems have in the codebase, then design a solution to integrate their state into the `StateShell` bridge architecture.

---

## Phase 1: Deep Discovery — Camera Subsystem

Search the entire codebase and collect **every** artifact related to Camera. For each item found, record it precisely.

### 1.1 Interfaces

Find all interfaces related to Camera:

```
Search patterns:
- ICamera, ICameraService, ICameraControl, ICameraState, ICameraManager
- ICameraCallback, ICameraCB, ICameraNotify, ICameraEvents
- Any interface in a file/namespace containing "Camera"
```

For each interface found, record:
| Interface Name | Namespace | Assembly | Methods | Properties | Events | Inherits From |
|---|---|---|---|---|---|---|

### 1.2 COM Interfaces & Interop

```
Search patterns:
- [ComImport], [Guid("...")] on camera-related types
- [InterfaceType(ComInterfaceType...)] on camera interfaces
- Any IDL or TLB references for camera
- CoClass registrations for camera objects
- Marshal attributes on camera method parameters
```

For each COM interface found, record:
| COM Interface | GUID | Interface Type (IUnknown/IDispatch/Dual) | Registered CoClass | Threading Model | Marshaling Notes |
|---|---|---|---|---|---|

### 1.3 State

```
Search patterns:
- CameraState, CameraStatus, eCameraState, ECameraState (enums/classes)
- Camera.*State, Camera.*Status (properties, fields)
- IsCamera*, Camera*Ready, Camera*Connected, Camera*Enabled
- State machines or state transition logic for Camera
- Any property change notification (INotifyPropertyChanged) on camera types
```

For each state artifact found, record:
| State Name | Type (enum/property/field) | Possible Values | Where Defined | Who Reads It | Who Writes It | Change Notification Mechanism |
|---|---|---|---|---|---|---|

### 1.4 Commands

```
Search patterns:
- CameraCommand, ICameraCommand, Camera.*Command
- Camera.*Execute, Camera.*Start, Camera.*Stop, Camera.*Trigger
- Command pattern implementations (ICommand) related to Camera
- Any method that sends a command/instruction to the camera hardware
```

For each command found, record:
| Command Name | Input Parameters | Return Type | Sync/Async | Where Defined | Who Calls It | Side Effects |
|---|---|---|---|---|---|---|

### 1.5 Events & Callbacks

```
Search patterns:
- event.*Camera, Camera.*Event, Camera.*Changed, Camera.*Completed
- OnCamera*, Camera.*Handler, Camera.*Delegate
- Camera-related callback registrations
```

For each event found, record:
| Event/Callback Name | Signature | Publisher | Subscriber(s) | Thread Affinity | Frequency |
|---|---|---|---|---|---|

### 1.6 Hardware / Driver Layer

```
Search patterns:
- Camera SDK references (e.g., Dalsa, Basler, Cognex, Matrox, FLIR, GenICam, GigE)
- Camera driver initialization, connection, disconnection
- Frame grabber references
- Image acquisition trigger/grab methods
```

Record:
| SDK/Driver | Version | Init Method | Connection Mechanism | Error Handling |
|---|---|---|---|---|

---

## Phase 2: Deep Discovery — Robot Subsystem

Repeat **the exact same audit** for Robot. Search the entire codebase and collect every artifact.

### 2.1 Interfaces

```
Search patterns:
- IRobot, IRobotService, IRobotControl, IRobotState, IRobotManager
- IRobotCallback, IRobotCB, IRobotNotify, IRobotEvents
- IMotion, IAxis, IHandler (if robot-related)
- Any interface in a file/namespace containing "Robot"
```

| Interface Name | Namespace | Assembly | Methods | Properties | Events | Inherits From |
|---|---|---|---|---|---|---|

### 2.2 COM Interfaces & Interop

```
Search patterns:
- [ComImport], [Guid("...")] on robot-related types
- CoClass registrations for robot objects
- Any IDL or TLB references for robot
```

| COM Interface | GUID | Interface Type | Registered CoClass | Threading Model | Marshaling Notes |
|---|---|---|---|---|---|

### 2.3 State

```
Search patterns:
- RobotState, RobotStatus, eRobotState, ERobotState
- Robot.*State, Robot.*Status, Robot.*Position
- IsRobot*, Robot*Ready, Robot*Connected, Robot*Homed, Robot*Moving
- AxisState, MotionState, HandlerState
- State machines or state transition logic for Robot
```

| State Name | Type | Possible Values | Where Defined | Who Reads It | Who Writes It | Change Notification |
|---|---|---|---|---|---|---|

### 2.4 Commands

```
Search patterns:
- RobotCommand, IRobotCommand, Robot.*Command
- Robot.*Move*, Robot.*Home*, Robot.*Execute, Robot.*Init
- Motion commands, axis commands
```

| Command Name | Input Parameters | Return Type | Sync/Async | Where Defined | Who Calls It | Side Effects |
|---|---|---|---|---|---|---|

### 2.5 Events & Callbacks

```
Search patterns:
- event.*Robot, Robot.*Event, Robot.*Changed, Robot.*Completed
- OnRobot*, Robot.*Handler, Robot.*Delegate
- Motion.*Complete, Axis.*Changed, Position.*Changed
```

| Event/Callback Name | Signature | Publisher | Subscriber(s) | Thread Affinity | Frequency |
|---|---|---|---|---|---|

### 2.6 Hardware / Driver Layer

```
Search patterns:
- Robot controller SDK (e.g., Epson, Fanuc, ABB, KUKA, Yamaha, ACS, Galil)
- Motion controller references
- Robot communication protocol (TCP, serial, EtherCAT, proprietary)
```

| SDK/Driver | Version | Init Method | Connection Mechanism | Error Handling |
|---|---|---|---|---|

---

## Phase 3: Master Summary Table

After completing Phase 1 and Phase 2, produce a single **consolidated summary table**:

| Aspect | Camera | Robot |
|--------|--------|-------|
| **Primary Interface** | (name, assembly) | (name, assembly) |
| **COM Interfaces** | (list with GUIDs) | (list with GUIDs) |
| **State Enum/Class** | (name, values) | (name, values) |
| **State Properties** | (list: name → type) | (list: name → type) |
| **Commands** | (list: name → signature) | (list: name → signature) |
| **Events Fired** | (list: name → signature) | (list: name → signature) |
| **Callbacks Received** | (list: name → signature) | (list: name → signature) |
| **Current State Notification** | (mechanism: event/polling/callback/none) | (mechanism: event/polling/callback/none) |
| **Thread Model** | (STA/MTA/thread-safe?) | (STA/MTA/thread-safe?) |
| **Hardware SDK** | (name, version) | (name, version) |
| **Connection Protocol** | (GigE/USB/serial/etc.) | (TCP/serial/EtherCAT/etc.) |
| **Existing Bridge?** | (Yes → name / No) | (Yes → name / No) |
| **Existing StateShell Integration?** | (Yes → how / No) | (Yes → how / No) |

---

## Phase 4: StateShell Integration Solution

### 4.1 Analyze Existing StateShell Architecture

Before designing the solution, fully understand the existing pattern:

```
Search and document:
1. StateShellBootstrapper — how it discovers, creates, and starts bridges
2. Existing bridge implementations (e.g., JobStateBridge) — their base class, lifecycle, registration
3. IFalconGuiCB — full interface definition and all methods
4. The state propagation mechanism — events? polling? direct calls?
5. How existing bridges expose state to the GUI / other consumers
```

Produce this reference:
| Existing Bridge | Monitored Component | State Properties Exposed | Events Forwarded | Base Class | Registration Method |
|---|---|---|---|---|---|

### 4.2 Design: CameraStateBridge

Based on the patterns found above, define the `CameraStateBridge`:

```
Provide:
1. Class definition (inheriting from the correct base)
2. Constructor — what dependencies to inject
3. State properties to expose (from Phase 1.3)
4. Event subscriptions — what camera events to listen to (from Phase 1.5)
5. IFalconGuiCB methods to invoke on state change
6. Thread marshaling strategy (if camera events come on a non-UI thread)
7. Initialization order in StateShellBootstrapper
8. Cleanup / disposal logic
```

**Skeleton code:**
```csharp
/// <summary>
/// Bridges camera subsystem state into the StateShell architecture.
/// Monitors camera state changes and propagates them via IFalconGuiCB.
/// </summary>
public class CameraStateBridge : StateBridgeBase  // or whatever the base class is
{
    // === Dependencies ===
    // (list what's injected)

    // === State Properties ===
    // (mirror the camera state properties discovered in Phase 1.3)

    // === Constructor ===
    public CameraStateBridge(/* dependencies */)
    {
        // Subscribe to camera state change events
    }

    // === State Change Handlers ===
    // One handler per camera event that affects state

    // === IFalconGuiCB Notifications ===
    // Map each state change to the appropriate GUI callback

    // === Cleanup ===
    // Unsubscribe from all events
}
```

### 4.3 Design: RobotStateBridge

Same structure for Robot:

```csharp
/// <summary>
/// Bridges robot subsystem state into the StateShell architecture.
/// Monitors robot state, position, motion status and propagates via IFalconGuiCB.
/// </summary>
public class RobotStateBridge : StateBridgeBase
{
    // === Dependencies ===

    // === State Properties ===
    // (mirror the robot state properties discovered in Phase 2.3)

    // === Constructor ===
    public RobotStateBridge(/* dependencies */)
    {
        // Subscribe to robot state change events
    }

    // === State Change Handlers ===

    // === IFalconGuiCB Notifications ===

    // === Cleanup ===
}
```

### 4.4 StateShellBootstrapper Modifications

Define exactly what changes are needed in `StateShellBootstrapper`:

```
1. Where to register CameraStateBridge and RobotStateBridge
2. Initialization order relative to existing bridges
3. Dependency resolution — what must be available before these bridges start
4. New DI/IoC container registrations needed
5. Startup validation — how to verify the bridges connected successfully
```

### 4.5 IFalconGuiCB Extensions (if needed)

If `IFalconGuiCB` does not already have methods for Camera/Robot state:

```
1. List new methods to add to the interface
2. Define signatures with parameter types
3. Identify all existing implementations that must be updated
4. Backward compatibility strategy (new interface version? default implementations?)
```

| New Method | Signature | Triggered By | Data Carried |
|---|---|---|---|
| CameraStateChanged | `void CameraStateChanged(eCameraState newState, eCameraState oldState)` | Camera connect/disconnect/error | State enum values |
| CameraFrameAcquired | `void CameraFrameAcquired(int cameraId, long frameId)` | Frame grab complete | Camera ID + frame reference |
| RobotStateChanged | `void RobotStateChanged(eRobotState newState, eRobotState oldState)` | Robot state transitions | State enum values |
| RobotPositionChanged | `void RobotPositionChanged(RobotPosition pos)` | Motion complete | Axis positions |
| ... | ... | ... | ... |

*(Adjust based on actual findings — these are examples)*

### 4.6 Integration Diagram

Produce an ASCII or text diagram showing the data flow:

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Camera HW/SDK  │────▶│  CameraStateBridge    │────▶│  IFalconGuiCB   │
│  (events/polls) │     │  (in StateShell)      │     │  (GUI + others) │
└─────────────────┘     └──────────────────────┘     └─────────────────┘

┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Robot HW/SDK   │────▶│  RobotStateBridge     │────▶│  IFalconGuiCB   │
│  (events/polls) │     │  (in StateShell)      │     │  (GUI + others) │
└─────────────────┘     └──────────────────────┘     └─────────────────┘

                        ┌──────────────────────┐
                        │ StateShellBootstrapper│
                        │  ├─ JobStateBridge    │
                        │  ├─ CameraStateBridge │  ◀── NEW
                        │  ├─ RobotStateBridge  │  ◀── NEW
                        │  └─ ...other bridges  │
                        └──────────────────────┘
```

---

## Phase 5: Implementation Checklist

Provide a prioritized task list:

| # | Task | Depends On | Estimated Effort | Risk |
|---|------|-----------|-----------------|------|
| 1 | Extend `IFalconGuiCB` with Camera/Robot methods | Phase 3 findings | Low–Med | Breaking change if COM interface |
| 2 | Implement `CameraStateBridge` | #1 + Camera interface analysis | Medium | Thread safety |
| 3 | Implement `RobotStateBridge` | #1 + Robot interface analysis | Medium | Thread safety |
| 4 | Register bridges in `StateShellBootstrapper` | #2, #3 | Low | Init order |
| 5 | Register in DI/IoC container | #4 | Low | Singleton scope |
| 6 | Update all `IFalconGuiCB` implementors | #1 | Med | Many touch points |
| 7 | Add unit tests for bridge state propagation | #2, #3 | Medium | Mock HW layer |
| 8 | Integration test — load job, verify all bridges fire | #4 | Medium | HW dependency |
| 9 | Stress test — rapid state changes, thread safety | #7 | Medium | Race conditions |

---

## Deliverables Expected

After running this analysis, provide:

1. **Phase 3 Master Summary Table** — fully populated with real findings
2. **Phase 4 skeleton code** — adapted to the actual base classes, interfaces, and patterns found
3. **Phase 4.5 interface changes** — exact methods with correct types from the codebase
4. **Phase 5 checklist** — adjusted for actual complexity discovered
5. **Risk callouts** — any architectural concerns (COM threading, circular dependencies, breaking changes)

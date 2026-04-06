Q:
base on the state_shell_design
exept from the Falcon.Net changes, what other project will have changed?

A: 
All changes are internal to Falcon.Net
Every file in the Module Change Plan (M1–M58) and every new file (N1–N39) lives under Falcon.Net:

File Category	Project	Examples
New StateShell/ folder (39 files)	Falcon.Net	Enums, Payloads, Events, Bridges, Core infrastructure
COM wrapper modifications (Keep/Wrap)	Falcon.Net	ScanManagerWrapper.cs, RobotUIEventHandlerWrapper.cs, AutoLoaderUIWrapper.cs, ExternalControlCbUiWrapper.cs
Form modifications	Falcon.Net	frmMain.cs, frmProduction.cs
Module modifications	Falcon.Net	OpticModule.cs, modWaferAlignment.cs, ExternalCoordSystemsAlign.cs, modCleanReferenceOptions.cs
MainContext modifications	Falcon.Net	MainContextModule.cs, clsInitAOI.cs, clsFalconPresentation.cs
CMM modifications	Falcon.Net	CmmReceiverApiRequetsHandler.cs, clsCMM.cs
UIEvents modifications	Falcon.Net	UIEvents.cs
Why no external project changes are needed
COM interfaces are frozen — IScanManagerInkingCB, IRobotUIConnectorCB, IFalconFireEvents, IAutoLoaderEvents are all kept unchanged. The COM servers (CScanManager, EfemSrv, CFalconEvents ATL) are not modified.

Bridges wrap, not replace — Every bridge subscribes to existing .NET delegate events exposed by wrappers already inside Falcon.Net. No upstream COM server code changes.

gRPC contract unchanged — CmmBridge hooks into CmmReceiverApiRequetsHandler callbacks that already exist in Falcon.Net. The CMM.Net.Api gRPC client/server contracts are untouched.

Prism dependency already exists — Microsoft.Practices.Prism.PubSubEvents is already referenced and deployed to bin. No NuGet additions.

*External consumers (Cimetrix, SECS/GEM, external tools)** receive events through the same CFalconEventsCOM path — which remains unchanged (theFire` methods just become subscribers to EA events instead of being called directly).

One caveat: Test project
A new test project (or test files added to an existing test project) would be needed for the 21 unit tests defined in §5.6. This is not an existing project change but a new addition:
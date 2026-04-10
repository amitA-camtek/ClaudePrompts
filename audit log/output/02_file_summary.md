# Audit Log — Output 2: File Classification & Summary

> **Input:** `output/01_discovered_files.md`  
> **Date:** 2026-04-10  
> **Analyst role:** Senior software architect, Camtek Falcon BIS platform

---

## Section 1 — Classification Table

| # | File pattern / path | Module | Hardware scope | Owner service | Write pattern | Sensitivity | Monitor priority |
|---|---|---|---|---|---|---|---|
| 1 | `c:\job\status.ini` | Config | Global | Falcon.Net | OnRun | High | **P1** |
| 2 | `c:\job\<JobName>\Metadata.ini` | Job | Global | RMS | OnCreate | High | **P1** |
| 3 | `c:\job\<JobName>\<Setup>\Metadata.ini` | Job | Global | RMS | OnCreate | High | **P1** |
| 4 | `c:\job\<JobName>\<Setup>\MultiRecipe.ini` | Recipe | Global | RMS | OnCreate / OnLoad | Critical | **P1** |
| 5 | `c:\job\<JobName>\<Setup>\DefectsClustering.ini` | Recipe | Global | RMS / AOI_Main | OnCreate | Critical | **P1** |
| 6 | `c:\job\<JobName>\<Setup>\ProductionInfo.ini` | Job | Global | RMS | OnCreate | High | **P1** |
| 7 | `c:\job\<JobName>\<Setup>\ScanCondition.ini` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 8 | `c:\job\<JobName>\<Setup>\Wafer2Table.ini` | AlignmentData | Stage | AOI_Main | OnLoad / OnEvent | Critical | **P1** |
| 9 | `c:\job\<JobName>\<Setup>\DefaultWafer2Table.ini` | AlignmentData | Stage | RMS | OnCreate | High | **P2** |
| 10 | `c:\job\<JobName>\<Setup>\DieAlignment.dat_block.ini` | Recipe | Global | RMS | OnCreate | Medium | **P2** |
| 11 | `c:\job\<JobName>\<Setup>\WaferMapRecipe.ini` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 12 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Recipe.ini` | Recipe | Global | RMS / Falcon.Net | OnLoad | Critical | **P1** |
| 13 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ProductInfo.ini` | Recipe | Camera / Illumination | RMS / AOI_Main | OnLoad | Critical | **P1** |
| 14 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Waferinfo.ini` | Recipe | Robot/EFEM | RMS / AOI_Main | OnLoad | Critical | **P1** |
| 15 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Wafer2Table.ini` | AlignmentData | Stage | AOI_Main | OnLoad / OnEvent | Critical | **P1** |
| 16 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Alignment.ini` | AlignmentData | Stage | AOI_Main | OnLoad | Critical | **P1** |
| 17 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DefaultWafer2Table.ini` | AlignmentData | Stage | RMS | OnCreate | High | **P2** |
| 18 | `c:\job\<JobName>\<Setup>\Recipes\<R>\AlignmentData.ini` | AlignmentData | Stage | RMS | OnCreate | High | **P2** |
| 19 | `c:\job\<JobName>\<Setup>\Recipes\<R>\AlignRtp.ini` | AlignmentData | Stage | RMS / AOI_Main | OnCreate / OnEvent | Critical | **P1** |
| 20 | `c:\job\<JobName>\<Setup>\Recipes\<R>\GlobalRTP.ini` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 21 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Params_AlignRTP.ini` | AlignmentData | Stage | RMS | OnCreate | Critical | **P1** |
| 22 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Params_SystemInfo.ini` | Config | Global | RMS | OnCreate | High | **P1** |
| 23 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Params_WaferInfo.ini` | Recipe | Robot/EFEM | RMS | OnCreate | High | **P1** |
| 24 | `c:\job\<JobName>\<Setup>\Recipes\<R>\RTP.txt` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 25 | `c:\job\<JobName>\<Setup>\Recipes\<R>\OpticPreset.ini` | Config | Illumination | RMS / DataServer | OnLoad | Critical | **P1** |
| 26 | `c:\job\<JobName>\<Setup>\Recipes\<R>\JobIllumLimits.ini` | Config | Illumination | RMS / DataServer | OnLoad | Critical | **P1** |
| 27 | `c:\job\<JobName>\<Setup>\Recipes\<R>\OpticToVCamStorage.json` | Config | Camera | RMS / AOI_Main | OnCreate / OnEvent | High | **P1** |
| 28 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ZoomLevels.ini` | Recipe | Camera | RMS | OnCreate | Critical | **P1** |
| 29 | `c:\job\<JobName>\<Setup>\Recipes\<R>\zones.ini` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 30 | `c:\job\<JobName>\<Setup>\Recipes\<R>\zones.txt` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 31 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DieMapRegPos.txt` | DieMap | Global | RMS | OnCreate | High | **P2** |
| 32 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DieRegPos.txt` | DieMap | Global | RMS | OnCreate | High | **P2** |
| 33 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Zones\<zone>.ini` | Recipe | Global | RMS | OnCreate | Critical | **P1** |
| 34 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ScenariosMetadatas.ini` | Recipe | Global | RMS / AOI_Main | OnCreate | High | **P2** |
| 35 | `c:\job\<JobName>\<Setup>\Recipes\<R>\CcsLocalMeas.ini` | Recipe | Camera | RMS / AOI_Main | OnCreate | High | **P2** |
| 36 | `c:\job\<JobName>\<Setup>\Recipes\<R>\CleanReferenceConfiguration.ini` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 37 | `c:\job\<JobName>\<Setup>\Recipes\<R>\CleanReferenceFinalParams.ini` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 38 | `c:\job\<JobName>\<Setup>\Recipes\<R>\CreateReference3dOptions.ini` | Recipe | Camera | RMS | OnCreate | High | **P2** |
| 39 | `c:\job\<JobName>\<Setup>\Recipes\<R>\OverlayScan.ini` | Recipe | Camera | RMS | OnCreate | High | **P2** |
| 40 | `c:\job\<JobName>\<Setup>\Recipes\<R>\SamplingMetrology.ini` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 41 | `c:\job\<JobName>\<Setup>\Recipes\<R>\UniqueArea.ini` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 42 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ExternalCoordSystems.ini` | Config | Global | RMS | OnCreate | Medium | **P2** |
| 43 | `c:\job\<JobName>\<Setup>\Recipes\<R>\Metadata.ini` (recipe) | Job | Global | RMS | OnCreate | Medium | **P3** |
| 44 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferDataReadSettings.xml` | Config | Global | RMS | OnCreate | Medium | **P2** |
| 45 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferMapRecipe.ini` | Recipe | Global | RMS | OnCreate | High | **P2** |
| 46 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferToRefWafer.ini` | Recipe | Global | RMS | OnCreate | Medium | **P2** |
| 47 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DieAlignment.dat_block.ini` | Recipe | Global | RMS | OnCreate | Medium | **P2** |
| 48 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DieMapAlignRes.dat_block.ini` | Recipe | Global | RMS | OnCreate | Medium | **P2** |
| 49 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ScanOverlapLog.txt` | ScanResult | Global | AOI_Main | OnClose | Medium | **P3** |
| 50 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ScanOverviewImage_<name>.txt` | ScanResult | Global | AOI_Main | OnClose | Low | **P3** |
| 51 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ImageProcessing.log` | Log | Global | AOI_Main | OnEvent | Low | **P4** |
| 52 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ReferencesInfo.json` | Recipe | Global | RMS | OnCreate / OnEvent | High | **P2** |
| 53 | `c:\job\<JobName>\<Setup>\Recipes\<R>\OpticLightMetadata\config.ini` | Config | Illumination | DataServer / RMS | OnCreate | High | **P2** |
| 54 | `c:\job\<JobName>\<Setup>\Recipes\<R>\FocusMapping\FocusMapping.ini` | Recipe | Camera | AOI_Main | OnEvent (teach) | High | **P2** |
| 55 | `c:\job\<JobName>\<Setup>\Recipes\<R>\FocusMapping\DieReferenceLocation.json` | AlignmentData | Camera | AOI_Main | OnEvent (teach) | High | **P2** |
| 56 | `c:\job\<JobName>\<Setup>\Recipes\<R>\FocusMapping\FocusPointsForScan.xml` | AlignmentData | Camera | AOI_Main | OnEvent (teach) | High | **P2** |
| 57 | `c:\job\<JobName>\<Setup>\Recipes\<R>\FocusMapping\Model_<guid>\FocusModel.ini` | AlignmentData | Camera | AOI_Main | OnEvent (teach) | High | **P2** |
| 58 | `c:\job\<JobName>\<Setup>\Recipes\<R>\.dc_cache\TransactionsHistory.ini` | Log | Global | RMS / AOI_Main | OnEvent (save) | Medium | **P2** |
| 59 | `c:\job\<JobName>\<Setup>\Recipes\<R>\TrainData\Die.ini` | Recipe | Camera | AOI_Main | OnEvent (train) | High | **P2** |
| 60 | `c:\job\<JobName>\<Setup>\Recipes\<R>\TrainData\DieRefToTrain.txt` | Recipe | Camera | AOI_Main | OnEvent (train) | Medium | **P2** |
| 61 | `c:\job\<JobName>\<Setup>\Recipes\<R>\TrainData\FrameToChuck.ini` | AlignmentData | Stage | AOI_Main | OnEvent (train) | High | **P2** |
| 62 | `c:\job\<JobName>\<Setup>\Recipes\<R>\TrainData\DieImage\*.ini` | Recipe | Camera | AOI_Main | OnEvent (train) | Medium | **P3** |
| 63 | `c:\job\<JobName>\<Setup>\Recipes\<R>\TrainData\ZonesVectorInfo.csv` | Recipe | Global | AOI_Main | OnEvent (train) | Medium | **P2** |
| 64 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ReferenceBackup\ZoomLevels.ini` | Recipe | Camera | RMS | OnEvent (backup) | Low | **P3** |
| 65 | `c:\job\<JobName>\<Setup>\Recipes\<R>\SW_QA-*\OpticsPreset.ini` | Config | Illumination | RMS | OnCreate | Medium | **P3** |
| 66 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferAlignData\AlignmentData.ini` | AlignmentData | Stage | AOI_Main | OnRun | Critical | **P1** |
| 67 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferAlignData\Alignment_PatFindRtp.txt` | AlignmentData | Stage | AOI_Main | OnRun | High | **P2** |
| 68 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferAlignData\AlignmentStatisticsTime.txt` | AlignmentData | Stage | AOI_Main | OnRun | High | **P2** |
| 69 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferAlignData\Alignment_PatRes.txt` | AlignmentData | Stage | AOI_Main | OnRun | High | **P2** |
| 70 | `c:\job\<JobName>\<Setup>\Recipes\<R>\WaferAlignData\Alignment_Stat.txt` | AlignmentData | Stage | AOI_Main | OnRun | High | **P2** |
| 71 | `c:\job\<JobName>\<Setup>\Recipes\<R>\DebugAFMapping\FocusMappingDebug_*.txt` | Log | Camera | AOI_Main | OnEvent | Low | **P4** |
| 72 | `c:\job\<JobName>\<Setup>\Recipes\<R>\s_FrameData.dat.md` | Recipe | Global | RMS | OnCreate | Low | **P3** |
| 73 | `c:\job\<JobName>\<Setup>\Recipes\<R>\ScenarioMetadataGrab.xml` | Recipe | Global | RMS / AOI_Main | OnCreate | Medium | **P3** |
| 74 | `c:\job\<JobName>\<Setup>\CurrWaferSurfaceInterpolation.ini/.md` | AlignmentData | Stage | AOI_Main | OnEvent | High | **P2** |
| 75 | `c:\job\ValidationJob\VcamInstallerGuid.txt` | Config | Camera | External tool | OnCreate | Medium | **P3** |
| 76 | `c:\job\<JobName>\<Setup>\DieAlignment.dat` (text-passing) | AlignmentData | Stage | AOI_Main | OnEvent | High | **P2** |
| 77 | `<Recipe>\DieMapping.dat`, `DieRegPos.dat`, `DieMapRegPos.dat`, `WaferInfo.dat`, `zones.dat`, `Job.dat` (text-passing .dat) | DieMap / Recipe | Global | RMS | OnCreate | High | **P2** |

---

## Section 2 — Write Pattern Evidence

| Pattern | Files | Evidence |
|---|---|---|
| **OnCreate** | `GlobalRTP.ini`, `RTP.txt`, `zones.ini`, `ZoomLevels.ini`, `AlignmentData.ini`, `Metadata.ini`, `ScenariosMetadatas.ini`, `DieMapping.dat`, structural .ini files | Last-Modified **predates** Created on all Diced_10.0.4511 files (2026-03-03 vs 2026-03-15) — file contents were authored at recipe design time and copied into the filesystem as-is |
| **OnLoad** | `Recipe.ini`, `ProductInfo.ini`, `Waferinfo.ini`, `Wafer2Table.ini` (recipe-level), `Alignment.ini`, `OpticPreset.ini`, `JobIllumLimits.ini` | Last-Modified is 2026-04-06 or 2026-04-07 — **22–23 days after** the job was copied. These files were last touched during an actual machine run, confirming they are updated each time the recipe is loaded or reloaded |
| **OnRun** | `WaferAlignData\*` (5 files per recipe) | Created = Modified = 2026-04-07 — gap ≈ 0 min, consistent with being written fresh at the start of every scan run |
| **OnEvent** | `FocusMapping\FocusMapping.ini`, `FocusReferenceLocation.json`, `FocusModel.ini`, `TrainData\*`, `.dc_cache\TransactionsHistory.ini`, `CurrWaferSurfaceInterpolation.*` | Written only when a specific teach / training / focus-mapping workflow is executed; not updated every load or every run |
| **OnClose** | `ScanOverlapLog.txt`, `ScanOverviewImage_*.txt` | Content describes results calculated at end of scan setup; size is small and stable, not appended during run |
| **Continuously (ongoing)** | `status.ini` (root) | 4-month gap between Created (2025-12-02) and Last-Modified (2026-04-07); `[UC_PROGRAM]` section updated on every machine-program state transition |

---

## Section 3 — Per-Group Summary

### Recipe — RMS (P1, Critical)

- **File pattern:** `c:\job\<Job>\<Setup>\Recipes\<R>\Recipe.ini`, `GlobalRTP.ini`, `RTP.txt`, `ZoomLevels.ini`, `zones.ini`, `Zones\<zone>.ini`, `MultiRecipe.ini`, `ScanCondition.ini`, `WaferMapRecipe.ini`
- **Typical count per job:** ~12 files × 2 recipes = 24 files (Diced); ~10 files (ScanAreaOnly, ValidationJob)
- **Write pattern:** `OnCreate` for structural files; `OnLoad` for `Recipe.ini`
- **Sensitivity:** Critical — these define what is scanned, how, and at what resolution
- **Monitor priority:** P1
- **Key fields to watch:** `[AutoCycle]` in `Recipe.ini`, `[GLOBAL_RTP]` section entries, zone names and bounds in `Zones\*.ini`
- **Notes:** `Recipe.ini` is the top-level recipe control file; modification here can change scan mode, number of passes, and post-process behavior

---

### AlignmentData — AOI_Main (P1, Critical)

- **File pattern:** `c:\job\<Job>\<Setup>\Recipes\<R>\Wafer2Table.ini`, `Alignment.ini`, `AlignRtp.ini`, `Params_AlignRTP.ini`; `WaferAlignData\*`; setup-level `Wafer2Table.ini`
- **Typical count per job:** ~8 alignment-param files + 5 runtime WaferAlignData files per recipe
- **Write pattern:** Alignment params → `OnLoad`/`OnCreate`; `WaferAlignData\*` → `OnRun`
- **Sensitivity:** Critical — incorrect alignment offsets produce systematic inspection errors or robot crashes
- **Monitor priority:** P1 (params) + P1 (WaferAlignData runtime)
- **Key fields to watch:** `[WAFER ALIGNMENT]` X/Y/Theta offsets, `[DIE Alignment]` parameters, PatFind results in `Alignment_PatRes.txt`
- **Notes:** `WaferAlignData\*` files are **overwritten every run** — store the hash and content at each overwrite to track alignment drift over time

---

### Config / Illumination — RMS / DataServer (P1, Critical)

- **File pattern:** `c:\job\<Job>\<Setup>\Recipes\<R>\OpticPreset.ini`, `JobIllumLimits.ini`, `OpticLightMetadata\config.ini`
- **Typical count per job:** 3 files per recipe
- **Write pattern:** `OnLoad` — illumination settings applied when recipe is loaded
- **Sensitivity:** Critical — wrong illumination settings directly affect image quality and defect detection rates
- **Monitor priority:** P1
- **Key fields to watch:** `[IllumConversion]` gain/exposure values, `[AMITA1]` min/max limits, channel intensities in `config.ini`
- **Notes:** `JobIllumLimits.ini` is created on first load if absent; `OpticPreset.ini` size varies significantly between recipes (1,547 B vs 2,302 B) indicating different illumination configurations

---

### Config / Machine State — Falcon.Net (P1, High)

- **File pattern:** `c:\job\status.ini`
- **Typical count:** 1 (global singleton)
- **Write pattern:** `OnRun` (continuously updated on every machine-state transition)
- **Sensitivity:** High — reflects which recipe/job is currently active; required for traceability
- **Monitor priority:** P1
- **Key fields to watch:** `[UC_PROGRAM]` section — program name, state, version
- **Notes:** Updated very frequently during active scan; consider storing change events with debounce (e.g., 500 ms) rather than every byte-level change

---

### Job Metadata — RMS (P1, High)

- **File pattern:** `c:\job\<Job>\Metadata.ini`, `c:\job\<Job>\<Setup>\Metadata.ini`, `c:\job\<Job>\<Setup>\ProductionInfo.ini`
- **Typical count:** 2–3 per job
- **Write pattern:** `OnCreate`; `ProductionInfo.ini` also `OnLoad` (Modified post-copy)
- **Sensitivity:** High — job identity and traceability data
- **Monitor priority:** P1
- **Key fields to watch:** `[General]` — job name, version, creation date

---

### Recipe — RMS (P2, High) — supporting files

- **File pattern:** `DefaultWafer2Table.ini`, `AlignmentData.ini`, `CcsLocalMeas.ini`, `CleanReference*.ini`, `CreateReference3dOptions.ini`, `OverlayScan.ini`, `SamplingMetrology.ini`, `UniqueArea.ini`, `WaferDataReadSettings.xml`, `WaferToRefWafer.ini`, `DieAlignment.dat_block.ini`, `ScenariosMetadatas.ini`, `zones.txt`, `DieMapRegPos.txt`, `DieRegPos.txt`
- **Typical count per recipe:** ~15 files
- **Write pattern:** `OnCreate` — set at recipe authoring time, not updated during normal operation
- **Sensitivity:** High — support correct recipe operation but not safety-critical
- **Monitor priority:** P2 (record hash + diff; full content optional)

---

### AlignmentData / FocusMapping — AOI_Main (P2, High)

- **File pattern:** `FocusMapping\FocusMapping.ini`, `FocusMapping\DieReferenceLocation.json`, `FocusMapping\FocusPointsForScan.xml`, `FocusMapping\Model_<guid>\FocusModel.ini`, `TrainData\Die.ini`, `TrainData\FrameToChuck.ini`, `CurrWaferSurfaceInterpolation.*`
- **Typical count per recipe:** ~6–8 files
- **Write pattern:** `OnEvent` (focus-teach or training workflow)
- **Sensitivity:** High — incorrect focus mapping causes out-of-focus scans
- **Monitor priority:** P2
- **Key fields to watch:** Mode flags in `FocusMapping.ini`, model GUID path, die reference coordinates

---

### Recipe — DieMap / Spatial data (P2, High)

- **File pattern:** `DieMapping.dat`, `DieRegPos.dat`, `DieMapRegPos.dat`, `WaferInfo.dat`, `zones.dat`, `Job.dat` (text-passing .dat files)
- **Typical count per recipe:** 5–8 files
- **Write pattern:** `OnCreate`
- **Sensitivity:** High — die map defines which dice are inspected and their positions
- **Monitor priority:** P2 — hash on change; no diff (binary-structured content)
- **Notes:** These files passed the text heuristic but are structured binary with ASCII headers. Store SHA-256 hash only; do NOT attempt to store text diff.

---

### Transaction Cache / Internal — RMS / AOI_Main (P2, Medium)

- **File pattern:** `.dc_cache\TransactionsHistory.ini`
- **Typical count per recipe:** 1
- **Write pattern:** `OnEvent` (recipe save/commit)
- **Sensitivity:** Medium — records recipe-change history internally
- **Monitor priority:** P2

---

### ScanResult / Log — AOI_Main (P3–P4, Low)

- **File pattern:** `ScanOverlapLog.txt`, `ScanOverviewImage_*.txt`, `s_FrameData.dat.md`, `ScenarioMetadataGrab.xml`, `ReferenceBackup\*`, `SW_QA-*\*`, `TrainData\DieImage\*`, `Metadata.ini` (recipe level)
- **Write pattern:** `OnClose` / `OnEvent` / `OnCreate`
- **Sensitivity:** Low–Medium
- **Monitor priority:** P3 (existence of change noted; no diff)

- **File pattern:** `ImageProcessing.log`, `DebugAFMapping\FocusMappingDebug_*.txt`
- **Write pattern:** `OnEvent` (appended during run)
- **Sensitivity:** Low
- **Monitor priority:** P4 — skip; noisy and low audit value

---

## Section 4 — Monitoring Scope Summary

| Decision | File groups | Reason |
|---|---|---|
| **Monitor P1** | `status.ini`; all `Recipe.ini`, `GlobalRTP.ini`, `RTP.txt`, `ZoomLevels.ini`, `zones.ini`, `Zones\*.ini`, `MultiRecipe.ini`, `ScanCondition.ini`, `WaferMapRecipe.ini`; `Wafer2Table.ini` (setup + recipe), `Alignment.ini`, `AlignRtp.ini`, `Params_AlignRTP.ini`, `WaferAlignData\AlignmentData.ini`; `OpticPreset.ini`, `JobIllumLimits.ini`; `Metadata.ini` (job + setup), `ProductInfo.ini`, `Waferinfo.ini`, `Params_SystemInfo.ini`, `Params_WaferInfo.ini`, `OpticToVCamStorage.json` | Changes here directly affect inspection correctness, machine safety, or recipe traceability — must be audited immediately with full content snapshot |
| **Monitor P2** | `DefaultWafer2Table.ini`, `AlignmentData.ini`, `CcsLocalMeas.ini`, `CleanReference*.ini`, `CreateReference3dOptions.ini`, `OverlayScan.ini`, `SamplingMetrology.ini`, `UniqueArea.ini`, `WaferDataReadSettings.xml`, `WaferToRefWafer.ini`, `ScenariosMetadatas.ini`, `zones.txt`, `DieMapRegPos.txt`, `DieRegPos.txt`; FocusMapping files; TrainData files; `.dc_cache\TransactionsHistory.ini`; text-passing `.dat` files; `WaferAlignData\Alignment_*.txt`; `ReferencesInfo.json`, `OpticLightMetadata\config.ini`, `CurrWaferSurfaceInterpolation.*`, `DieAlignment.dat` | Change affects repeatability or debug traceability; hash recorded, content diff optional |
| **Skip P3/P4** | `ScanOverlapLog.txt`, `ScanOverviewImage_*.txt`, `ImageProcessing.log`, `DebugAFMapping\*.txt`, `ReferenceBackup\*.ini`, `SW_QA-*\*.ini`, `TrainData\DieImage\*.ini`, `s_FrameData.dat.md`, `ScenarioMetadataGrab.xml`, `VcamInstallerGuid.txt`, `Metadata.ini` (recipe level only) | Informational or debug output — low audit value, potentially noisy (especially logs) |

### File count by priority

| Priority | File patterns | Approx. file instances across all 3 jobs |
|---|---|---|
| P1 | ~22 patterns | ~80 files |
| P2 | ~30 patterns | ~110 files |
| P3/P4 | ~15 patterns | ~47 files |
| **Total monitored (P1+P2)** | | **~190 files** |

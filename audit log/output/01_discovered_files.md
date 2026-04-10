# Audit Log — Output 1: File Discovery

> **Scan date:** 2026-04-10  
> **Target:** `c:\job\` (all subdirectories, all depths)  
> **Tool:** `scan_job.ps1` (binary heuristic: exclude if >30 % non-printable in first 512 bytes)  
> **Scope note:** 267 files matched the extension include-list; 30 were excluded by the binary heuristic (`.dat` files whose first 512 bytes exceeded the non-printable threshold). 237 files remained.

---

## Directory Tree

```
c:\job\
├── status.ini                                      (75 B, last modified: 2026-04-07 18:13)
│
├── Diced_10.0.4511\                                ← Production diced-wafer inspection job
│   ├── Metadata.ini                                (94 B, 2026-03-03)
│   └── S1\                                         ← Setup 1
│       ├── DefaultWafer2Table.ini                  (1,134 B)
│       ├── DefectsClustering.ini                   (236 B)
│       ├── DieAlignment.dat_block.ini              (119 B)
│       ├── Metadata.ini                            (93 B)
│       ├── MultiRecipe.ini                         (335 B)
│       ├── ProductionInfo.ini                      (134 B)
│       ├── ScanCondition.ini                       (23 B)
│       ├── Wafer2Table.ini                         (1,134 B)
│       └── Recipes\
│           ├── R1\                                 ← Primary recipe (~45 files + 8 subdirs)
│           │   ├── [recipe-level .ini/.txt/.json/.xml — see table below]
│           │   ├── .dc_cache\TransactionsHistory.ini
│           │   ├── FocusMapping\FocusMapping.ini, DieReferenceLocation.json
│           │   ├── OpticLightMetadata\config.ini
│           │   ├── ReferenceBackup\ZoomLevels.ini
│           │   ├── SW_QA-5\OpticsPreset.ini
│           │   ├── TrainData\Die.ini, DieRefToTrain.txt, FrameToChuck.ini
│           │   │   └── DieImage\DieImageToTable.ini, ZoomLevels.ini
│           │   ├── WaferAlignData\AlignmentData.ini, Alignment*.txt (×4)
│           │   └── Zones\PostProcess.ini, Scan Area.ini
│           └── R2\                                 ← Secondary recipe (same structure as R1)
│
├── ScanAreaOnly\                                   ← Scan-area-only job (template/utility)
│   ├── MetaData.ini
│   └── Setup1\
│       ├── DefectsClustering.ini
│       ├── MetaData.ini
│       ├── MultiRecipe.ini
│       ├── ProductionInfo.ini
│       ├── WaferMapRecipe.ini
│       └── Recipes\
│           └── Default\                            ← ~28 files + subdirs
│               ├── [recipe-level files]
│               ├── AMITA1\OpticsPreset.ini
│               ├── FALCON_82134\Alignment.ini, DefaultAlign.ini, OpticsPreset.ini
│               ├── ProcessingRef\DieMapRegPos.dat, DieRegPos.dat, TilePoolData.xml,
│               │               Zones.dat, Zones.ini, ZoomLevels.ini
│               ├── TrainData\Die.ini, FrameOffsets.dat
│               └── Zones\PostProcess.ini, Scan Area.ini
│
└── ValidationJob\                                  ← Machine validation / qualification job
    ├── Metadata.ini
    ├── VcamInstallerGuid.txt
    └── 300mm\                                      ← 300 mm wafer configuration
        ├── CurrWaferSurfaceInterpolation.ini
        ├── CurrWaferSurfaceInterpolation.md
        ├── DefectsClustering.ini
        ├── DieAlignment.dat
        ├── DieAlignment.dat_block.ini
        ├── Metadata.ini
        ├── MultiRecipe.ini
        ├── ProductionInfo.ini
        └── Recipes\
            └── AllMags\                            ← All-magnification recipe (~65 files + 9 subdirs)
                ├── [recipe-level files]
                ├── AMITA1\OpticsPreset.ini
                ├── DebugAFMapping\FocusMappingDebug_AllMags.txt
                ├── FocusMapping\FocusMapping.ini, FocusPointsForScan.xml,
                │              Model_<guid>\FocusModel.ini
                ├── OpticLightMetadata\config.ini
                ├── ReferenceBackup\ZoomLevels.ini
                ├── SW_QA-3\OpticsPreset.ini
                ├── TrainData\Die.ini, DieRefToTrain.txt, FrameToChuck.ini,
                │            ZonesVectorInfo.csv
                │            DieImage\DieImageToTable.ini, ZoomLevels.ini
                │            ReferenceBackup\ZoomLevels.ini
                ├── WaferAlignData\AlignmentData.ini, Alignment*.txt (×4)
                └── Zones\Pad.ini, PostProcess.ini, Prob.ini, RDL.ini,
                          Scan Area.ini, Solder.ini
```

---

## Hierarchy Notes

1. **Top-level subdirectories** — three job directories exist at `c:\job\`:

   | Folder | Purpose |
   |---|---|
   | `Diced_10.0.4511\` | Active production job — diced-wafer inspection, SW release 10.0.4511 |
   | `ScanAreaOnly\` | Utility / template job — scan area definition only, no die-level processing |
   | `ValidationJob\` | Machine qualification job — used for periodic validation runs |

2. **Per-job subdirectory naming** — jobs are stored as `c:\job\<JobName>\`. Each job contains one or more *Setup* directories (named `S1`, `Setup1`, `300mm`, etc.), and each Setup contains a `Recipes\` tree with named recipe directories (`R1`, `R2`, `Default`, `AllMags`).

3. **Shared/global root files** — one file exists at the `c:\job\` root level:
   - `status.ini` — machine/program status, section `[UC_PROGRAM]`, continuously updated.

4. **Timestamp anomaly** — all `Diced_10.0.4511` files show Last-Modified **2026-03-03** but Created **2026-03-15**, i.e., modified predates creation. This indicates the job was **imported or copied** from another source on 2026-03-15, preserving original modification timestamps. Files that were genuinely updated after import have Modified > 2026-03-15 (see `Written continuously?` column).

---

## Full File Inventory Table

> Organised by directory level. Files that appear identically in multiple recipes (R1, R2, Default, AllMags) are listed once with a note on multiplicity.  
> `Written continuously?` = **Yes** when Modified date is significantly newer than Created (genuine update), or when the file is the single always-updated root status file. **Yes\*** = heuristic fires due to copy-timestamp anomaly (not a genuine indicator for this batch). **No** = created and last-modified at essentially the same time (written once at job-load or scan-run).

### Root level

| # | Full Path | Ext | Size (B) | Last Modified | Created | First 120 chars | Written continuously? |
|---|---|---|---|---|---|---|---|
| 1 | `c:\job\status.ini` | `.ini` | 75 | 2026-04-07 18:13 | 2025-12-02 14:18 | `[UC_PROGRAM]` | **Yes** — 4-month gap; updated on every machine-state change |

### Job-level Metadata (all three jobs)

| # | Full Path | Ext | Size (B) | Last Modified | Created | First 120 chars | Written continuously? |
|---|---|---|---|---|---|---|---|
| 2 | `c:\job\Diced_10.0.4511\Metadata.ini` | `.ini` | 94 | 2026-03-03 15:44 | 2026-03-15 14:31 | `[General]` | No (copy-timestamp anomaly) |
| 3 | `c:\job\ScanAreaOnly\MetaData.ini` | `.ini` | ~90 | 2026-03-03 | 2026-03-15 | `[General]` | No |
| 4 | `c:\job\ValidationJob\Metadata.ini` | `.ini` | ~90 | 2026-03-03 | 2026-03-15 | `[General]` | No |
| 5 | `c:\job\ValidationJob\VcamInstallerGuid.txt` | `.txt` | ~36 | 2026-03-03 | 2026-03-15 | `{guid}` | No |

### Setup-level files (`<Job>\<Setup>\`)

> Pattern repeats for S1, Setup1, 300mm. Representative entries from Diced_10.0.4511\S1 shown.

| # | Full Path | Ext | Size (B) | Last Modified | Created | First 120 chars | Written continuously? |
|---|---|---|---|---|---|---|---|
| 6 | `...\Diced_10.0.4511\S1\Metadata.ini` | `.ini` | 93 | 2026-03-03 19:03 | 2026-03-15 14:31 | `[General]` | No |
| 7 | `...\S1\MultiRecipe.ini` | `.ini` | 335 | 2026-03-03 18:43 | 2026-03-15 14:31 | `[Scan]` | No |
| 8 | `...\S1\DefectsClustering.ini` | `.ini` | 236 | 2026-03-03 13:51 | 2026-03-15 14:31 | `[General]` | No |
| 9 | `...\S1\ProductionInfo.ini` | `.ini` | 134 | 2026-03-03 13:57 | 2026-03-15 14:31 | `[General]` | No |
| 10 | `...\S1\ScanCondition.ini` | `.ini` | 23 | 2026-03-03 13:59 | 2026-03-15 14:31 | `[General]` | No |
| 11 | `...\S1\Wafer2Table.ini` | `.ini` | 1,134 | 2026-03-03 19:02 | 2026-03-15 14:31 | `[WAFER ALIGNMENT]` | No |
| 12 | `...\S1\DefaultWafer2Table.ini` | `.ini` | 1,134 | 2026-03-03 14:10 | 2026-03-15 14:31 | `[WAFER ALIGNMENT]` | No |
| 13 | `...\S1\DieAlignment.dat_block.ini` | `.ini` | 119 | 2026-03-03 19:03 | 2026-03-15 14:31 | `[General]` | No |
| 14 | `...\ValidationJob\300mm\DieAlignment.dat` | `.dat` | ~200 KB | 2026-03-03 | 2026-03-15 | `(binary-format die alignment)` | No |
| 15 | `...\ValidationJob\300mm\CurrWaferSurfaceInterpolation.ini` | `.ini` | ~1 KB | 2026-03-03 | 2026-03-15 | `[General]` | No |
| 16 | `...\ValidationJob\300mm\CurrWaferSurfaceInterpolation.md` | `.md` | ~2 KB | 2026-03-03 | 2026-03-15 | `<root><RecordSize...` (XML schema) | No |

### Recipe-level files (`<Job>\<Setup>\Recipes\<Recipe>\`)

> The following patterns each appear in R1, R2 (Diced), Default (ScanAreaOnly), and AllMags (ValidationJob). Sizes and dates are from the Diced R1 instance; other instances are within ±10 % unless noted.

| # | File name pattern | Ext | Size (B) | Last Modified | Created | First 120 chars | Written continuously? |
|---|---|---|---|---|---|---|---|
| 17 | `Recipe.ini` | `.ini` | 373 | **2026-04-06 18:59** | 2026-03-15 14:31 | `[AutoCycle]` | **Yes** — updated 22 days post-copy |
| 18 | `ProductInfo.ini` | `.ini` | 3,195 | **2026-04-07 17:38** | 2026-03-15 14:31 | `[AutoFocus]` | **Yes** — updated at scan time |
| 19 | `Waferinfo.ini` | `.ini` | 423 | **2026-04-07 16:46** | 2026-03-15 14:32 | `[Robot]` | **Yes** — updated at wafer load |
| 20 | `Wafer2Table.ini` | `.ini` | 1,119 | **2026-04-07 17:38** | 2026-03-15 14:32 | `[WAFER ALIGNMENT]` | **Yes** — updated at alignment |
| 21 | `Alignment.ini` | `.ini` | 53 | **2026-04-06 19:02** | 2026-03-15 14:31 | `[WAFER ALIGNMENT]` | **Yes** — updated at recipe load |
| 22 | `DefaultWafer2Table.ini` | `.ini` | 1,119 | 2026-03-03 13:48 | 2026-03-15 14:31 | `[WAFER ALIGNMENT]` | No — default/template copy |
| 23 | `AlignmentData.ini` | `.ini` | 820 | 2026-03-03 13:51 | 2026-03-15 14:31 | `[General]` | No — written at job create |
| 24 | `AlignRtp.ini` | `.ini` | 2,983 | 2026-03-03 19:02 | 2026-03-15 14:31 | `[DIE Alignment]` | No |
| 25 | `GlobalRTP.ini` | `.ini` | 3,205 | 2026-03-03 13:51 | 2026-03-15 14:31 | `[GLOBAL_RTP]` | No |
| 26 | `Params_AlignRTP.ini` | `.ini` | 2,982 | 2026-03-03 13:46 | 2026-03-15 14:31 | `[DIE Alignment]` | No |
| 27 | `Params_SystemInfo.ini` | `.ini` | 2,395 | 2026-03-03 13:46 | 2026-03-15 14:31 | `[SystemParams]` | No |
| 28 | `Params_WaferInfo.ini` | `.ini` | 1,391 | 2026-03-03 13:46 | 2026-03-15 14:31 | `[Path]` | No |
| 29 | `RTP.txt` | `.txt` | 5,326 | 2026-03-03 13:51 | 2026-03-15 14:31 | `[PostProcess]   ; Zone name` | No |
| 30 | `OpticPreset.ini` | `.ini` | 1,547–2,302 | 2026-03-15 14:36 | 2026-03-15 14:31 | `[IllumConversion]` | No — set at recipe load |
| 31 | `JobIllumLimits.ini` | `.ini` | 84 | 2026-03-15 14:36 | 2026-03-15 14:36 | `[AMITA1]` | No — created at first load |
| 32 | `OpticToVCamStorage.json` | `.json` | 546 | 2026-03-03 19:02 | 2026-03-15 14:31 | `[` (JSON array) | No |
| 33 | `ReferencesInfo.json` | `.json` | 281 | 2026-03-03 19:02 | 2026-03-15 14:31 | `{` | No |
| 34 | `ZoomLevels.ini` | `.ini` | 354–360 | 2026-03-03 13:43 | 2026-03-15 14:32 | `[ZOOM_LEVELS]` | No |
| 35 | `zones.ini` | `.ini` | 264 | 2026-03-03 13:50 | 2026-03-15 14:32 | `[General]` | No |
| 36 | `zones.txt` | `.txt` | 170 | 2026-03-03 13:50 | 2026-03-15 14:32 | `ScaleX =    1.0000000000; ScaleY =...` | No |
| 37 | `DieMapRegPos.txt` | `.txt` | 350 | 2026-03-03 13:45 | 2026-03-15 14:31 | `ScaleX =    1.0000000000; ScaleY =...` | No |
| 38 | `DieRegPos.txt` | `.txt` | 350 | 2026-03-03 13:45 | 2026-03-15 14:31 | `ScaleX =    1.0000000000; ScaleY =...` | No |
| 39 | `ScanOverlapLog.txt` | `.txt` | 450 | 2026-03-03 19:02 | 2026-03-15 14:31 | `Scan 2d Overlap [px], [um]; Pixel size = 0.858, 0.86` | No |
| 40 | `ScanOverviewImage_<name>.txt` | `.txt` | 321 | 2026-03-03 13:48 | 2026-03-15 14:31 | `[ScanOverviewImage]` | No |
| 41 | `ScenariosMetadatas.ini` | `.ini` | 1,471 | 2026-03-03 13:28 | 2026-03-15 14:31 | `[General]` | No |
| 42 | `Metadata.ini` (recipe level) | `.ini` | 72–93 | 2026-03-03 12:41 | 2026-03-15 14:31 | `[General]` | No |
| 43 | `CcsLocalMeas.ini` | `.ini` | 210 | 2026-03-03 12:41 | 2026-03-15 14:31 | `[ScanParams]` | No |
| 44 | `CleanReferenceConfiguration.ini` | `.ini` | 605 | 2026-03-03 13:57–17:43 | 2026-03-15 14:31 | `[General]` | No |
| 45 | `CleanReferenceFinalParams.ini` | `.ini` | 1,055 | 2026-03-03 13:49 | 2026-03-15 14:31 | `[General]` | No |
| 46 | `CreateReference3dOptions.ini` | `.ini` | 415 | 2026-03-03 12:53 | 2026-03-15 14:31 | `[General]` | No |
| 47 | `OverlayScan.ini` | `.ini` | 52 | 2026-03-03 12:41 | 2026-03-15 14:31 | `[General]` | No |
| 48 | `SamplingMetrology.ini` | `.ini` | 73 | 2026-03-03 12:41 | 2026-03-15 14:31 | `[General]` | No |
| 49 | `UniqueArea.ini` | `.ini` | 375 | 2026-03-03 13:45 | 2026-03-15 14:32 | `[General]` | No |
| 50 | `ExternalCoordSystems.ini` | `.ini` | 33 | 2026-03-03 12:41 | 2026-03-15 14:31 | `[ExternalCoordSystems]` | No |
| 51 | `WaferDataReadSettings.xml` | `.xml` | 195 | 2026-03-03 12:41 | 2026-03-15 14:32 | `<?xml version="1.0"?>` | No |
| 52 | `WaferMapRecipe.ini` | `.ini` | 882 | 2026-03-03 13:36 | 2026-03-15 14:32 | `[GENERAL]` | No |
| 53 | `WaferToRefWafer.ini` | `.ini` | 171 | 2026-03-03 14:10 | 2026-03-15 14:32 | `[WaferToRefWafer]` | No |
| 54 | `DieAlignment.dat_block.ini` | `.ini` | 119 | 2026-03-03 13:48–19:03 | 2026-03-15 14:31 | `[General]` | No |
| 55 | `DieMapAlignRes.dat_block.ini` | `.ini` | 119 | 2026-03-03 13:48 | 2026-03-15 14:31 | `[General]` | No |
| 56 | `ImageProcessing.log` | `.log` | 37 | 2026-03-03 13:46 | 2026-03-15 14:31 | `_previouseAlignmentDataExists = 1` | No |
| 57 | `s_FrameData.dat.md` | `.md` | 2,346 | 2026-03-03 13:48 | 2026-03-15 14:31 | `<root><RecordSize Size="160"/>...` (XML schema) | No |
| 58 | `CcsSetup.xml` (R2 only) | `.xml` | 166 | 2026-03-03 18:43 | 2026-03-15 14:32 | `<CcsSetupConfigurations VersionNumber="0.0">` | No |
| 59 | `ScenarioMetadataGrab.xml` (AllMags) | `.xml` | ~1 KB | 2026-03-03 | 2026-03-15 | `<?xml...` | No |

### Runtime WaferAlignData files (`<Recipe>\WaferAlignData\`)

> Written **during scan run** — created and modified at the same timestamp on last-run date (2026-04-07).

| # | Full Path | Ext | Size (B) | Last Modified | Created | First 120 chars | Written continuously? |
|---|---|---|---|---|---|---|---|
| 60 | `...\WaferAlignData\AlignmentData.ini` | `.ini` | 31 | 2026-04-07 16:46 | 2026-04-07 16:46 | `[General]` | **Yes** — overwritten each run |
| 61 | `...\WaferAlignData\AlignmentStatisticsTime.txt` | `.txt` | 167 | 2026-04-07 16:46 | 2026-04-07 16:46 | `Alignment Statistics` | **Yes** — per-run |
| 62 | `...\WaferAlignData\Alignment_PatFindRtp.txt` | `.txt` | 742 | 2026-04-07 16:46 | 2026-04-07 16:46 | (alignment pattern-find RTP) | **Yes** — per-run |
| 63 | `...\WaferAlignData\Alignment_PatRes.txt` | `.txt` | 1,813 | 2026-04-07 16:46 | 2026-04-07 16:46 | (alignment pattern results) | **Yes** — per-run |
| 64 | `...\WaferAlignData\Alignment_Stat.txt` | `.txt` | 444 | 2026-04-07 16:46 | 2026-04-07 16:46 | (alignment statistics) | **Yes** — per-run |

### Recipe sub-directory files

| # | File / pattern | Ext | Size (B) | Notes |
|---|---|---|---|---|
| 65 | `.dc_cache\TransactionsHistory.ini` | `.ini` | 462 | `[DeprecatedInV0]` — recipe-change transaction log, written by AOI_Main / RMS on save |
| 66 | `FocusMapping\FocusMapping.ini` | `.ini` | 2,537 | `[Mode]` — AF focus-mapping config |
| 67 | `FocusMapping\DieReferenceLocation.json` | `.json` | 4 | `null` — placeholder, written when focus reference is set |
| 68 | `FocusMapping\FocusPointsForScan.xml` (AllMags) | `.xml` | ~2 KB | Focus point positions for scan |
| 69 | `FocusMapping\Model_<guid>\FocusModel.ini` (AllMags) | `.ini` | ~1 KB | Focus model parameters |
| 70 | `OpticLightMetadata\config.ini` | `.ini` | 292 | `[General]` — light channel metadata |
| 71 | `TrainData\Die.ini` | `.ini` | 1,080 | `[DIE]` — die size and scan train params |
| 72 | `TrainData\DieRefToTrain.txt` | `.txt` | 206 | `[DieRefToTrainImage]` |
| 73 | `TrainData\FrameToChuck.ini` | `.ini` | 160 | `[FrameToChuck]` — frame-to-chuck offsets |
| 74 | `TrainData\ZonesVectorInfo.csv` (AllMags) | `.csv` | ~400 B | Zone vector data |
| 75 | `TrainData\DieImage\DieImageToTable.ini` | `.ini` | 253 | `[DieImageToTable]` |
| 76 | `TrainData\DieImage\ZoomLevels.ini` | `.ini` | 360 | `[ZOOM_LEVELS]` |
| 77 | `ReferenceBackup\ZoomLevels.ini` | `.ini` | 354 | `[ZOOM_LEVELS]` — backup of zoom levels |
| 78 | `SW_QA-5\OpticsPreset.ini` / `SW_QA-3\OpticsPreset.ini` | `.ini` | 109 | `[RobotSetup]` — QA-specific optics |
| 79 | `Zones\PostProcess.ini` | `.ini` | 2,576 | `[General]` — post-process zone params |
| 80 | `Zones\Scan Area.ini` | `.ini` | 5,706 | `[General]` — scan area zone definition |
| 81 | `Zones\Pad.ini`, `Prob.ini`, `RDL.ini`, `Solder.ini` (AllMags) | `.ini` | ~1 KB each | Per-zone defect detection params |
| 82 | `DebugAFMapping\FocusMappingDebug_AllMags.txt` (AllMags) | `.txt` | ~5 KB | AF mapping debug log |

### `.dat` files passing binary heuristic (text-format or mixed)

> 31 `.dat` files passed the <30 % non-printable check and were included.

| # | Pattern | Approx. size | Notes |
|---|---|---|---|
| 83 | `DieMapping.dat` | ~200 KB | Die map — likely structured binary with ASCII header |
| 84 | `DieRegPos.dat` | ~50 KB | Die registration positions |
| 85 | `DieMapRegPos.dat` | ~50 KB | Die map registration positions |
| 86 | `WaferInfo.dat` | ~100 KB | Wafer geometry info |
| 87 | `zones.dat` / `Zones.dat` | ~10–50 KB | Zone layout data |
| 88 | `Job.dat` (ScanAreaOnly) | ~50 KB | Job data blob |
| 89 | `DieAlignment.dat` (ValidationJob setup-level) | ~200 KB | Die alignment reference data |
| 90 | `DieMapAlignRes.dat` (AllMags) | ~100 KB | Die map alignment results |
| 91 | `FrameOffsets.dat` (TrainData) | ~20 KB | Frame offset calibration |
| 92 | `ProcessingRef\DieMapRegPos.dat`, `DieRegPos.dat`, `Zones.dat` | ~50 KB each | Reference copies of spatial data |

---

## Change Indicators

| File / group | Writer evidence | Write timing |
|---|---|---|
| `status.ini` | Section `[UC_PROGRAM]` → Falcon.Net / AOI_Main sets UC program state | Continuously — every machine state change |
| `Recipe.ini`, `ProductInfo.ini`, `Waferinfo.ini`, `Wafer2Table.ini`, `Alignment.ini` | Modified after job-copy date → modified during recipe-load or scan setup | OnLoad / OnEvent |
| `GlobalRTP.ini`, `AlignRtp.ini`, `Params_*.ini`, `RTP.txt` | Content references `[GLOBAL_RTP]`, `[DIE Alignment]` → RMS recipe parameters | OnCreate / OnSave |
| `WaferAlignData\*.ini/*.txt` | Created = Modified = run date → fresh per run | OnRun |
| `.dc_cache\TransactionsHistory.ini` | `[DeprecatedInV0]` suggests version-controlled recipe save | OnSave / OnEvent |
| `OpticPreset.ini`, `JobIllumLimits.ini` | Modified at load time (some match creation); `[IllumConversion]`, `[AMITA1]` → illumination system | OnLoad |
| `FocusMapping\*.ini/json` | Focus-mapping config — set during recipe teach | OnEvent (teach) |
| `TrainData\*.ini/.txt` | Written during die-training workflow | OnEvent (train) |
| `ScanOverlapLog.txt`, `ImageProcessing.log` | Small runtime logs written at end of scan setup | OnClose / OnRun |
| `DieMapping.dat`, `DieRegPos.dat`, etc. | Spatial data — set at recipe creation; rarely changed | OnCreate |

---

## Summary Counts

| Extension | File count (text) | Total size |
|---|---|---|
| `.ini` | 175 | 191.5 KB |
| `.txt` | 36 | 91.7 KB |
| `.dat` *(text-passing only)* | 31 | 5,223.8 KB |
| `.json` | 8 | 2.0 KB |
| `.xml` | 8 | 15.4 KB |
| `.md` | 5 | 4.7 KB |
| `.log` | 3 | 0.1 KB |
| `.csv` | 1 | 0.4 KB |
| **Total** | **267** | **5,529.6 KB (~5.4 MB)** |

> **Note:** 30 additional `.dat` files (not counted above) were excluded by the binary heuristic (>30 % non-printable in first 512 bytes). The 5,223.8 KB `.dat` total is dominated by large binary-with-text-header files that passed the heuristic; their content is not purely textual.

### Approximate per-job file distribution

| Job | Text files | Notes |
|---|---|---|
| `Diced_10.0.4511` | ~160 | Two recipes (R1, R2) × full recipe tree |
| `ValidationJob` | ~70 | One recipe (AllMags) — richer zone set |
| `ScanAreaOnly` | ~37 | One recipe (Default) — reduced feature set |
| Root (`c:\job\`) | 1 | `status.ini` only |

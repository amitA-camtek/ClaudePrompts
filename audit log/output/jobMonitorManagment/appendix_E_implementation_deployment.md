# Appendix E — Implementation & Deployment Guide

> **Part of:** `jobMonitorManagmentDesign.md`  
> **Target environment:** Camtek Falcon machine — Windows 10 LTSC, x64  
> **Covers:** FalconAuditService (Windows Service) + FalconAuditWebServer (ASP.NET Core)

---

## E.1 — Prerequisites

| Requirement | Minimum | Notes |
|---|---|---|
| OS | Windows 10 LTSC 2019 (10.0.17763) | Service uses Windows-native APIs (FSW, EventLog, SCM) |
| .NET SDK | .NET 6.0 SDK (6.0.x) | Build machine only — runtime is embedded (self-contained) |
| PowerShell | 5.1+ | `install.ps1` requires `-RunAsAdministrator` |
| Disk — `C:\bis\auditlog\` | 2 GB recommended | SQLite shards + logs; grows with job count |
| Disk — `C:\job\` | Existing | Monitored path; service needs read access only |
| Visual Studio / MSBuild | 2022 (17.x) | Or `dotnet` CLI 6.x |
| NuGet packages (build) | Internet or internal feed | `Microsoft.Data.Sqlite`, `DiffPlex`, `Serilog.*` |

---

## E.2 — Repository & Project Structure

```
FalconAudit\
├── FalconAuditService\               ← Windows Service (Appendix B)
│   ├── FalconAuditService.csproj
│   ├── appsettings.json
│   ├── FileClassificationRules.json  (copied to C:\bis\auditlog\ on first install)
│   ├── ParameterDescriptions.json    (copied to C:\bis\auditlog\ on first install)
│   ├── Models\
│   │   ├── AuditLogEntry.cs
│   │   ├── FileBaseline.cs
│   │   ├── MonitorConfig.cs
│   │   └── JobManifest.cs
│   ├── ContentCache.cs
│   ├── HashHelper.cs
│   ├── DiffHelper.cs
│   ├── FileClassifier.cs
│   ├── ChangeDescriptionEnricher.cs
│   ├── SqliteRepository.cs
│   ├── ShardRegistry.cs
│   ├── ManifestManager.cs
│   ├── DirectoryWatcher.cs
│   ├── ChangeEvent.cs
│   ├── FileChangeHandler.cs
│   ├── FileMonitorService.cs
│   ├── CatchUpScanner.cs
│   ├── Worker.cs
│   ├── Program.cs
│   └── install.ps1
│
└── FalconAuditWebServer\             ← Read-only query API (Appendix C)
    ├── FalconAuditWebServer.csproj
    ├── appsettings.json
    ├── Models\
    │   ├── AuditEventSummary.cs
    │   └── AuditEventDetail.cs
    ├── JobDiscoveryService.cs
    ├── QueryRepository.cs
    ├── EventsEndpoints.cs
    └── Program.cs
```

---

## E.3 — Build

### E.3.1 — FalconAuditService

```powershell
cd FalconAudit\FalconAuditService

dotnet publish -c Release -r win-x64 --self-contained true `
    /p:PublishSingleFile=true `
    -o C:\build\FalconAuditService
```

Output: `C:\build\FalconAuditService\FalconAuditService.exe` (~35 MB self-contained, includes .NET runtime)

The JSON config files are embedded as `<Content CopyToOutputDirectory="PreserveNewest">` and land alongside the exe.

### E.3.2 — FalconAuditWebServer

```powershell
cd FalconAudit\FalconAuditWebServer

dotnet publish -c Release -r win-x64 --self-contained true `
    /p:PublishSingleFile=true `
    -o C:\build\FalconAuditWebServer
```

Output: `C:\build\FalconAuditWebServer\FalconAuditWebServer.exe`

---

## E.4 — Directory Layout on Target Machine

```
C:\bis\bin\FalconAuditService\        ← service binaries (install destination)
    FalconAuditService.exe

C:\bis\bin\FalconAuditWebServer\      ← web server binaries
    FalconAuditWebServer.exe

C:\bis\auditlog\                       ← runtime data (created by install.ps1)
    global.db                          ← machine-wide audit shard (status.ini events)
    FileClassificationRules.json       ← hot-reloadable classification rules
    ParameterDescriptions.json         ← hot-reloadable parameter labels
    logs\
        falconaudit-YYYYMMDD.log       ← rolling daily log, 31-day retention

C:\job\                                ← monitored path (pre-existing, Falcon-managed)
    <JobName>\
        .audit\
            audit.db                   ← per-job shard (created by service on first event)
            manifest.json              ← chain-of-custody manifest
        Metadata.ini
        ...
```

---

## E.5 — First-Time Installation: FalconAuditService

### Step 1 — Copy binaries

```powershell
# Run as Administrator
$src = 'C:\build\FalconAuditService'
$dst = 'C:\bis\bin\FalconAuditService'

if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
Copy-Item "$src\FalconAuditService.exe" $dst -Force
```

### Step 2 — Run the installer

```powershell
Set-Location $dst
.\install.ps1 -Action Install -InstallPath $dst -DbPath 'C:\bis\auditlog'
```

`install.ps1` performs these steps automatically:

| # | Action |
|---|---|
| 1 | Creates `C:\bis\auditlog\` if absent |
| 2 | Copies `FileClassificationRules.json` and `ParameterDescriptions.json` to `C:\bis\auditlog\` (first install only — does not overwrite) |
| 3 | Grants `NT SERVICE\FalconAuditSvc` read on `C:\job` and modify on `C:\bis\auditlog` via `icacls` |
| 4 | Registers service with SCM (`sc.exe create`) — auto-start, virtual account |
| 5 | Sets 3-stage restart failure policy (5 s → 10 s → 30 s, daily reset) |
| 6 | Starts the service |

### Step 3 — Verify service started

```powershell
Get-Service FalconAuditService | Select-Object Status, StartType
# Expected: Status=Running, StartType=Automatic

# Watch the log for startup confirmation
Get-Content 'C:\bis\auditlog\logs\falconaudit-*.log' -Tail 30
# Expected lines:
#   FalconAuditService starting. WatchPath=c:\job\
#   FalconAuditService FSW live.
#   CatchUpScanner: full reconciliation complete.
#   FalconAuditService running.
```

### Step 4 — Verify SQLite shards

```powershell
# global.db should exist immediately after service start
Test-Path 'C:\bis\auditlog\global.db'   # True

# Per-job shards appear after first file event or catch-up scan
Get-ChildItem 'C:\job\' -Recurse -Filter 'audit.db' | Select-Object FullName
```

---

## E.6 — First-Time Installation: FalconAuditWebServer

### Step 1 — Copy binaries

```powershell
$src = 'C:\build\FalconAuditWebServer'
$dst = 'C:\bis\bin\FalconAuditWebServer'

if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
Copy-Item "$src\FalconAuditWebServer.exe" $dst -Force
```

### Step 2 — Configure `appsettings.json`

Place alongside the exe:

```json
{
  "AuditWebServer": {
    "WatchPath":  "C:\\job",
    "GlobalDb":   "C:\\bis\\auditlog\\global.db"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5100"
      }
    }
  },
  "Logging": {
    "LogLevel": { "Default": "Information" }
  }
}
```

### Step 3 — Register as Windows Service (optional but recommended)

```powershell
# Run as Administrator
$webExe = 'C:\bis\bin\FalconAuditWebServer\FalconAuditWebServer.exe'

sc.exe create FalconAuditWebServer `
    binPath= "`"$webExe`"" `
    start=   auto `
    obj=     "NT SERVICE\FalconAuditWebSvc"

sc.exe description FalconAuditWebServer "Falcon Audit Log read-only HTTP query server."
sc.exe failure      FalconAuditWebServer reset= 86400 actions= restart/5000/restart/10000//0

# Grant the virtual account read on the shard directories
icacls "C:\bis\auditlog" /grant "NT SERVICE\FalconAuditWebSvc:(OI)(CI)R" /T | Out-Null
icacls "C:\job"          /grant "NT SERVICE\FalconAuditWebSvc:(OI)(CI)R" /T | Out-Null

Start-Service FalconAuditWebServer
```

### Step 4 — Verify web server

```powershell
# From the same machine (Windows Auth passes through)
Invoke-WebRequest -Uri 'http://localhost:5100/jobs' -UseDefaultCredentials |
    Select-Object StatusCode, Content
# Expected: 200 with JSON array of job names
```

---

## E.7 — Configuration Reference

### E.7.1 — appsettings.json (FalconAuditService)

Path overrides only. All operational settings live in the `monitor_config` SQL table.

| Key (under `AuditService`) | Default | Purpose |
|---|---|---|
| `GlobalDbPath` | `C:\bis\auditlog\global.db` | Path to machine-wide SQLite shard |
| `ClassificationRulesPath` | `C:\bis\auditlog\FileClassificationRules.json` | Hot-reloadable classification rules |
| `ParameterDescriptionsPath` | `C:\bis\auditlog\ParameterDescriptions.json` | Human-readable parameter labels |

### E.7.2 — monitor_config SQL table (primary config)

Query or update from any SQLite client:

```sql
-- View all settings
SELECT key, value FROM monitor_config ORDER BY key;

-- Common updates
UPDATE monitor_config SET value = '1000' WHERE key = 'debounce_ms';
UPDATE monitor_config SET value = '1'    WHERE key = 'capture_content';
UPDATE monitor_config SET value = '209715200' WHERE key = 'max_content_bytes';  -- 200 MB
```

| Key | Default | Type | Description |
|---|---|---|---|
| `watch_path` | `c:\job` | string | Root folder monitored by FSW |
| `debounce_ms` | `500` | int | FSW debounce delay (ms) |
| `capture_content` | `0` | bool (0/1) | Snapshot file content for P1 files |
| `max_content_bytes` | `52428800` | int | Max file size for content capture (50 MB default) |
| `machine_name` | `%COMPUTERNAME%` | string | Stamped on manifest and audit rows |
| `recovery_delay_ms` | `30000` | int | Delay before full re-hash after FSW overflow |
| `classification_rules_path` | *(from appsettings)* | string | Override classification rules path |
| `parameter_descriptions_path` | *(from appsettings)* | string | Override parameter descriptions path |

> Changes to `monitor_config` take effect on **service restart** (except `classification_rules_path` / `parameter_descriptions_path`, which are consumed only at startup).

### E.7.3 — FileClassificationRules.json

Located at `C:\bis\auditlog\FileClassificationRules.json`. Hot-reloaded within 2 seconds of any change — no service restart required.

To add a new monitored file type, append a rule:

```json
{
  "pattern":         "c:\\job\\**\\MyNewFile.ini",
  "matchType":       "glob",
  "module":          "Recipe",
  "ownerService":    "RMS",
  "monitorPriority": "P2",
  "description":     "My new recipe file",
  "changeSummary":   "Recipe parameter changed"
}
```

Rules are evaluated top-to-bottom; first match wins. More-specific (deeper) patterns must appear before shallower ones.

---

## E.8 — Upgrade Procedure

> Upgrades are zero-downtime for the web server (read-only process). The service requires a brief stop (typically < 5 seconds).

### E.8.1 — FalconAuditService upgrade

```powershell
# 1. Stop service
Stop-Service FalconAuditService -Force
Write-Host "Service stopped."

# 2. Back up existing exe
$dst = 'C:\bis\bin\FalconAuditService'
Copy-Item "$dst\FalconAuditService.exe" "$dst\FalconAuditService.exe.bak" -Force

# 3. Copy new exe
Copy-Item 'C:\build\FalconAuditService\FalconAuditService.exe' $dst -Force

# 4. Start service
Start-Service FalconAuditService

# 5. Verify (give it 10 s to run catch-up)
Start-Sleep 10
Get-Service FalconAuditService | Select-Object Status
Get-Content 'C:\bis\auditlog\logs\falconaudit-*.log' -Tail 20
```

**Schema migration** runs automatically on startup. The `MigrateSchema` method detects the current `schema_version` and applies all pending `ALTER TABLE` statements. Existing data is preserved.

### E.8.2 — FalconAuditWebServer upgrade

```powershell
Stop-Service FalconAuditWebServer -Force

$dst = 'C:\bis\bin\FalconAuditWebServer'
Copy-Item "$dst\FalconAuditWebServer.exe" "$dst\FalconAuditWebServer.exe.bak" -Force
Copy-Item 'C:\build\FalconAuditWebServer\FalconAuditWebServer.exe' $dst -Force

Start-Service FalconAuditWebServer
Invoke-WebRequest -Uri 'http://localhost:5100/jobs' -UseDefaultCredentials | Select-Object StatusCode
```

### E.8.3 — Configuration-only update (no binary change)

Edit `FileClassificationRules.json` or `ParameterDescriptions.json` in `C:\bis\auditlog\`. The service picks up the change automatically within 2 seconds. No restart required.

To update `monitor_config` values:

```sql
UPDATE monitor_config SET value = '750' WHERE key = 'debounce_ms';
-- Restart service to apply
Restart-Service FalconAuditService
```

---

## E.9 — Rollback

```powershell
# Service
Stop-Service FalconAuditService -Force
$dst = 'C:\bis\bin\FalconAuditService'
Copy-Item "$dst\FalconAuditService.exe.bak" "$dst\FalconAuditService.exe" -Force
Start-Service FalconAuditService

# Web server
Stop-Service FalconAuditWebServer -Force
$dst = 'C:\bis\bin\FalconAuditWebServer'
Copy-Item "$dst\FalconAuditWebServer.exe.bak" "$dst\FalconAuditWebServer.exe" -Force
Start-Service FalconAuditWebServer
```

> **Schema rollback is not automated.** If a new schema version adds columns, those columns remain after rollback but are ignored by the older binary. This is safe — `DEFAULT` values cover all new `NOT NULL` columns. Never drop columns to roll back.

---

## E.10 — Uninstall

```powershell
# Run as Administrator
Set-Location 'C:\bis\bin\FalconAuditService'
.\install.ps1 -Action Uninstall

Stop-Service FalconAuditWebServer -Force -ErrorAction SilentlyContinue
sc.exe delete FalconAuditWebServer

# Optional: remove data (DESTRUCTIVE — audit history lost)
# Remove-Item 'C:\bis\auditlog' -Recurse -Force
# Get-ChildItem 'C:\job' -Recurse -Filter '.audit' -Directory | Remove-Item -Recurse -Force
```

---

## E.11 — Operational Runbook

### Start / stop

```powershell
Start-Service  FalconAuditService
Stop-Service   FalconAuditService -Force
Restart-Service FalconAuditService

Start-Service  FalconAuditWebServer
Stop-Service   FalconAuditWebServer -Force
```

### View live log

```powershell
Get-Content 'C:\bis\auditlog\logs\falconaudit-*.log' -Tail 50 -Wait
```

### View Windows Event Log (Warnings and above)

```powershell
Get-EventLog -LogName Application -Source FalconAuditService -Newest 20 |
    Format-List TimeGenerated, EntryType, Message
```

### Query audit events (SQLite CLI)

```powershell
# Install sqlite3 if not present: winget install SQLite.SQLite
sqlite3 'C:\job\<JobName>\.audit\audit.db' `
    "SELECT changed_at, event_type, filepath, change_summary FROM audit_log ORDER BY id DESC LIMIT 20;"
```

### Check manifest

```powershell
Get-Content 'C:\job\<JobName>\.audit\manifest.json' | ConvertFrom-Json | Format-List
```

### Disk usage

```powershell
# Total audit data size
(Get-ChildItem 'C:\job' -Recurse -Filter 'audit.db' |
    Measure-Object -Property Length -Sum).Sum / 1MB

# Global DB
(Get-Item 'C:\bis\auditlog\global.db').Length / 1MB
```

---

## E.12 — Smoke Tests

Run after any deployment or upgrade.

### Test 1 — Service is alive

```powershell
(Get-Service FalconAuditService).Status -eq 'Running'    # True
```

### Test 2 — FSW fires and writes an event

```powershell
# Touch a monitored file; wait for debounce + write
$testFile = 'C:\job\TestJob\Metadata.ini'
if (Test-Path $testFile) {
    (Get-Item $testFile).LastWriteTime = Get-Date
    Start-Sleep 2
    sqlite3 "C:\job\TestJob\.audit\audit.db" `
        "SELECT id, event_type, changed_at FROM audit_log ORDER BY id DESC LIMIT 1;"
}
```

### Test 3 — Web server returns jobs

```powershell
$r = Invoke-WebRequest 'http://localhost:5100/jobs' -UseDefaultCredentials
$r.StatusCode -eq 200    # True
($r.Content | ConvertFrom-Json).Count -gt 0    # True if any jobs exist
```

### Test 4 — Events endpoint filters correctly

```powershell
$job = (Invoke-WebRequest 'http://localhost:5100/jobs' -UseDefaultCredentials |
    ConvertFrom-Json | Select-Object -First 1).name

$r = Invoke-WebRequest "http://localhost:5100/events/$job`?limit=5" -UseDefaultCredentials
$r.StatusCode -eq 200
```

### Test 5 — Classification hot-reload

```powershell
# Add a comment to FileClassificationRules.json and save
$rulesFile = 'C:\bis\auditlog\FileClassificationRules.json'
(Get-Content $rulesFile) | Set-Content $rulesFile   # touch/resave
Start-Sleep 3

# Check log for reload confirmation
Select-String 'FileClassifier: rules reloaded' `
    'C:\bis\auditlog\logs\falconaudit-*.log' | Select-Object -Last 1
```

### Test 6 — CatchUp marks backfill rows

```powershell
# After a restart, backfill rows have is_backfill=1
sqlite3 'C:\bis\auditlog\global.db' `
    "SELECT COUNT(*) FROM audit_log WHERE is_backfill = 1;"
# Should be > 0 if any files existed before first install
```

---

## E.13 — Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| Service fails to start | Event Viewer → Application → FalconAuditService | Check WatchPath exists; check ACLs on `C:\bis\auditlog` |
| No events recorded after file change | Log: `FalconAuditService FSW live` present? | Verify FSW not exceeding buffer (`InternalBufferSize`); check debounce_ms |
| `audit.db` not created for a job | Log: `ShardRegistry: failed to open shard` | Check `NT SERVICE\FalconAuditSvc` has write access to `C:\job\<JobName>\.audit\` |
| Web server returns 401 | Windows Authentication not configured for the client | Ensure browser/client is domain-joined; check `UseDefaultCredentials` |
| Web server returns 403 on single-event endpoint | User not in `Auditor` role | Add user to `Auditor` local group or AD group |
| `manifest.json` write warning in log | Temp and target on different volumes | Move `C:\bis\auditlog` to same volume as `C:\job`, or accept the warning |
| FSW overflow in log | Too many file changes in short burst | Increase `InternalBufferSize` in `FileMonitorService`; the `OnError` recovery runs automatically after `recovery_delay_ms` |
| `CatchUpScanner exceeded 5-min limit` | More files than expected | Check job folder size; consider increasing the timeout in `Worker.ExecuteAsync` |
| Old events appear after rollback | Schema columns remain | No action needed — old binary ignores new columns; data is safe |
| `monitor_config` table empty | First-run `LoadConfig` populates defaults | Restart service once; defaults are written on startup |

---

## E.14 — Security Checklist

| Control | Implementation | Verify |
|---|---|---|
| Least-privilege service account | `NT SERVICE\FalconAuditSvc` — read `C:\job`, modify `C:\bis\auditlog` only | `icacls C:\job` shows the grant |
| Read-only web server | SQLite `Mode=ReadOnly`; no write endpoints | Grep source for `INSERT`, `UPDATE`, `DELETE` in `QueryRepository` → 0 matches |
| Windows Authentication | Negotiate middleware; fallback policy requires authenticated user | `GET /jobs` without credentials → 401 |
| `Auditor` role for sensitive content | `[Authorize(Policy="AuditorOnly")]` on single-event endpoint | `GET /event/{job}/{id}` as non-Auditor → 403 |
| Path traversal guard | `Path.GetFullPath(rel).StartsWith(jobRoot)` before query | Request `GET /event/../../../etc` → 400 |
| No LIKE wildcard injection | `instr(filepath, @path)` replaces `LIKE` | SQL in `EventsEndpoints.cs` contains no `LIKE` |
| Audit DB integrity | SHA-256 hash on every event row | `audit_log.sha256_hash` is 64-char hex; non-null for Created/Changed events |

---

## E.15 — File Inventory After Deployment

```
C:\bis\bin\FalconAuditService\
    FalconAuditService.exe          ← single-file self-contained binary

C:\bis\bin\FalconAuditWebServer\
    FalconAuditWebServer.exe        ← single-file self-contained binary

C:\bis\auditlog\
    global.db                       ← created on first service start
    global.db-wal                   ← SQLite WAL file (normal during operation)
    global.db-shm                   ← SQLite shared memory file (normal)
    FileClassificationRules.json    ← copied from install package; user-editable
    ParameterDescriptions.json      ← copied from install package; user-editable
    logs\
        falconaudit-YYYYMMDD.log

C:\job\<each job folder>\
    .audit\
        audit.db                    ← per-job shard; created lazily on first event
        audit.db-wal
        audit.db-shm
        manifest.json               ← chain-of-custody; created on job arrival
```

> The `.audit` subdirectory is created by the service. Falcon job management software (RMS) does not touch it. Moving a job folder to another machine carries the `.audit` directory — and therefore its full history — automatically.

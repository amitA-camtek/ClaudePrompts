# Appendix B — Complete Source Code

> **Belongs to:** `jobMonitorManagmentDesign.md`  
> **Design option implemented:** Option C — Job-Embedded Shard with Custody Manifest  
> **Base:** `04_recommended_design.md` Appendix A, modified for per-job shard architecture  
> **Target:** .NET 6, C# 10, `net6.0-windows`

Files marked **[NEW]**, **[MODIFIED]**, or **[UNCHANGED]**.

---

## B.1 — `FalconAuditService.csproj` [UNCHANGED]

```xml
<Project Sdk="Microsoft.NET.Sdk.Worker">

  <PropertyGroup>
    <TargetFramework>net6.0-windows</TargetFramework>
    <RootNamespace>FalconAuditService</RootNamespace>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>true</PublishSingleFile>
    <AssemblyName>FalconAuditService</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite"                    Version="7.0.*" />
    <PackageReference Include="DiffPlex"                                 Version="1.7.*" />
    <PackageReference Include="Microsoft.Extensions.Hosting.WindowsServices" Version="7.0.*" />
    <PackageReference Include="Serilog.Extensions.Hosting"              Version="7.0.*" />
    <PackageReference Include="Serilog.Sinks.File"                      Version="5.0.*" />
    <PackageReference Include="Serilog.Sinks.EventLog"                  Version="3.1.*" />
  </ItemGroup>

  <ItemGroup>
    <!-- Copy FileClassificationRules.json to output directory -->
    <Content Include="FileClassificationRules.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>

</Project>
```

---

## B.2 — `appsettings.json` [MODIFIED]

Changes from `04_recommended_design.md`: `DbPath` now points to `global.db`; `ClassificationRulesPath` added.

```json
{
  "AuditService": {
    "GlobalDbPath":             "C:\\bis\\auditlog\\global.db",
    "ClassificationRulesPath":  "C:\\bis\\auditlog\\FileClassificationRules.json"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": { "FalconAuditService": "Debug" }
    },
    "WriteTo": [
      {
        "Name": "File",
        "Args": {
          "path": "C:\\bis\\auditlog\\FalconAudit.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30,
          "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}"
        }
      },
      {
        "Name": "EventLog",
        "Args": {
          "source": "FalconAuditService",
          "restrictedToMinimumLevel": "Warning"
        }
      }
    ]
  }
}
```

---

## B.3 — `Models/AuditLogEntry.cs` [UNCHANGED]

```csharp
namespace FalconAuditService.Models;

public record AuditLogEntry
{
    public string  Filepath         { get; init; } = "";
    public string  Filename         { get; init; } = "";
    public string  Extension        { get; init; } = "";
    public string  ChangeType       { get; init; } = "";   // Created|Modified|Deleted|Renamed
    public string? OldHash          { get; init; }
    public string? NewHash          { get; init; }
    public string? OldContent       { get; init; }         // full text before  (P1 only)
    public string? NewContent       { get; init; }         // full text after   (P1 only)
    public string? DiffText         { get; init; }         // unified diff      (P1 Modified only)
    public string  Module           { get; init; } = "Unknown";
    public string  OwnerService     { get; init; } = "Unknown";
    public string  MonitorPriority  { get; init; } = "P3";
    public string  DetectedAt       { get; init; } = "";   // ISO-8601 UTC
    public string  MachineName      { get; init; } = "";
    public string? Note             { get; init; }         // null for live events; "catch-up" for offline-detected
}
```

---

## B.4 — `Models/FileBaseline.cs` [UNCHANGED]

```csharp
namespace FalconAuditService.Models;

public record FileBaseline
{
    public string  Filepath         { get; init; } = "";
    public string  LastHash         { get; init; } = "";
    public string  LastSeen         { get; init; } = "";   // ISO-8601 UTC
    public long    LastSize         { get; init; }
    public string  Module           { get; init; } = "";
    public string  MonitorPriority  { get; init; } = "";
}
```

---

## B.5 — `Models/MonitorConfig.cs` [MODIFIED]

Changes: `DbPath` → `GlobalDbPath`; `ClassificationRulesPath` added.

```csharp
namespace FalconAuditService.Models;

public class MonitorConfig
{
    public string WatchPath               { get; set; } = @"C:\job";
    public string GlobalDbPath            { get; set; } = @"C:\bis\auditlog\global.db";
    public string ClassificationRulesPath { get; set; } = @"C:\bis\auditlog\FileClassificationRules.json";
    public bool   StoreContentP1          { get; set; } = true;
    public long   MaxContentBytes         { get; set; } = 1_048_576;  // 1 MB
    public int    DebounceMs              { get; set; } = 500;
    public int    FswBufferBytes          { get; set; } = 65_536;
    public string MachineName             { get; set; } = System.Net.Dns.GetHostName();
}
```

---

## B.6 — `Models/JobManifest.cs` [NEW]

```csharp
namespace FalconAuditService.Models;

using System.Text.Json.Serialization;

public class JobManifest
{
    [JsonPropertyName("jobName")]
    public string JobName { get; set; } = "";

    [JsonPropertyName("auditDbVersion")]
    public string AuditDbVersion { get; set; } = "1";

    [JsonPropertyName("created")]
    public MachineTimestamp? Created { get; set; }

    [JsonPropertyName("history")]
    public List<HistoryEntry> History { get; set; } = new();
}

public class MachineTimestamp
{
    [JsonPropertyName("machine")]
    public string Machine { get; set; } = "";

    [JsonPropertyName("at")]
    public DateTime At { get; set; }
}

public class HistoryEntry
{
    [JsonPropertyName("machine")]
    public string Machine { get; set; } = "";

    [JsonPropertyName("from")]
    public DateTime From { get; set; }

    [JsonPropertyName("to")]
    public DateTime? To { get; set; }

    [JsonPropertyName("events")]
    public int Events { get; set; }
}
```

---

## B.7 — `ContentCache.cs` [UNCHANGED]

```csharp
namespace FalconAuditService;

using System.Collections.Concurrent;

public class ContentCache
{
    private readonly ConcurrentDictionary<string, string> _store =
        new(StringComparer.OrdinalIgnoreCase);

    public void    Set(string path, string content) => _store[path] = content;
    public string? Get(string path)                 => _store.TryGetValue(path, out var v) ? v : null;
    public void    Remove(string path)              => _store.TryRemove(path, out _);
}
```

---

## B.8 — `HashHelper.cs` [UNCHANGED]

```csharp
namespace FalconAuditService;

using System.Security.Cryptography;

public static class HashHelper
{
    private const int MaxRetries   = 3;
    private const int RetryDelayMs = 100;

    public static string? ComputeSha256(string path)
    {
        for (int attempt = 0; attempt < MaxRetries; attempt++)
        {
            try
            {
                using var fs   = new FileStream(path, FileMode.Open,
                                                FileAccess.Read, FileShare.ReadWrite);
                using var sha  = SHA256.Create();
                byte[]    hash = sha.ComputeHash(fs);
                return Convert.ToHexString(hash).ToLowerInvariant();
            }
            catch (IOException) when (attempt < MaxRetries - 1)
            {
                Thread.Sleep(RetryDelayMs * (attempt + 1));
            }
            catch (Exception)
            {
                return null;
            }
        }
        return null;
    }
}
```

---

## B.9 — `DiffHelper.cs` [UNCHANGED]

```csharp
namespace FalconAuditService;

using System.Text;
using DiffPlex.DiffBuilder;
using DiffPlex.DiffBuilder.Model;

public static class DiffHelper
{
    private const int ContextLines = 3;

    public static string? UnifiedDiff(
        string?  oldText,
        string?  newText,
        string   fileName,
        DateTime oldTime,
        DateTime newTime)
    {
        if (oldText is null || newText is null) return null;

        var diff = InlineDiffBuilder.Diff(oldText, newText);
        if (!diff.HasDifferences) return null;

        var lines = diff.Lines;
        int n     = lines.Count;

        var inHunk = new bool[n];
        for (int i = 0; i < n; i++)
        {
            if (lines[i].Type == ChangeType.Unchanged) continue;
            for (int j = Math.Max(0, i - ContextLines);
                     j < Math.Min(n, i + ContextLines + 1); j++)
                inHunk[j] = true;
        }

        var sb    = new StringBuilder();
        sb.AppendLine($"--- {fileName}  {oldTime:O} (before)");
        sb.AppendLine($"+++ {fileName}  {newTime:O} (after)");

        int oldNo = 1, newNo = 1, i2 = 0;

        while (i2 < n)
        {
            if (!inHunk[i2])
            {
                if (lines[i2].Type != ChangeType.Inserted) oldNo++;
                if (lines[i2].Type != ChangeType.Deleted)  newNo++;
                i2++;
                continue;
            }

            int start = i2;
            while (i2 < n && inHunk[i2]) i2++;
            int end = i2;

            var hunk   = lines.GetRange(start, end - start);
            int oldCnt = hunk.Count(l => l.Type != ChangeType.Inserted);
            int newCnt = hunk.Count(l => l.Type != ChangeType.Deleted);

            sb.AppendLine($"@@ -{oldNo},{oldCnt} +{newNo},{newCnt} @@");

            foreach (var line in hunk)
            {
                char pfx = line.Type switch
                {
                    ChangeType.Inserted => '+',
                    ChangeType.Deleted  => '-',
                    _                   => ' '
                };
                sb.AppendLine($"{pfx}{line.Text}");
                if (line.Type != ChangeType.Inserted) oldNo++;
                if (line.Type != ChangeType.Deleted)  newNo++;
            }
        }

        return sb.ToString().TrimEnd();
    }
}
```

---

## B.10 — `FileClassifier.cs` [MODIFIED]

Changes: rules loaded from `FileClassificationRules.json` via `LoadRules()`. Hot-reload via a secondary `FileSystemWatcher`. `ImmutableList` swap is lock-free on the read path.

```csharp
namespace FalconAuditService;

using System.Collections.Immutable;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

public class FileClassifier : IDisposable
{
    public record ClassificationResult(
        string Module,           // Job|Recipe|Config|AlignmentData|DieMap|ScanResult|Log|Unknown
        string OwnerService,     // RMS|Falcon.Net|AOI_Main|DataServer|Unknown
        string MonitorPriority   // P1|P2|P3|P4
    );

    private record CompiledRule(Regex Regex, ClassificationResult Result);

    private ImmutableList<CompiledRule>                      _rules = ImmutableList<CompiledRule>.Empty;
    private ClassificationResult                             _default = new("Unknown", "Unknown", "P3");
    private FileSystemWatcher?                               _configWatcher;
    private Timer?                                           _reloadDebounce;
    private readonly ILogger<FileClassifier>                 _logger;

    public FileClassifier(ILogger<FileClassifier> logger) => _logger = logger;

    // ── Load / Hot-reload ────────────────────────────────────────────────────

    public void LoadRules(string configPath)
    {
        try
        {
            var json    = File.ReadAllText(configPath);
            var ruleset = JsonSerializer.Deserialize<RuleSet>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (ruleset?.Rules is null)
            {
                _logger.LogWarning("FileClassificationRules.json has no rules.");
                return;
            }

            var compiled = ruleset.Rules
                .Select(r => new CompiledRule(GlobToRegex(
                    r.Pattern.ToLowerInvariant().Replace('\\', '/')), 
                    new ClassificationResult(r.Module, r.OwnerService, r.MonitorPriority)))
                .ToImmutableList();

            // Atomic swap — in-flight Classify() calls complete with old list, that's fine
            System.Threading.Interlocked.Exchange(
                ref System.Runtime.CompilerServices.Unsafe.AsRef(in _rules), compiled);

            if (ruleset.DefaultClassification is not null)
                _default = new ClassificationResult(
                    ruleset.DefaultClassification.Module,
                    ruleset.DefaultClassification.OwnerService,
                    ruleset.DefaultClassification.MonitorPriority);

            _logger.LogInformation("FileClassifier: loaded {N} rules from {P}",
                compiled.Count, configPath);

            StartConfigWatcher(configPath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FileClassifier: failed to load rules from {P}", configPath);
        }
    }

    private void StartConfigWatcher(string configPath)
    {
        if (_configWatcher is not null) return;   // already watching

        var dir  = Path.GetDirectoryName(configPath)!;
        var file = Path.GetFileName(configPath);

        _configWatcher = new FileSystemWatcher(dir, file)
        {
            NotifyFilters       = NotifyFilters.LastWrite,
            EnableRaisingEvents = true
        };
        _configWatcher.Changed += (_, _) =>
        {
            // Debounce: JSON file may still be partially written
            _reloadDebounce?.Dispose();
            _reloadDebounce = new Timer(_ => LoadRules(configPath), null, 1000, Timeout.Infinite);
        };
        _logger.LogInformation("FileClassifier: watching {P} for hot-reload.", configPath);
    }

    // ── Classify ─────────────────────────────────────────────────────────────

    public ClassificationResult Classify(string filePath)
    {
        var norm  = filePath.ToLowerInvariant().Replace('\\', '/');
        var rules = _rules;   // snapshot — lock-free

        foreach (var rule in rules)
            if (rule.Regex.IsMatch(norm)) return rule.Result;

        return _default;
    }

    // ── Glob → Regex ─────────────────────────────────────────────────────────

    private static Regex GlobToRegex(string glob)
    {
        var sb = new System.Text.StringBuilder("^");
        int i  = 0;
        while (i < glob.Length)
        {
            if (glob[i] == '*' && i + 1 < glob.Length && glob[i + 1] == '*')
            {
                sb.Append(".*");
                i += 2;
                if (i < glob.Length && glob[i] == '/') i++;
            }
            else if (glob[i] == '*') { sb.Append("[^/]*"); i++; }
            else if (glob[i] == '?') { sb.Append("[^/]");  i++; }
            else if (glob[i] == '.') { sb.Append("\\.");   i++; }
            else { sb.Append(Regex.Escape(glob[i].ToString())); i++; }
        }
        sb.Append('$');
        return new Regex(sb.ToString(), RegexOptions.IgnoreCase | RegexOptions.Compiled);
    }

    // ── JSON schema types ────────────────────────────────────────────────────

    private record RuleEntry(string Pattern, string MatchType,
                              string Module, string OwnerService, string MonitorPriority);
    private record DefaultEntry(string Module, string OwnerService, string MonitorPriority);
    private record RuleSet(List<RuleEntry>? Rules, DefaultEntry? DefaultClassification);

    public void Dispose()
    {
        _configWatcher?.Dispose();
        _reloadDebounce?.Dispose();
    }
}
```

---

## B.11 — `SqliteRepository.cs` [MODIFIED]

Changes: constructor takes `string dbPath` instead of `IConfiguration`. All WAL/schema/CRUD logic unchanged. `LoadConfig()` retained for the global DB instance.

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Logging;

public class SqliteRepository : IDisposable
{
    private readonly SqliteConnection _conn;
    private readonly SqliteConnection _readConn;
    private readonly SemaphoreSlim    _writeLock = new(1, 1);
    private readonly ILogger<SqliteRepository> _logger;

    public SqliteRepository(string dbPath, ILogger<SqliteRepository> logger)
    {
        _logger = logger;
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);

        _conn = new SqliteConnection($"Data Source={dbPath}");
        _conn.Open();

        _readConn = new SqliteConnection($"Data Source={dbPath}");
        _readConn.Open();

        using var rp = _readConn.CreateCommand();
        rp.CommandText = "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=3000;";
        rp.ExecuteNonQuery();

        using var wp = _conn.CreateCommand();
        wp.CommandText = "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=3000;";
        wp.ExecuteNonQuery();

        using var check = _conn.CreateCommand();
        check.CommandText = "PRAGMA journal_mode=WAL;";
        var mode = check.ExecuteScalar()?.ToString();
        if (!string.Equals(mode, "wal", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"SQLite WAL mode could not be enabled (got '{mode}'). " +
                "Ensure the database is not on a network share or FAT32 volume.");

        EnsureSchema();
        logger.LogInformation("SqliteRepository: ready. DB={D}", dbPath);
    }

    // ── Schema ───────────────────────────────────────────────────────────────

    private void EnsureSchema()
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = @"
            CREATE TABLE IF NOT EXISTS audit_log (
                id               INTEGER  PRIMARY KEY AUTOINCREMENT,
                filepath         TEXT     NOT NULL,
                filename         TEXT     NOT NULL,
                extension        TEXT     NOT NULL,
                change_type      TEXT     NOT NULL
                                 CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
                old_hash         TEXT,
                new_hash         TEXT,
                old_content      TEXT,
                new_content      TEXT,
                diff_text        TEXT,
                module           TEXT,
                owner_service    TEXT,
                monitor_priority TEXT     NOT NULL,
                detected_at      TEXT     NOT NULL,
                machine_name     TEXT     NOT NULL,
                note             TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_al_filepath ON audit_log(filepath);
            CREATE INDEX IF NOT EXISTS idx_al_detected ON audit_log(detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_priority ON audit_log(monitor_priority, detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_module   ON audit_log(module, detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_note     ON audit_log(note);

            CREATE TABLE IF NOT EXISTS file_baseline (
                filepath         TEXT PRIMARY KEY,
                last_hash        TEXT NOT NULL,
                last_seen        TEXT NOT NULL,
                last_size        INTEGER,
                module           TEXT,
                monitor_priority TEXT
            );

            CREATE TABLE IF NOT EXISTS monitor_config (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            INSERT OR IGNORE INTO monitor_config VALUES
                ('watch_path',               'C:\job'),
                ('store_content_p1',         'true'),
                ('max_content_bytes',        '1048576'),
                ('debounce_ms',              '500'),
                ('fsw_buffer_bytes',         '65536'),
                ('machine_name',             ''),
                ('classification_rules_path','C:\bis\auditlog\FileClassificationRules.json');
        ";
        cmd.ExecuteNonQuery();
    }

    // ── audit_log ────────────────────────────────────────────────────────────

    public async Task InsertAuditLogAsync(AuditLogEntry e)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO audit_log
                    (filepath, filename, extension, change_type,
                     old_hash, new_hash, old_content, new_content, diff_text,
                     module, owner_service, monitor_priority, detected_at, machine_name, note)
                VALUES
                    (@fp,@fn,@ext,@ct,@oh,@nh,@oc,@nc,@dt,@mod,@svc,@pri,@at,@mn,@note)";

            cmd.Parameters.AddWithValue("@fp",   e.Filepath);
            cmd.Parameters.AddWithValue("@fn",   e.Filename);
            cmd.Parameters.AddWithValue("@ext",  e.Extension);
            cmd.Parameters.AddWithValue("@ct",   e.ChangeType);
            cmd.Parameters.AddWithValue("@oh",   (object?)e.OldHash    ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@nh",   (object?)e.NewHash    ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@oc",   (object?)e.OldContent ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@nc",   (object?)e.NewContent ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@dt",   (object?)e.DiffText   ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@mod",  e.Module);
            cmd.Parameters.AddWithValue("@svc",  e.OwnerService);
            cmd.Parameters.AddWithValue("@pri",  e.MonitorPriority);
            cmd.Parameters.AddWithValue("@at",   e.DetectedAt);
            cmd.Parameters.AddWithValue("@mn",   e.MachineName);
            cmd.Parameters.AddWithValue("@note", (object?)e.Note ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    // ── file_baseline ────────────────────────────────────────────────────────

    public async Task UpsertBaselineAsync(FileBaseline b)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO file_baseline
                    (filepath, last_hash, last_seen, last_size, module, monitor_priority)
                VALUES (@fp, @lh, @ls, @lz, @mod, @pri)
                ON CONFLICT(filepath) DO UPDATE SET
                    last_hash        = excluded.last_hash,
                    last_seen        = excluded.last_seen,
                    last_size        = excluded.last_size,
                    module           = excluded.module,
                    monitor_priority = excluded.monitor_priority";

            cmd.Parameters.AddWithValue("@fp",  b.Filepath);
            cmd.Parameters.AddWithValue("@lh",  b.LastHash);
            cmd.Parameters.AddWithValue("@ls",  b.LastSeen);
            cmd.Parameters.AddWithValue("@lz",  b.LastSize);
            cmd.Parameters.AddWithValue("@mod", b.Module);
            cmd.Parameters.AddWithValue("@pri", b.MonitorPriority);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    public async Task<FileBaseline?> GetBaselineAsync(string filepath)
    {
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText =
            "SELECT filepath,last_hash,last_seen,last_size,module,monitor_priority " +
            "FROM file_baseline WHERE filepath=@fp";
        cmd.Parameters.AddWithValue("@fp", filepath);
        using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;
        return new FileBaseline
        {
            Filepath        = r.GetString(0),
            LastHash        = r.GetString(1),
            LastSeen        = r.GetString(2),
            LastSize        = r.IsDBNull(3) ? 0L   : r.GetInt64(3),
            Module          = r.IsDBNull(4) ? ""   : r.GetString(4),
            MonitorPriority = r.IsDBNull(5) ? "P3" : r.GetString(5)
        };
    }

    public async Task<List<FileBaseline>> GetAllBaselinesAsync()
    {
        var list = new List<FileBaseline>();
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText =
            "SELECT filepath,last_hash,last_seen,last_size,module,monitor_priority " +
            "FROM file_baseline";
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new FileBaseline
            {
                Filepath        = r.GetString(0),
                LastHash        = r.GetString(1),
                LastSeen        = r.GetString(2),
                LastSize        = r.IsDBNull(3) ? 0L   : r.GetInt64(3),
                Module          = r.IsDBNull(4) ? ""   : r.GetString(4),
                MonitorPriority = r.IsDBNull(5) ? "P3" : r.GetString(5)
            });
        return list;
    }

    public async Task DeleteBaselineAsync(string filepath)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = "DELETE FROM file_baseline WHERE filepath=@fp";
            cmd.Parameters.AddWithValue("@fp", filepath);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    // ── monitor_config (global DB only) ─────────────────────────────────────

    public MonitorConfig LoadConfig()
    {
        var cfg = new MonitorConfig();
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT key, value FROM monitor_config";
        using var r = cmd.ExecuteReader();
        while (r.Read())
        {
            var key = r.GetString(0);
            var val = r.GetString(1);
            switch (key)
            {
                case "watch_path":               cfg.WatchPath               = val; break;
                case "store_content_p1":         cfg.StoreContentP1          = val == "true"; break;
                case "max_content_bytes":        cfg.MaxContentBytes         = long.TryParse(val, out var mb)  ? mb  : 1048576L; break;
                case "debounce_ms":              cfg.DebounceMs              = int.TryParse(val,  out var dm)  ? dm  : 500; break;
                case "fsw_buffer_bytes":         cfg.FswBufferBytes          = int.TryParse(val,  out var fsw) ? fsw : 65536; break;
                case "classification_rules_path":cfg.ClassificationRulesPath = val; break;
                case "machine_name":
                    cfg.MachineName = string.IsNullOrWhiteSpace(val)
                        ? System.Net.Dns.GetHostName() : val;
                    break;
            }
        }
        return cfg;
    }

    public void Dispose()
    {
        _writeLock.Dispose();
        _conn.Dispose();
        _readConn.Dispose();
    }
}
```

---

## B.12 — `ShardRegistry.cs` [NEW]

Manages one `SqliteRepository` per job folder. Created lazily on first event for that job.

```csharp
namespace FalconAuditService;

using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;

public class ShardRegistry : IDisposable
{
    private readonly ConcurrentDictionary<string, SqliteRepository> _shards =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly ILoggerFactory _loggerFactory;
    private readonly ILogger<ShardRegistry> _logger;

    public ShardRegistry(ILoggerFactory loggerFactory)
    {
        _loggerFactory = loggerFactory;
        _logger        = loggerFactory.CreateLogger<ShardRegistry>();
    }

    /// <summary>
    /// Return the SqliteRepository for a job, creating it on first call.
    /// The shard file lives at <jobPath>\.audit\audit.db.
    /// </summary>
    public SqliteRepository GetOrCreate(string jobName, string jobPath)
    {
        return _shards.GetOrAdd(jobName, _ =>
        {
            var auditDir = Path.Combine(jobPath, ".audit");
            Directory.CreateDirectory(auditDir);
            var dbPath = Path.Combine(auditDir, "audit.db");
            _logger.LogInformation("ShardRegistry: opening shard for job '{J}' at {D}", jobName, dbPath);
            return new SqliteRepository(dbPath, _loggerFactory.CreateLogger<SqliteRepository>());
        });
    }

    public bool TryGet(string jobName, out SqliteRepository? repo) =>
        _shards.TryGetValue(jobName, out repo);

    /// <summary>Close and remove the shard for a job (e.g., job folder deleted).</summary>
    public void Remove(string jobName)
    {
        if (_shards.TryRemove(jobName, out var repo))
        {
            _logger.LogInformation("ShardRegistry: closed shard for job '{J}'.", jobName);
            repo.Dispose();
        }
    }

    public IEnumerable<string> JobNames => _shards.Keys;

    public void Dispose()
    {
        foreach (var repo in _shards.Values)
            repo.Dispose();
        _shards.Clear();
    }
}
```

---

## B.13 — `ManifestManager.cs` [NEW]

Reads and writes `.audit\manifest.json`. All writes go through an atomic temp-file rename.

```csharp
namespace FalconAuditService;

using System.Text.Json;
using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class ManifestManager
{
    private static readonly JsonSerializerOptions _jsonOpts =
        new() { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    private readonly ILogger<ManifestManager> _logger;

    public ManifestManager(ILogger<ManifestManager> logger) => _logger = logger;

    /// <summary>
    /// Called when this machine takes ownership of a job folder.
    /// Creates manifest.json if absent; appends a new history entry if the
    /// last entry belongs to a different machine; no-ops if already open for this machine.
    /// </summary>
    public void RecordArrival(string jobPath, string machineName)
    {
        var auditDir     = Path.Combine(jobPath, ".audit");
        var manifestPath = Path.Combine(auditDir, "manifest.json");
        var jobName      = Path.GetFileName(jobPath.TrimEnd('\\', '/'));

        var manifest = ReadManifest(manifestPath) ?? new JobManifest
        {
            JobName  = jobName,
            Created  = new MachineTimestamp { Machine = machineName, At = DateTime.UtcNow }
        };

        var last = manifest.History.LastOrDefault();

        // If last entry is from a different machine and still open, close it
        if (last?.To == null && !string.Equals(last?.Machine, machineName,
                                                StringComparison.OrdinalIgnoreCase))
        {
            last!.To = DateTime.UtcNow;
            _logger.LogInformation("ManifestManager: closed entry for {M} on job '{J}'.",
                                    last.Machine, jobName);
        }

        // Open new entry for this machine if needed
        if (last == null || !string.Equals(last.Machine, machineName,
                                            StringComparison.OrdinalIgnoreCase)
                         || last.To != null)
        {
            manifest.History.Add(new HistoryEntry
            {
                Machine = machineName,
                From    = DateTime.UtcNow,
                To      = null,
                Events  = 0
            });
            _logger.LogInformation(
                "ManifestManager: opened entry for {M} on job '{J}'.", machineName, jobName);
        }

        WriteManifest(manifestPath, manifest);
    }

    /// <summary>
    /// Called when this machine releases ownership (service stop, job folder removed).
    /// Closes the open history entry by setting its 'to' timestamp.
    /// </summary>
    public void RecordDeparture(string jobPath)
    {
        var manifestPath = Path.Combine(jobPath, ".audit", "manifest.json");
        var manifest     = ReadManifest(manifestPath);
        if (manifest is null) return;

        var last = manifest.History.LastOrDefault();
        if (last?.To == null)
        {
            last!.To = DateTime.UtcNow;
            WriteManifest(manifestPath, manifest);
            _logger.LogInformation(
                "ManifestManager: departure recorded for job '{J}'.",
                Path.GetFileName(jobPath.TrimEnd('\\', '/')));
        }
    }

    /// <summary>
    /// Increment the event counter for the current open history entry.
    /// Called after each successful InsertAuditLogAsync.
    /// </summary>
    public void IncrementEvents(string jobPath)
    {
        var manifestPath = Path.Combine(jobPath, ".audit", "manifest.json");
        var manifest     = ReadManifest(manifestPath);
        if (manifest is null) return;

        var last = manifest.History.LastOrDefault(e => e.To == null);
        if (last is null) return;

        last.Events++;
        WriteManifest(manifestPath, manifest);
    }

    private JobManifest? ReadManifest(string path)
    {
        if (!File.Exists(path)) return null;
        try
        {
            return JsonSerializer.Deserialize<JobManifest>(
                File.ReadAllText(path), _jsonOpts);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ManifestManager: could not read {P}", path);
            return null;
        }
    }

    private void WriteManifest(string path, JobManifest manifest)
    {
        var tmp = path + ".tmp";
        try
        {
            File.WriteAllText(tmp, JsonSerializer.Serialize(manifest, _jsonOpts));
            File.Move(tmp, path, overwrite: true);   // atomic on NTFS
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ManifestManager: could not write {P}", path);
        }
    }
}
```

---

## B.14 — `DirectoryWatcher.cs` [NEW]

Watches `c:\job\` at depth=1 (job folders only, not file changes). Fires callbacks on job folder arrive/remove.

```csharp
namespace FalconAuditService;

using Microsoft.Extensions.Logging;

public class DirectoryWatcher : IDisposable
{
    private FileSystemWatcher?            _watcher;
    private readonly string               _watchPath;
    private readonly Action<string, string> _onArrived;   // (jobName, jobFullPath)
    private readonly Action<string>       _onDeparted;    // (jobName)
    private readonly ILogger<DirectoryWatcher> _logger;

    public DirectoryWatcher(
        string watchPath,
        Action<string, string> onArrived,
        Action<string> onDeparted,
        ILogger<DirectoryWatcher> logger)
    {
        _watchPath  = watchPath;
        _onArrived  = onArrived;
        _onDeparted = onDeparted;
        _logger     = logger;
    }

    public void Start()
    {
        _watcher = new FileSystemWatcher(_watchPath)
        {
            NotifyFilters         = NotifyFilters.DirectoryName,
            IncludeSubdirectories = false,   // depth=1 — job directories only
            EnableRaisingEvents   = true
        };
        _watcher.Created += OnCreated;
        _watcher.Deleted += OnDeleted;
        _watcher.Renamed += OnRenamed;
        _logger.LogInformation("DirectoryWatcher: watching {P} for job folder changes.", _watchPath);
    }

    public void Stop()
    {
        _watcher?.Dispose();
        _watcher = null;
    }

    /// <summary>Enumerate existing job folders at startup — fires onArrived for each.</summary>
    public void EnumerateExisting()
    {
        foreach (var dir in Directory.EnumerateDirectories(_watchPath))
        {
            var name = Path.GetFileName(dir);
            if (!string.IsNullOrEmpty(name))
                _onArrived(name, dir);
        }
    }

    private void OnCreated(object _, FileSystemEventArgs e)
    {
        if (string.IsNullOrEmpty(e.Name)) return;
        _logger.LogInformation("DirectoryWatcher: job folder arrived — '{N}'.", e.Name);
        _onArrived(e.Name!, e.FullPath);
    }

    private void OnDeleted(object _, FileSystemEventArgs e)
    {
        if (string.IsNullOrEmpty(e.Name)) return;
        _logger.LogInformation("DirectoryWatcher: job folder departed — '{N}'.", e.Name);
        _onDeparted(e.Name!);
    }

    private void OnRenamed(object _, RenamedEventArgs e)
    {
        _logger.LogInformation("DirectoryWatcher: job folder renamed '{O}' → '{N}'.",
                                e.OldName, e.Name);
        if (!string.IsNullOrEmpty(e.OldName)) _onDeparted(e.OldName!);
        if (!string.IsNullOrEmpty(e.Name))    _onArrived(e.Name!, e.FullPath);
    }

    public void Dispose() => _watcher?.Dispose();
}
```

---

## B.15 — `ChangeEvent.cs` [UNCHANGED]

```csharp
namespace FalconAuditService;

internal record ChangeEvent(
    string             FullPath,
    WatcherChangeTypes ChangeType,
    DateTime           DetectedAt,
    string?            OldPath = null   // populated for Renamed events only
);
```

---

## B.16 — `FileChangeHandler.cs` [MODIFIED]

Changes: takes `ShardRegistry` and `SqliteRepository` (global). Routes events to the correct shard based on job name extracted from the file path. Global files (`c:\job\status.ini` — no subdirectory) go to `globalRepo`.

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileChangeHandler
{
    private readonly ShardRegistry   _shards;
    private readonly SqliteRepository _globalRepo;
    private readonly FileClassifier   _classifier;
    private readonly ContentCache     _contentCache;
    private readonly MonitorConfig    _config;
    private readonly ILogger<FileChangeHandler> _logger;

    public FileChangeHandler(
        ShardRegistry shards, SqliteRepository globalRepo,
        FileClassifier classifier, ContentCache contentCache,
        MonitorConfig config, ILogger<FileChangeHandler> logger)
    {
        _shards       = shards;
        _globalRepo   = globalRepo;
        _classifier   = classifier;
        _contentCache = contentCache;
        _config       = config;
        _logger       = logger;
    }

    public async Task HandleAsync(ChangeEvent ev)
    {
        _logger.LogDebug("Processing change. Path={P} ChangeType={T}", ev.FullPath, ev.ChangeType);

        var repo     = GetRepo(ev.FullPath);
        var cls      = _classifier.Classify(ev.FullPath);
        var baseline = await repo.GetBaselineAsync(ev.FullPath);

        _logger.LogDebug("Classified. Module={M} OwnerService={O} Priority={P}",
                          cls.Module, cls.OwnerService, cls.MonitorPriority);

        string? oldHash    = baseline?.LastHash;
        string? newHash    = null;
        string? oldContent = null;
        string? newContent = null;
        string? diffText   = null;
        string  changeType;

        switch (ev.ChangeType)
        {
            case WatcherChangeTypes.Deleted:
                changeType = "Deleted";
                oldContent = _contentCache.Get(ev.FullPath);
                break;

            case WatcherChangeTypes.Created:
            case WatcherChangeTypes.Changed:
                newHash = HashHelper.ComputeSha256(ev.FullPath);
                if (newHash is null)
                {
                    _logger.LogWarning("Could not hash {P} — skipping.", ev.FullPath);
                    return;
                }
                _logger.LogDebug("Hash computed. OldHash={O} NewHash={N} HashChanged={C}",
                                  oldHash?[..8] ?? "null", newHash[..8], newHash != oldHash);

                if (newHash == oldHash)
                {
                    await repo.UpsertBaselineAsync(MakeBaseline(ev.FullPath, newHash, cls));
                    return;
                }

                changeType = baseline is null ? "Created" : "Modified";

                if (cls.MonitorPriority == "P1" && _config.StoreContentP1)
                {
                    var fi = new FileInfo(ev.FullPath);
                    if (fi.Length <= _config.MaxContentBytes)
                    {
                        _logger.LogDebug("Reading content for P1 file. SizeBytes={S}", fi.Length);
                        newContent = await ReadTextAsync(ev.FullPath);
                        oldContent = _contentCache.Get(ev.FullPath);

                        if (changeType == "Modified" && oldContent is not null && newContent is not null)
                        {
                            diffText = DiffHelper.UnifiedDiff(
                                oldContent, newContent,
                                Path.GetFileName(ev.FullPath),
                                baseline!.LastSeen != null
                                    ? DateTime.Parse(baseline.LastSeen, null,
                                        System.Globalization.DateTimeStyles.RoundtripKind)
                                    : ev.DetectedAt.AddSeconds(-1),
                                ev.DetectedAt);
                            _logger.LogDebug("Diff computed. LinesAdded={A} LinesRemoved={R}",
                                              CountDiffLines(diffText, '+'),
                                              CountDiffLines(diffText, '-'));
                        }

                        if (newContent is not null) _contentCache.Set(ev.FullPath, newContent);
                    }
                    else
                    {
                        diffText = $"[content omitted: size {fi.Length:N0} bytes " +
                                    "exceeds max_content_bytes limit]";
                    }
                }
                break;

            case WatcherChangeTypes.Renamed:
                changeType = "Renamed";
                oldContent = _contentCache.Get(ev.OldPath ?? ev.FullPath);
                newHash    = HashHelper.ComputeSha256(ev.FullPath);
                if (ev.OldPath is not null)
                {
                    await repo.DeleteBaselineAsync(ev.OldPath);
                    _contentCache.Remove(ev.OldPath);
                }
                break;

            default:
                return;
        }

        var entry = new AuditLogEntry
        {
            Filepath        = ev.FullPath,
            Filename        = Path.GetFileName(ev.FullPath),
            Extension       = Path.GetExtension(ev.FullPath).ToLowerInvariant(),
            ChangeType      = changeType,
            OldHash         = oldHash,
            NewHash         = newHash,
            OldContent      = oldContent,
            NewContent      = newContent,
            DiffText        = diffText,
            Module          = cls.Module,
            OwnerService    = cls.OwnerService,
            MonitorPriority = cls.MonitorPriority,
            DetectedAt      = ev.DetectedAt.ToString("O"),
            MachineName     = _config.MachineName
        };

        await repo.InsertAuditLogAsync(entry);

        _logger.LogInformation(
            "Audit event written. File={F} ChangeType={C} Module={M} Priority={P} " +
            "OldHash={OH} NewHash={NH}",
            Path.GetFileName(ev.FullPath), changeType,
            cls.Module, cls.MonitorPriority,
            oldHash?[..8] ?? "null", newHash?[..8] ?? "null");

        if (ev.ChangeType == WatcherChangeTypes.Deleted)
        {
            await repo.DeleteBaselineAsync(ev.FullPath);
            _contentCache.Remove(ev.FullPath);
        }
        else if (newHash is not null)
        {
            await repo.UpsertBaselineAsync(MakeBaseline(ev.FullPath, newHash, cls));
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    /// <summary>
    /// Return the shard repo for the job that owns this file path.
    /// Files directly under c:\job\ (e.g. status.ini) go to globalRepo.
    /// </summary>
    private SqliteRepository GetRepo(string filePath)
    {
        var (jobName, jobPath) = ExtractJob(filePath);
        if (jobName is null || jobPath is null) return _globalRepo;
        return _shards.GetOrCreate(jobName, jobPath);
    }

    private (string? jobName, string? jobPath) ExtractJob(string filePath)
    {
        var watch   = _config.WatchPath.TrimEnd('\\', '/');
        if (!filePath.StartsWith(watch, StringComparison.OrdinalIgnoreCase))
            return (null, null);

        var relative = filePath[(watch.Length)..].TrimStart('\\', '/');
        var sep      = relative.IndexOfAny(new[] { '\\', '/' });
        if (sep <= 0) return (null, null);   // direct child of c:\job\ — global file

        var jobName = relative[..sep];
        return (jobName, Path.Combine(watch, jobName));
    }

    private static FileBaseline MakeBaseline(string path, string hash,
                                              FileClassifier.ClassificationResult cls) =>
        new()
        {
            Filepath        = path,
            LastHash        = hash,
            LastSeen        = DateTime.UtcNow.ToString("O"),
            LastSize        = new FileInfo(path).Exists ? new FileInfo(path).Length : 0,
            Module          = cls.Module,
            MonitorPriority = cls.MonitorPriority
        };

    private static async Task<string?> ReadTextAsync(string path)
    {
        try
        {
            using var fs = new FileStream(path, FileMode.Open,
                                          FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    private static int CountDiffLines(string? diff, char prefix) =>
        diff?.Split('\n').Count(l => l.Length > 0 &&
                                     l[0] == prefix &&
                                     (l.Length < 2 || l[1] != prefix)) ?? 0;
}
```

---

## B.17 — `FileMonitorService.cs` [UNCHANGED]

```csharp
namespace FalconAuditService;

using System.Collections.Concurrent;
using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileMonitorService : IDisposable
{
    private FileSystemWatcher?                             _watcher;
    private readonly ConcurrentDictionary<string, Timer>  _debounce = new();
    private readonly BlockingCollection<ChangeEvent>       _queue    = new(1000);
    private readonly FileChangeHandler  _handler;
    private readonly CatchUpScanner     _catchUp;
    private readonly MonitorConfig      _config;
    private readonly ILogger<FileMonitorService> _logger;
    private CancellationToken           _ct;
    private Thread?                     _writerThread;

    public FileMonitorService(FileChangeHandler handler, CatchUpScanner catchUp,
                               MonitorConfig config, ILogger<FileMonitorService> logger)
    {
        _handler = handler;
        _catchUp = catchUp;
        _config  = config;
        _logger  = logger;
    }

    public void Start(CancellationToken ct)
    {
        _ct = ct;
        InitWatcher();
        _writerThread = new Thread(DrainQueue) { IsBackground = true, Name = "AuditWriter" };
        _writerThread.Start();
        _logger.LogInformation(
            "FileMonitorService: FileSystemWatcher enabled. Path={P} Buffer={B}",
            _config.WatchPath, _config.FswBufferBytes);
    }

    public void Stop()
    {
        _watcher?.Dispose();
        _queue.CompleteAdding();
        _writerThread?.Join(TimeSpan.FromSeconds(10));
        _logger.LogInformation("FileMonitorService: FileSystemWatcher disabled.");
    }

    private void InitWatcher()
    {
        _watcher?.Dispose();
        _watcher = new FileSystemWatcher(_config.WatchPath)
        {
            NotifyFilters         = NotifyFilters.FileName
                                  | NotifyFilters.LastWrite
                                  | NotifyFilters.DirectoryName,
            IncludeSubdirectories = true,
            InternalBufferSize    = _config.FswBufferBytes,
            Filter                = "*.*",
            EnableRaisingEvents   = true
        };
        _watcher.Changed += OnFileEvent;
        _watcher.Created += OnFileEvent;
        _watcher.Deleted += OnFileEvent;
        _watcher.Renamed += OnRenamed;
        _watcher.Error   += OnError;
    }

    private void OnFileEvent(object _, FileSystemEventArgs e)
    {
        _logger.LogDebug("FSW event received. Type={T} Path={P}", e.ChangeType, e.FullPath);
        _debounce.AddOrUpdate(
            e.FullPath,
            key => new Timer(FireDebounce, e, _config.DebounceMs, Timeout.Infinite),
            (key, existing) =>
            {
                existing.Change(_config.DebounceMs, Timeout.Infinite);
                _logger.LogDebug("FSW event received. Type={T} Path={P}  (debounce reset)",
                                  e.ChangeType, e.FullPath);
                return existing;
            });
    }

    private void OnRenamed(object _, RenamedEventArgs e)
    {
        _logger.LogDebug("FSW event received. Type=Renamed OldPath={O} NewPath={N}",
                          e.OldFullPath, e.FullPath);
        TryEnqueue(new ChangeEvent(e.FullPath, WatcherChangeTypes.Renamed,
                                   DateTime.UtcNow, e.OldFullPath));
    }

    private void FireDebounce(object? state)
    {
        var e = (FileSystemEventArgs)state!;
        if (_debounce.TryRemove(e.FullPath, out var t)) t.Dispose();
        _logger.LogDebug("Debounce fired. Path={P}  Enqueued.", e.FullPath);
        TryEnqueue(new ChangeEvent(e.FullPath, e.ChangeType, DateTime.UtcNow));
    }

    private void OnError(object _, ErrorEventArgs e)
    {
        _logger.LogWarning("FSW buffer overflow or error: {M}. Restarting watcher.",
                            e.GetException().Message);
        InitWatcher();
        _ = Task.Run(() => _catchUp.RunAsync(_config.WatchPath, _ct));
    }

    private void TryEnqueue(ChangeEvent ev)
    {
        if (!_queue.IsAddingCompleted) _queue.TryAdd(ev);
    }

    private void DrainQueue()
    {
        foreach (var ev in _queue.GetConsumingEnumerable(_ct))
        {
            try   { _handler.HandleAsync(ev).GetAwaiter().GetResult(); }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled error processing event. Path={P}", ev.FullPath);
            }
        }
    }

    public void Dispose()
    {
        _watcher?.Dispose();
        _queue.Dispose();
        foreach (var t in _debounce.Values) t.Dispose();
    }
}
```

---

## B.18 — `CatchUpScanner.cs` [MODIFIED]

Changes: takes `ShardRegistry` and global `SqliteRepository`. `RunAsync` accepts optional `jobPath` to scope the scan to a single job. Internal `GetRepo(path)` routes writes to the correct shard or global repo.

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class CatchUpScanner
{
    private readonly ShardRegistry    _shards;
    private readonly SqliteRepository _globalRepo;
    private readonly FileClassifier   _classifier;
    private readonly ContentCache     _contentCache;
    private readonly MonitorConfig    _config;
    private readonly ILogger<CatchUpScanner> _logger;
    private readonly SemaphoreSlim    _guard = new(1, 1);

    private static readonly HashSet<string> IncludedExts =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".txt", ".ini", ".json", ".xml", ".csv", ".log",
            ".yaml", ".yml", ".cfg", ".dat", ".seq", ".md",
            ".properties", ".conf", ".config", ".bat", ".cmd", ".ps1", ".sql"
        };

    public CatchUpScanner(ShardRegistry shards, SqliteRepository globalRepo,
                           FileClassifier classifier, ContentCache contentCache,
                           MonitorConfig config, ILogger<CatchUpScanner> logger)
    {
        _shards       = shards;
        _globalRepo   = globalRepo;
        _classifier   = classifier;
        _contentCache = contentCache;
        _config       = config;
        _logger       = logger;
    }

    /// <summary>
    /// Reconcile disk state against stored baselines.
    /// Pass jobPath to restrict scan to one job subtree;
    /// pass null for a full scan of the entire watch path (used on full restart).
    /// </summary>
    public async Task RunAsync(string watchPath, CancellationToken ct, string? jobPath = null)
    {
        if (!await _guard.WaitAsync(0))
        {
            _logger.LogWarning("CatchUpScanner: already running — skipping.");
            return;
        }
        try   { await CoreAsync(watchPath, ct, jobPath); }
        finally { _guard.Release(); }
    }

    private async Task CoreAsync(string watchPath, CancellationToken ct, string? jobPath)
    {
        var scanRoot = jobPath ?? watchPath;
        var sw       = System.Diagnostics.Stopwatch.StartNew();

        _logger.LogInformation("CatchUpScanner: starting reconciliation scan. Root={R}", scanRoot);

        var currentFiles = Directory
            .EnumerateFiles(scanRoot, "*.*", SearchOption.AllDirectories)
            .Where(f => IncludedExts.Contains(Path.GetExtension(f)))
            .ToList();

        _logger.LogInformation("CatchUpScanner: found {N} candidate files.", currentFiles.Count);

        // Build a per-repo baseline map: only load baselines from repos we'll scan
        // For a scoped job scan, get baselines only from that job's shard.
        var repo         = jobPath is not null ? GetRepo(Path.Combine(jobPath, "_dummy")) : null;
        var allBaselines = repo is not null
            ? await repo.GetAllBaselinesAsync()
            : await GetAllBaselinesAsync(currentFiles);

        var baselineMap  = allBaselines.ToDictionary(b => b.Filepath,
                                                      StringComparer.OrdinalIgnoreCase);
        var currentSet   = new HashSet<string>(currentFiles, StringComparer.OrdinalIgnoreCase);

        int created = 0, modified = 0, deleted = 0, unchanged = 0;

        // ── Phase 1: inspect current files ──────────────────────────────────
        foreach (var path in currentFiles)
        {
            ct.ThrowIfCancellationRequested();

            string? hash; long size;
            try { hash = HashHelper.ComputeSha256(path); size = new FileInfo(path).Length; }
            catch (IOException) { continue; }
            if (hash is null) continue;

            var cls    = _classifier.Classify(path);
            var fileRepo = GetRepo(path);
            baselineMap.TryGetValue(path, out var bl);

            if (bl is null)
            {
                string? content = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (content is not null) _contentCache.Set(path, content);

                await fileRepo.InsertAuditLogAsync(new AuditLogEntry
                {
                    Filepath = path, Filename = Path.GetFileName(path),
                    Extension = Path.GetExtension(path).ToLowerInvariant(),
                    ChangeType = "Created", NewHash = hash, NewContent = content,
                    Module = cls.Module, OwnerService = cls.OwnerService,
                    MonitorPriority = cls.MonitorPriority,
                    DetectedAt = DateTime.UtcNow.ToString("O"),
                    MachineName = _config.MachineName, Note = "catch-up"
                });
                created++;
            }
            else if (hash != bl.LastHash)
            {
                string? newContent = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (newContent is not null) _contentCache.Set(path, newContent);

                await fileRepo.InsertAuditLogAsync(new AuditLogEntry
                {
                    Filepath = path, Filename = Path.GetFileName(path),
                    Extension = Path.GetExtension(path).ToLowerInvariant(),
                    ChangeType = "Modified", OldHash = bl.LastHash, NewHash = hash,
                    NewContent = newContent,
                    Module = cls.Module, OwnerService = cls.OwnerService,
                    MonitorPriority = cls.MonitorPriority,
                    DetectedAt = DateTime.UtcNow.ToString("O"),
                    MachineName = _config.MachineName, Note = "catch-up"
                });
                modified++;
            }
            else
            {
                if (cls.MonitorPriority == "P1" && _config.StoreContentP1 &&
                    size <= _config.MaxContentBytes)
                {
                    var content = await ReadIfP1Async(path, cls.MonitorPriority, size);
                    if (content is not null) _contentCache.Set(path, content);
                }
                unchanged++;
            }

            await fileRepo.UpsertBaselineAsync(new FileBaseline
            {
                Filepath = path, LastHash = hash,
                LastSeen = DateTime.UtcNow.ToString("O"), LastSize = size,
                Module = cls.Module, MonitorPriority = cls.MonitorPriority
            });
        }

        // ── Phase 2: detect deletions ────────────────────────────────────────
        foreach (var bl in allBaselines)
        {
            ct.ThrowIfCancellationRequested();
            if (currentSet.Contains(bl.Filepath)) continue;

            var fileRepo = GetRepo(bl.Filepath);
            await fileRepo.InsertAuditLogAsync(new AuditLogEntry
            {
                Filepath = bl.Filepath, Filename = Path.GetFileName(bl.Filepath),
                Extension = Path.GetExtension(bl.Filepath).ToLowerInvariant(),
                ChangeType = "Deleted", OldHash = bl.LastHash,
                Module = bl.Module, MonitorPriority = bl.MonitorPriority,
                DetectedAt = DateTime.UtcNow.ToString("O"),
                MachineName = _config.MachineName, Note = "catch-up"
            });
            await fileRepo.DeleteBaselineAsync(bl.Filepath);
            _contentCache.Remove(bl.Filepath);
            deleted++;
        }

        sw.Stop();
        _logger.LogInformation(
            "CatchUpScanner: complete. Unchanged={U} Created={C} Modified={M} Deleted={D} Elapsed={E}ms",
            unchanged, created, modified, deleted, sw.ElapsedMilliseconds);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private SqliteRepository GetRepo(string filePath)
    {
        var watch = _config.WatchPath.TrimEnd('\\', '/');
        if (!filePath.StartsWith(watch, StringComparison.OrdinalIgnoreCase))
            return _globalRepo;

        var relative = filePath[(watch.Length)..].TrimStart('\\', '/');
        var sep      = relative.IndexOfAny(new[] { '\\', '/' });
        if (sep <= 0) return _globalRepo;

        var jobName = relative[..sep];
        var jobPath = Path.Combine(watch, jobName);
        return _shards.GetOrCreate(jobName, jobPath);
    }

    private async Task<List<FileBaseline>> GetAllBaselinesAsync(List<string> currentFiles)
    {
        var result   = new List<FileBaseline>();
        var jobNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var f in currentFiles)
        {
            var watch = _config.WatchPath.TrimEnd('\\', '/');
            var rel   = f[(watch.Length)..].TrimStart('\\', '/');
            var sep   = rel.IndexOfAny(new[] { '\\', '/' });
            if (sep > 0) jobNames.Add(rel[..sep]);
        }

        result.AddRange(await _globalRepo.GetAllBaselinesAsync());

        foreach (var jn in jobNames)
        {
            var jp   = Path.Combine(_config.WatchPath, jn);
            var repo = _shards.GetOrCreate(jn, jp);
            result.AddRange(await repo.GetAllBaselinesAsync());
        }
        return result;
    }

    private async Task<string?> ReadIfP1Async(string path, string priority, long size)
    {
        if (priority != "P1" || !_config.StoreContentP1) return null;
        if (size > _config.MaxContentBytes) return null;
        try
        {
            using var fs = new FileStream(path, FileMode.Open,
                                          FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ReadIfP1Async: could not read {P}", path);
            return null;
        }
    }
}
```

---

## B.19 — `Worker.cs` [MODIFIED]

Changes: enumerates existing job folders at startup via `DirectoryWatcher.EnumerateExisting()`; wires `DirectoryWatcher` callbacks for live job folder arrivals; calls `ManifestManager.RecordDeparture()` on stop.

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public class Worker : BackgroundService
{
    private readonly FileMonitorService _monitor;
    private readonly CatchUpScanner     _catchUp;
    private readonly ShardRegistry      _shards;
    private readonly ManifestManager    _manifest;
    private readonly DirectoryWatcher   _dirWatcher;
    private readonly MonitorConfig      _config;
    private readonly ILogger<Worker>    _logger;

    public Worker(
        FileMonitorService monitor, CatchUpScanner catchUp,
        ShardRegistry shards, ManifestManager manifest,
        DirectoryWatcher dirWatcher, MonitorConfig config,
        ILogger<Worker> logger)
    {
        _monitor    = monitor;
        _catchUp    = catchUp;
        _shards     = shards;
        _manifest   = manifest;
        _dirWatcher = dirWatcher;
        _config     = config;
        _logger     = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("FalconAuditService starting. WatchPath={W}", _config.WatchPath);

        if (!Directory.Exists(_config.WatchPath))
        {
            _logger.LogCritical(
                "WatchPath does not exist: {P} — service cannot start monitoring.", _config.WatchPath);
            return;
        }

        // Step 1: enumerate existing job folders; open shards; record arrival in manifest
        _dirWatcher.EnumerateExisting();

        // Step 2: run catch-up scan for each known job (sequential to avoid DB contention)
        using var scanTimeout = new CancellationTokenSource(TimeSpan.FromMinutes(5));
        using var scanCts     = CancellationTokenSource.CreateLinkedTokenSource(
                                    stoppingToken, scanTimeout.Token);
        try
        {
            // Full scan — routes each file to the correct shard internally
            await _catchUp.RunAsync(_config.WatchPath, scanCts.Token);
        }
        catch (OperationCanceledException) when (scanTimeout.IsCancellationRequested)
        {
            _logger.LogWarning("CatchUpScanner exceeded 5-min startup limit — starting with partial catch-up.");
        }

        // Step 3: start live FSW + DirectoryWatcher for job folder arrive/remove events
        _dirWatcher.Start();
        _monitor.Start(stoppingToken);
        _logger.LogInformation("FalconAuditService running.");

        try { await Task.Delay(Timeout.Infinite, stoppingToken); }
        catch (TaskCanceledException) { /* normal shutdown */ }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("StopAsync requested. Draining queue.");

        // Record departure in manifest for every active job
        foreach (var jobName in _shards.JobNames)
        {
            var jobPath = Path.Combine(_config.WatchPath, jobName);
            _manifest.RecordDeparture(jobPath);
        }

        _dirWatcher.Stop();
        _monitor.Stop();
        await base.StopAsync(cancellationToken);
        _logger.LogInformation("FalconAuditService stopped.");
    }
}
```

---

## B.20 — `Program.cs` [MODIFIED]

Changes: registers `ShardRegistry`, `ManifestManager`, `DirectoryWatcher`; loads `FileClassifier` rules from JSON config; constructor for `SqliteRepository` now takes `dbPath` string.

```csharp
using FalconAuditService;
using FalconAuditService.Models;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(
        new ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build())
    .CreateLogger();

try
{
    IHost host = Host.CreateDefaultBuilder(args)
        .UseWindowsService(o => o.ServiceName = "FalconAuditService")
        .UseSerilog()
        .ConfigureServices((ctx, services) =>
        {
            // Global DB (status.ini and monitor_config)
            services.AddSingleton(sp =>
            {
                var globalDbPath = ctx.Configuration["AuditService:GlobalDbPath"]
                                ?? @"C:\bis\auditlog\global.db";
                return new SqliteRepository(
                    globalDbPath,
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<SqliteRepository>>());
            });

            // MonitorConfig loaded from monitor_config table in global DB
            services.AddSingleton(sp =>
            {
                var cfg = sp.GetRequiredService<SqliteRepository>().LoadConfig();
                // appsettings.json overrides (if present) take priority
                var rulesPath = ctx.Configuration["AuditService:ClassificationRulesPath"];
                if (!string.IsNullOrEmpty(rulesPath)) cfg.ClassificationRulesPath = rulesPath;
                return cfg;
            });

            services.AddSingleton<ContentCache>();
            services.AddSingleton<ShardRegistry>();
            services.AddSingleton<ManifestManager>();

            // FileClassifier: singleton, loaded from JSON rules
            services.AddSingleton(sp =>
            {
                var config     = sp.GetRequiredService<MonitorConfig>();
                var classifier = new FileClassifier(
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<FileClassifier>>());
                classifier.LoadRules(config.ClassificationRulesPath);
                return classifier;
            });

            // DirectoryWatcher wired with callbacks into ShardRegistry + ManifestManager
            services.AddSingleton(sp =>
            {
                var config   = sp.GetRequiredService<MonitorConfig>();
                var shards   = sp.GetRequiredService<ShardRegistry>();
                var manifest = sp.GetRequiredService<ManifestManager>();
                var catchUp  = sp.GetRequiredService<CatchUpScanner>();
                var logger   = sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<DirectoryWatcher>>();

                return new DirectoryWatcher(
                    config.WatchPath,
                    onArrived: (jobName, jobPath) =>
                    {
                        shards.GetOrCreate(jobName, jobPath);
                        manifest.RecordArrival(jobPath, config.MachineName);
                        _ = Task.Run(() => catchUp.RunAsync(config.WatchPath,
                                                             CancellationToken.None, jobPath));
                    },
                    onDeparted: (jobName) =>
                    {
                        var jobPath = Path.Combine(config.WatchPath, jobName);
                        manifest.RecordDeparture(jobPath);
                        shards.Remove(jobName);
                    },
                    logger);
            });

            services.AddSingleton<FileChangeHandler>();
            services.AddSingleton<CatchUpScanner>();
            services.AddSingleton<FileMonitorService>();
            services.AddHostedService<Worker>();
        })
        .Build();

    await host.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "FalconAuditService terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}
```

---

## B.21 — `install.ps1` [UNCHANGED]

```powershell
<#
.SYNOPSIS
    Install or uninstall the FalconAuditService Windows Service.
.EXAMPLE
    .\install.ps1 -Action Install
    .\install.ps1 -Action Uninstall
#>
#Requires -RunAsAdministrator

param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action      = 'Install',
    [string]$InstallPath = 'C:\bis\bin\FalconAuditService',
    [string]$DbPath      = 'C:\bis\auditlog'
)

$ServiceName = 'FalconAuditService'
$DisplayName = 'Falcon Audit Log Service'
$Description = 'Monitors c:\job\ for file changes and writes per-job audit shards to SQLite.'
$ExePath     = Join-Path $InstallPath 'FalconAuditService.exe'
$DbDir       = $DbPath

if ($Action -eq 'Install') {
    if (-not (Test-Path $ExePath)) {
        Write-Error "Executable not found: $ExePath"
        exit 1
    }

    if (-not (Test-Path $DbDir)) {
        New-Item -ItemType Directory -Path $DbDir | Out-Null
        Write-Host "Created directory: $DbDir"
    }

    # Copy FileClassificationRules.json to the audit directory on first install
    $rulesSource = Join-Path $InstallPath 'FileClassificationRules.json'
    $rulesDest   = Join-Path $DbDir 'FileClassificationRules.json'
    if ((Test-Path $rulesSource) -and -not (Test-Path $rulesDest)) {
        Copy-Item $rulesSource $rulesDest
        Write-Host "Installed FileClassificationRules.json to $DbDir"
    }

    # SECURITY NOTE: Replace LocalSystem with a low-privilege service account
    # that has read access to C:\job\ and write access to C:\bis\auditlog\ only.
    sc.exe create $ServiceName `
        binPath= "`"$ExePath`"" `
        start=   auto `
        obj=     LocalSystem

    sc.exe description $ServiceName $Description
    sc.exe failure      $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000

    Start-Service -Name $ServiceName
    Write-Host "Service '$ServiceName' installed and started."

} elseif ($Action -eq 'Uninstall') {
    if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)?.Status -eq 'Running') {
        Stop-Service -Name $ServiceName -Force
        Write-Host "Service stopped."
    }
    sc.exe delete $ServiceName
    Write-Host "Service '$ServiceName' uninstalled."
}
```

---

## B.22 — Summary of Changes vs `04_recommended_design.md`

| File | Status | Key changes |
|---|---|---|
| `FalconAuditService.csproj` | Unchanged | Added `<Content>` for JSON rules file |
| `appsettings.json` | Modified | `GlobalDbPath` replaces `DbPath`; `ClassificationRulesPath` added |
| `Models/AuditLogEntry.cs` | Unchanged | — |
| `Models/FileBaseline.cs` | Unchanged | — |
| `Models/MonitorConfig.cs` | Modified | `GlobalDbPath`, `ClassificationRulesPath` |
| `Models/JobManifest.cs` | **New** | Chain-of-custody data model |
| `ContentCache.cs` | Unchanged | — |
| `HashHelper.cs` | Unchanged | — |
| `DiffHelper.cs` | Unchanged | — |
| `FileClassifier.cs` | Modified | Load from JSON; hot-reload via FSW |
| `SqliteRepository.cs` | Modified | Constructor takes `string dbPath` |
| `ShardRegistry.cs` | **New** | Per-job repository factory/cache |
| `ManifestManager.cs` | **New** | Reads/writes `.audit\manifest.json` |
| `DirectoryWatcher.cs` | **New** | Monitors `c:\job\` depth-1 for job folders |
| `ChangeEvent.cs` | Unchanged | — |
| `FileChangeHandler.cs` | Modified | Routes to `ShardRegistry`; `GetRepo()` helper |
| `FileMonitorService.cs` | Unchanged | — |
| `CatchUpScanner.cs` | Modified | `jobPath` scope; `GetRepo()` routing; `ShardRegistry` dependency |
| `Worker.cs` | Modified | Enumerate jobs; `DirectoryWatcher` wiring; manifest on stop |
| `Program.cs` | Modified | Register new services; `FileClassifier` init; `DirectoryWatcher` callbacks |
| `install.ps1` | Unchanged | Minor: copy `FileClassificationRules.json` on first install |
| `FileClassificationRules.json` | **New** | 69 rules derived from `JobConfigurationFileList.json` |

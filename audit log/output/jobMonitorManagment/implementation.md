# FalconAudit — Project Scaffold Script

Save the PowerShell block below as `scaffold-falconaudit.ps1` and run:

```
.\scaffold-falconaudit.ps1 -OutputPath C:\dev\FalconAudit
```

After it finishes:
```
cd C:\dev\FalconAudit\FalconAuditService
dotnet build

cd ..\FalconAuditWebServer
dotnet build
```

---

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS  Scaffolds the complete FalconAudit project from source.
.EXAMPLE   .\scaffold-falconaudit.ps1 -OutputPath C:\dev\FalconAudit
#>
param([string]$OutputPath = ".\FalconAudit")

function New-File {
    param([string]$Rel, [string]$Body)
    $full = Join-Path $OutputPath $Rel
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($full, $Body, [System.Text.Encoding]::UTF8)
    Write-Host "  $Rel"
}

Write-Host "`nScaffolding FalconAudit → $OutputPath`n"

# ============================================================
# FALCONAUDITSERVICE
# ============================================================

New-File "FalconAuditService\FalconAuditService.csproj" @'
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
    <PackageReference Include="Microsoft.Data.Sqlite"                        Version="7.0.*" />
    <PackageReference Include="DiffPlex"                                     Version="1.7.*" />
    <PackageReference Include="Microsoft.Extensions.Hosting.WindowsServices" Version="7.0.*" />
    <PackageReference Include="Serilog.Extensions.Hosting"                   Version="7.0.*" />
    <PackageReference Include="Serilog.Sinks.File"                           Version="5.0.*" />
    <PackageReference Include="Serilog.Sinks.EventLog"                       Version="3.1.*" />
  </ItemGroup>
  <ItemGroup>
    <Content Include="FileClassificationRules.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
    <Content Include="ParameterDescriptions.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>
</Project>
'@

New-File "FalconAuditService\appsettings.json" @'
{
  "AuditService": {
    "GlobalDbPath":              "C:\\bis\\auditlog\\global.db",
    "ClassificationRulesPath":   "C:\\bis\\auditlog\\FileClassificationRules.json",
    "ParameterDescriptionsPath": "C:\\bis\\auditlog\\ParameterDescriptions.json"
  },
  "Serilog": {
    "MinimumLevel": { "Default": "Information" },
    "WriteTo": [
      {
        "Name": "File",
        "Args": {
          "path": "C:\\bis\\auditlog\\logs\\falconaudit-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 31
        }
      },
      {
        "Name": "EventLog",
        "Args": { "source": "FalconAuditService", "restrictedToMinimumLevel": "Warning" }
      }
    ]
  }
}
'@

New-File "FalconAuditService\Models\AuditLogEntry.cs" @'
namespace FalconAuditService.Models;

public record AuditLogEntry
{
    public string  Filepath         { get; init; } = "";
    public string  RelFilepath      { get; init; } = "";
    public string  EventType        { get; init; } = "";
    public string? OldContent       { get; init; }
    public string? DiffText         { get; init; }
    public string  Module           { get; init; } = "Unknown";
    public string  OwnerService     { get; init; } = "Unknown";
    public string  MonitorPriority  { get; init; } = "P3";
    public string  ChangedAt        { get; init; } = "";
    public string  MachineName      { get; init; } = "";
    public string  Sha256Hash       { get; init; } = "";
    public string  FileDescription  { get; init; } = "";
    public string  ChangeSummary    { get; init; } = "";
    public bool    IsBackfill       { get; init; } = false;
    public string? OldFilepath      { get; init; }
}
'@

New-File "FalconAuditService\Models\FileBaseline.cs" @'
namespace FalconAuditService.Models;

public record FileBaseline
{
    public string  Filepath     { get; init; } = "";
    public string  LastHash     { get; init; } = "";
    public string  LastSeen     { get; init; } = "";
    public string? LastContent  { get; init; }
}
'@

New-File "FalconAuditService\Models\MonitorConfig.cs" @'
namespace FalconAuditService.Models;

public class MonitorConfig
{
    public string WatchPath                 { get; set; } = @"C:\job\";
    public string GlobalDbPath              { get; set; } = @"C:\bis\auditlog\global.db";
    public string ClassificationRulesPath   { get; set; } = @"C:\bis\auditlog\FileClassificationRules.json";
    public string ParameterDescriptionsPath { get; set; } = @"C:\bis\auditlog\ParameterDescriptions.json";
    public int    ApiPort                   { get; set; } = 5100;
    public string ApiBindAddress            { get; set; } = "127.0.0.1";
    public int    DebounceMs                { get; set; } = 500;
    public int    FswBufferBytes            { get; set; } = 65_536;
    public long   MaxContentBytes           { get; set; } = 1_048_576;
    public bool   CaptureContent            { get; set; } = true;
    public int    CatchUpYieldThreshold     { get; set; } = 50;
    public int    RecoveryDelayMs           { get; set; } = 30_000;
    public string MachineName               { get; set; } = Environment.MachineName;
}
'@

New-File "FalconAuditService\Models\JobManifest.cs" @'
namespace FalconAuditService.Models;

using System.Text.Json.Serialization;

public class JobManifest
{
    [JsonPropertyName("jobName")]      public string JobName        { get; set; } = "";
    [JsonPropertyName("auditDbVersion")] public string AuditDbVersion { get; set; } = "1";
    [JsonPropertyName("created")]      public MachineTimestamp? Created { get; set; }
    [JsonPropertyName("history")]      public List<HistoryEntry> History { get; set; } = new();
}

public class MachineTimestamp
{
    [JsonPropertyName("machine")] public string   Machine { get; set; } = "";
    [JsonPropertyName("at")]      public DateTime At      { get; set; }
}

public class HistoryEntry
{
    [JsonPropertyName("machine")] public string    Machine { get; set; } = "";
    [JsonPropertyName("from")]    public DateTime  From    { get; set; }
    [JsonPropertyName("to")]      public DateTime? To      { get; set; }
    [JsonPropertyName("events")]  public int       Events  { get; set; }
}
'@

New-File "FalconAuditService\ContentCache.cs" @'
namespace FalconAuditService;

using System.Collections.Generic;

public class ContentCache
{
    private readonly long _maxBytes;
    private long _totalBytes;
    private readonly Dictionary<string, LinkedListNode<(string key, string value)>> _map =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly LinkedList<(string key, string value)> _order = new();
    private readonly object _lock = new();

    public ContentCache(long maxBytes = 200L * 1024 * 1024)
    {
        _maxBytes = maxBytes;
    }

    public void Set(string path, string content)
    {
        long newBytes = content.Length * 2L;
        lock (_lock)
        {
            if (_map.TryGetValue(path, out var existing))
            {
                _totalBytes -= existing.Value.value.Length * 2L;
                _order.Remove(existing);
                _map.Remove(path);
            }

            while (_totalBytes + newBytes > _maxBytes && _order.Count > 0)
            {
                var oldest = _order.First!;
                _totalBytes -= oldest.Value.value.Length * 2L;
                _map.Remove(oldest.Value.key);
                _order.RemoveFirst();
            }

            var node = _order.AddLast((path, content));
            _map[path] = node;
            _totalBytes += newBytes;
        }
    }

    public string? Get(string path)
    {
        lock (_lock)
            return _map.TryGetValue(path, out var node) ? node.Value.value : null;
    }

    public void Remove(string path)
    {
        lock (_lock)
        {
            if (!_map.TryGetValue(path, out var node)) return;
            _totalBytes -= node.Value.value.Length * 2L;
            _order.Remove(node);
            _map.Remove(path);
        }
    }
}
'@

New-File "FalconAuditService\HashHelper.cs" @'
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
                using var fs   = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
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
'@

New-File "FalconAuditService\DiffHelper.cs" @'
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
        DateTime oldTime = default,
        DateTime newTime = default)
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
        var oldTs = oldTime == default ? "" : $"  {oldTime:O}";
        var newTs = newTime == default ? "" : $"  {newTime:O}";
        sb.AppendLine($"--- {fileName}{oldTs} (before)");
        sb.AppendLine($"+++ {fileName}{newTs} (after)");

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
'@

New-File "FalconAuditService\FileClassifier.cs" @'
namespace FalconAuditService;

using System.Collections.Immutable;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

public class FileClassifier : IDisposable
{
    public record ClassificationResult(
        string Module,
        string OwnerService,
        string MonitorPriority,
        string MatchedPattern,
        string ShortName,
        string Description
    );

    private record CompiledRule(Regex Regex, string RawPattern, ClassificationResult Result);

    private ImmutableList<CompiledRule>      _rules   = ImmutableList<CompiledRule>.Empty;
    private ClassificationResult             _default = new("Unknown", "Unknown", "P3", "", "Unknown file", "Unclassified file change.");
    private FileSystemWatcher?               _configWatcher;
    private Timer?                           _reloadDebounce;
    private readonly ILogger<FileClassifier> _logger;

    public FileClassifier(ILogger<FileClassifier> logger) => _logger = logger;

    public void LoadRules(string configPath)
    {
        try
        {
            var json    = File.ReadAllText(configPath);
            var ruleset = JsonSerializer.Deserialize<RuleSet>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true,
                                            ReadCommentHandling = JsonCommentHandling.Skip });

            if (ruleset?.Rules is null)
            {
                _logger.LogWarning("FileClassificationRules.json has no rules.");
                return;
            }

            var compiled = ruleset.Rules
                .Select(r =>
                {
                    var normPattern = r.Pattern.ToLowerInvariant().Replace('\\', '/');
                    var result = new ClassificationResult(
                        r.Module, r.OwnerService, r.MonitorPriority,
                        r.Pattern,
                        r.ShortName   ?? r.Module,
                        r.Description ?? "");
                    return new CompiledRule(GlobToRegex(normPattern), r.Pattern, result);
                })
                .ToImmutableList();

            Interlocked.Exchange(ref _rules, compiled);

            if (ruleset.DefaultClassification is not null)
                _default = new ClassificationResult(
                    ruleset.DefaultClassification.Module,
                    ruleset.DefaultClassification.OwnerService,
                    ruleset.DefaultClassification.MonitorPriority,
                    "",
                    ruleset.DefaultClassification.ShortName   ?? "Unknown file",
                    ruleset.DefaultClassification.Description ?? "Unclassified file change.");
            else
                _default = new ClassificationResult("Unknown", "Unknown", "P3", "", "Unknown file", "Unclassified file change.");

            _logger.LogInformation("FileClassifier: loaded {N} rules from {P}", compiled.Count, configPath);
            StartConfigWatcher(configPath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FileClassifier: failed to load rules from {P}", configPath);
        }
    }

    private void StartConfigWatcher(string configPath)
    {
        if (_configWatcher is not null) return;
        var dir  = Path.GetDirectoryName(configPath)!;
        var file = Path.GetFileName(configPath);
        _configWatcher = new FileSystemWatcher(dir, file)
        {
            NotifyFilters       = NotifyFilters.LastWrite,
            EnableRaisingEvents = true
        };
        _configWatcher.Changed += (_, _) =>
        {
            _reloadDebounce?.Dispose();
            _reloadDebounce = new Timer(_ => LoadRules(configPath), null, 1000, Timeout.Infinite);
        };
        _logger.LogInformation("FileClassifier: watching {P} for hot-reload.", configPath);
    }

    public ClassificationResult Classify(string filePath)
    {
        var norm  = filePath.ToLowerInvariant().Replace('\\', '/');
        var rules = _rules;
        foreach (var rule in rules)
            if (rule.Regex.IsMatch(norm)) return rule.Result;
        return _default;
    }

    private static Regex GlobToRegex(string glob)
    {
        var sb = new System.Text.StringBuilder("^");
        int i  = 0;
        while (i < glob.Length)
        {
            if (glob[i] == '*' && i + 1 < glob.Length && glob[i + 1] == '*')
            {
                sb.Append(".*"); i += 2;
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

    private record RuleEntry(string Pattern, string MatchType, string Module, string OwnerService,
                              string MonitorPriority, string? ShortName, string? Description);
    private record DefaultEntry(string Module, string OwnerService, string MonitorPriority,
                                string? ShortName, string? Description);
    private record RuleSet(List<RuleEntry>? Rules, DefaultEntry? DefaultClassification);

    public void Dispose()
    {
        _configWatcher?.Dispose();
        _reloadDebounce?.Dispose();
    }
}
'@

New-File "FalconAuditService\ChangeDescriptionEnricher.cs" @'
namespace FalconAuditService;

using System.Collections.Immutable;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

public class ChangeDescriptionEnricher : IDisposable
{
    private ImmutableDictionary<string, ImmutableDictionary<string, string>> _map =
        ImmutableDictionary<string, ImmutableDictionary<string, string>>.Empty;

    private FileSystemWatcher?                           _watcher;
    private Timer?                                       _debounce;
    private readonly ILogger<ChangeDescriptionEnricher> _logger;

    private static readonly Regex _sectionRx  = new(@"^\s*\[([^\]]+)\]", RegexOptions.Compiled);
    private static readonly Regex _keyValueRx  = new(@"^([+\- ])\s*([^=\s][^=]*)=(.*)$", RegexOptions.Compiled);

    public ChangeDescriptionEnricher(ILogger<ChangeDescriptionEnricher> logger) => _logger = logger;

    public void Load(string configPath)
    {
        if (!File.Exists(configPath))
        {
            _logger.LogWarning("ChangeDescriptionEnricher: {P} not found.", configPath);
            StartWatcher(configPath);
            return;
        }
        try
        {
            var json = File.ReadAllText(configPath);
            var doc  = JsonSerializer.Deserialize<DescriptionsFile>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true,
                                            ReadCommentHandling = JsonCommentHandling.Skip });

            if (doc?.Files is null) return;

            var builder = ImmutableDictionary.CreateBuilder<string, ImmutableDictionary<string, string>>(
                StringComparer.OrdinalIgnoreCase);
            foreach (var (pattern, keys) in doc.Files)
            {
                var inner = ImmutableDictionary.CreateBuilder<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var (k, v) in keys) inner[k] = v;
                builder[pattern] = inner.ToImmutable();
            }
            Interlocked.Exchange(ref _map, builder.ToImmutable());
            _logger.LogInformation("ChangeDescriptionEnricher: loaded {N} patterns from {P}.", doc.Files.Count, configPath);
        }
        catch (Exception ex) { _logger.LogError(ex, "ChangeDescriptionEnricher: failed to load {P}.", configPath); }
        finally { StartWatcher(configPath); }
    }

    private void StartWatcher(string configPath)
    {
        if (_watcher is not null) return;
        var dir = Path.GetDirectoryName(configPath);
        if (dir is null || !Directory.Exists(dir)) return;
        _watcher = new FileSystemWatcher(dir, Path.GetFileName(configPath))
        {
            NotifyFilters = NotifyFilters.LastWrite, EnableRaisingEvents = true
        };
        _watcher.Changed += (_, _) =>
        {
            _debounce?.Dispose();
            _debounce = new Timer(_ => Load(configPath), null, 1000, Timeout.Infinite);
        };
    }

    public string Enrich(string matchedPattern, string eventType, string? diffText)
    {
        if (eventType == "Created") return "File created";
        if (eventType == "Deleted") return $"File deleted: {Path.GetFileName(matchedPattern)}";
        if (eventType == "Renamed") return !string.IsNullOrEmpty(diffText) ? $"File renamed: {diffText}" : "File renamed";
        if (string.IsNullOrEmpty(diffText)) return "File modified";

        var changes = ParseDiffChanges(diffText);
        if (changes.Count == 0) return "File modified";

        var map = _map;
        map.TryGetValue(matchedPattern, out var paramMap);

        var parts = new List<string>(changes.Count);
        foreach (var (key, (oldVal, newVal)) in changes)
        {
            var label = ResolveLabel(paramMap, key, key.Contains('.') ? key.Split('.', 2)[1] : key);
            parts.Add(string.IsNullOrEmpty(newVal)
                ? $"{label}: removed"
                : string.IsNullOrEmpty(oldVal)
                    ? $"{label}: set to {newVal.Trim()}"
                    : $"{label}: {oldVal.Trim()} \u2192 {newVal.Trim()}");
        }
        return string.Join("; ", parts);
    }

    private static Dictionary<string, (string Old, string New)> ParseDiffChanges(string diffText)
    {
        var removed = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var added   = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var section = "";

        foreach (var rawLine in diffText.Split('\n'))
        {
            var line = rawLine.TrimEnd('\r');
            if (line.StartsWith("---") || line.StartsWith("+++") || line.StartsWith("@@")) continue;
            if (line.Length == 0) continue;
            char prefix = line[0];
            var  body   = line.Length > 1 ? line[1..] : "";

            var secMatch = _sectionRx.Match(body);
            if (secMatch.Success && prefix != '+')
                section = secMatch.Groups[1].Value.Trim();

            if (prefix != '-' && prefix != '+') continue;
            var kvMatch = _keyValueRx.Match(line);
            if (!kvMatch.Success) continue;

            var key   = $"{section}.{kvMatch.Groups[2].Value.Trim()}";
            var value = kvMatch.Groups[3].Value.Trim();
            if (prefix == '-') removed[key] = value;
            else               added[key]   = value;
        }

        var result = new Dictionary<string, (string, string)>(StringComparer.OrdinalIgnoreCase);
        foreach (var (k, ov) in removed)
        {
            added.TryGetValue(k, out var nv);
            if (ov != (nv ?? "")) result[k] = (ov, nv ?? "");
        }
        foreach (var (k, nv) in added)
            if (!removed.ContainsKey(k)) result[k] = ("", nv);
        return result;
    }

    private static string ResolveLabel(ImmutableDictionary<string, string>? paramMap, string sectionDotKey, string keyOnly)
    {
        if (paramMap is not null)
        {
            if (paramMap.TryGetValue(sectionDotKey, out var label)) return label;
            if (paramMap.TryGetValue(keyOnly,        out label))     return label;
        }
        return Regex.Replace(keyOnly, @"(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", " ");
    }

    private record DescriptionsFile(string? Version, Dictionary<string, Dictionary<string, string>>? Files);

    public void Dispose()
    {
        _watcher?.Dispose();
        _debounce?.Dispose();
    }
}
'@

New-File "FalconAuditService\SqliteRepository.cs" @'
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
            throw new InvalidOperationException($"SQLite WAL mode could not be enabled (got '{mode}').");

        EnsureSchema();
        logger.LogInformation("SqliteRepository: ready. DB={D}", dbPath);
    }

    private void EnsureSchema()
    {
        using var tx  = _conn.BeginTransaction();
        using var cmd = _conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = @"
            CREATE TABLE IF NOT EXISTS audit_log (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                changed_at       TEXT    NOT NULL,
                event_type       TEXT    NOT NULL CHECK(event_type IN ('Created','Modified','Deleted','Renamed')),
                filepath         TEXT    NOT NULL,
                rel_filepath     TEXT    NOT NULL,
                module           TEXT    NOT NULL,
                owner_service    TEXT    NOT NULL,
                monitor_priority TEXT    NOT NULL CHECK(monitor_priority IN ('P1','P2','P3')),
                machine_name     TEXT    NOT NULL,
                sha256_hash      TEXT    NOT NULL,
                old_content      TEXT    NULL,
                diff_text        TEXT    NULL,
                file_description TEXT    NOT NULL DEFAULT '',
                change_summary   TEXT    NOT NULL DEFAULT '',
                is_backfill      INTEGER NOT NULL DEFAULT 0,
                old_filepath     TEXT    NULL
            );

            CREATE INDEX IF NOT EXISTS ix_audit_log_changed_at        ON audit_log (changed_at DESC);
            CREATE INDEX IF NOT EXISTS ix_audit_log_module            ON audit_log (module);
            CREATE INDEX IF NOT EXISTS ix_audit_log_priority          ON audit_log (monitor_priority);
            CREATE INDEX IF NOT EXISTS ix_audit_log_event_type        ON audit_log (event_type);
            CREATE INDEX IF NOT EXISTS ix_audit_log_machine           ON audit_log (machine_name);
            CREATE INDEX IF NOT EXISTS ix_audit_log_owner_service     ON audit_log (owner_service);
            CREATE INDEX IF NOT EXISTS ix_audit_log_rel_filepath      ON audit_log (rel_filepath);
            CREATE INDEX IF NOT EXISTS ix_audit_log_module_changed_at ON audit_log (module, changed_at DESC);
            CREATE INDEX IF NOT EXISTS ix_audit_log_filepath          ON audit_log (filepath);

            CREATE TABLE IF NOT EXISTS file_baselines (
                filepath     TEXT PRIMARY KEY,
                last_hash    TEXT NOT NULL,
                last_seen    TEXT NOT NULL,
                last_content TEXT NULL
            );
            CREATE INDEX IF NOT EXISTS ix_file_baselines_last_seen ON file_baselines (last_seen);

            CREATE TABLE IF NOT EXISTS schema_meta (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            INSERT OR IGNORE INTO schema_meta (key, value) VALUES ('schema_version', '3');
            INSERT OR IGNORE INTO schema_meta (key, value) VALUES ('audit_db_version', '1');
            INSERT OR IGNORE INTO schema_meta (key, value) VALUES
                ('created_at_utc', strftime('%Y-%m-%dT%H:%M:%fZ','now'));

            CREATE TABLE IF NOT EXISTS monitor_config (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        ";
        cmd.ExecuteNonQuery();
        tx.Commit();
        MigrateSchema();
    }

    private void MigrateSchema()
    {
        var version = 1;
        using (var qv = _conn.CreateCommand())
        {
            qv.CommandText = "SELECT value FROM schema_meta WHERE key='schema_version'";
            var raw = qv.ExecuteScalar()?.ToString();
            if (int.TryParse(raw, out var v)) version = v;
        }

        if (version < 2)
        {
            AlterTableAddColumns(new[] { "file_description TEXT NOT NULL DEFAULT ''",
                                         "change_summary   TEXT NOT NULL DEFAULT ''" });
            SetSchemaVersion(2);
        }

        if (version < 3)
        {
            AlterTableAddColumns(new[] { "is_backfill  INTEGER NOT NULL DEFAULT 0",
                                          "old_filepath TEXT NULL" });
            SetSchemaVersion(3);
        }
    }

    private void AlterTableAddColumns(string[] columnDefs)
    {
        foreach (var col in columnDefs)
        {
            try
            {
                using var ac = _conn.CreateCommand();
                ac.CommandText = $"ALTER TABLE audit_log ADD COLUMN {col}";
                ac.ExecuteNonQuery();
            }
            catch (SqliteException ex) when (
                ex.Message.Contains("duplicate column name", StringComparison.OrdinalIgnoreCase)) { }
        }
    }

    private void SetSchemaVersion(int version)
    {
        using var uv = _conn.CreateCommand();
        uv.CommandText = "INSERT OR REPLACE INTO schema_meta (key,value) VALUES ('schema_version',@v)";
        uv.Parameters.AddWithValue("@v", version.ToString());
        uv.ExecuteNonQuery();
    }

    public async Task InsertAuditEventAsync(AuditLogEntry e, FileBaseline baseline)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var tx  = _conn.BeginTransaction();
            using var ins = _conn.CreateCommand();
            ins.Transaction = tx;
            ins.CommandText = @"
                INSERT INTO audit_log
                  (changed_at,event_type,filepath,rel_filepath,module,owner_service,
                   monitor_priority,machine_name,sha256_hash,old_content,diff_text,
                   file_description,change_summary,is_backfill,old_filepath)
                VALUES (@ca,@et,@fp,@rfp,@mod,@svc,@pri,@mn,@hash,@oc,@dt,@fd,@cs,@ib,@ofp)";
            ins.Parameters.AddWithValue("@ca",  e.ChangedAt);
            ins.Parameters.AddWithValue("@et",  e.EventType);
            ins.Parameters.AddWithValue("@fp",  e.Filepath);
            ins.Parameters.AddWithValue("@rfp", e.RelFilepath);
            ins.Parameters.AddWithValue("@mod", e.Module);
            ins.Parameters.AddWithValue("@svc", e.OwnerService);
            ins.Parameters.AddWithValue("@pri", e.MonitorPriority);
            ins.Parameters.AddWithValue("@mn",  e.MachineName);
            ins.Parameters.AddWithValue("@hash",e.Sha256Hash);
            ins.Parameters.AddWithValue("@oc",  (object?)e.OldContent  ?? DBNull.Value);
            ins.Parameters.AddWithValue("@dt",  (object?)e.DiffText    ?? DBNull.Value);
            ins.Parameters.AddWithValue("@fd",  e.FileDescription);
            ins.Parameters.AddWithValue("@cs",  e.ChangeSummary);
            ins.Parameters.AddWithValue("@ib",  e.IsBackfill ? 1 : 0);
            ins.Parameters.AddWithValue("@ofp", (object?)e.OldFilepath ?? DBNull.Value);
            await ins.ExecuteNonQueryAsync();

            using var upb = _conn.CreateCommand();
            upb.Transaction = tx;
            upb.CommandText = @"
                INSERT INTO file_baselines (filepath,last_hash,last_seen,last_content)
                VALUES (@fp,@lh,@ls,@lc)
                ON CONFLICT(filepath) DO UPDATE SET
                  last_hash=excluded.last_hash, last_seen=excluded.last_seen,
                  last_content=excluded.last_content";
            upb.Parameters.AddWithValue("@fp", baseline.Filepath);
            upb.Parameters.AddWithValue("@lh", baseline.LastHash);
            upb.Parameters.AddWithValue("@ls", baseline.LastSeen);
            upb.Parameters.AddWithValue("@lc", (object?)baseline.LastContent ?? DBNull.Value);
            await upb.ExecuteNonQueryAsync();
            tx.Commit();
        }
        finally { _writeLock.Release(); }
    }

    public async Task UpsertBaselineAsync(FileBaseline baseline)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO file_baselines (filepath,last_hash,last_seen,last_content)
                VALUES (@fp,@lh,@ls,@lc)
                ON CONFLICT(filepath) DO UPDATE SET
                  last_hash=excluded.last_hash, last_seen=excluded.last_seen,
                  last_content=excluded.last_content";
            cmd.Parameters.AddWithValue("@fp", baseline.Filepath);
            cmd.Parameters.AddWithValue("@lh", baseline.LastHash);
            cmd.Parameters.AddWithValue("@ls", baseline.LastSeen);
            cmd.Parameters.AddWithValue("@lc", (object?)baseline.LastContent ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    public MonitorConfig LoadConfig()
    {
        var defaults = new MonitorConfig();
        var data = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["watch_path"]                  = defaults.WatchPath,
            ["global_db_path"]              = defaults.GlobalDbPath,
            ["classification_rules_path"]   = defaults.ClassificationRulesPath,
            ["parameter_descriptions_path"] = defaults.ParameterDescriptionsPath,
            ["api_port"]                    = defaults.ApiPort.ToString(),
            ["api_bind_address"]            = defaults.ApiBindAddress,
            ["debounce_ms"]                 = defaults.DebounceMs.ToString(),
            ["fsw_buffer_bytes"]            = defaults.FswBufferBytes.ToString(),
            ["max_content_bytes"]           = defaults.MaxContentBytes.ToString(),
            ["capture_content"]             = defaults.CaptureContent.ToString(),
            ["catch_up_yield_threshold"]    = defaults.CatchUpYieldThreshold.ToString(),
            ["recovery_delay_ms"]           = defaults.RecoveryDelayMs.ToString()
        };

        _writeLock.Wait();
        try
        {
            using var tx = _conn.BeginTransaction();
            foreach (var (k, v) in data)
            {
                using var ins = _conn.CreateCommand();
                ins.Transaction = tx;
                ins.CommandText = "INSERT OR IGNORE INTO monitor_config (key,value) VALUES (@k,@v)";
                ins.Parameters.AddWithValue("@k", k);
                ins.Parameters.AddWithValue("@v", v);
                ins.ExecuteNonQuery();
            }
            tx.Commit();
        }
        finally { _writeLock.Release(); }

        using var cmd = _readConn.CreateCommand();
        cmd.CommandText = "SELECT key,value FROM monitor_config";
        using var r = cmd.ExecuteReader();
        while (r.Read()) data[r.GetString(0)] = r.GetString(1);

        var cfg = new MonitorConfig();
        if (data.TryGetValue("watch_path",                  out var s)) cfg.WatchPath                 = s;
        if (data.TryGetValue("global_db_path",              out s))     cfg.GlobalDbPath               = s;
        if (data.TryGetValue("classification_rules_path",   out s))     cfg.ClassificationRulesPath    = s;
        if (data.TryGetValue("parameter_descriptions_path", out s))     cfg.ParameterDescriptionsPath  = s;
        if (data.TryGetValue("api_bind_address",            out s))     cfg.ApiBindAddress             = s;
        if (data.TryGetValue("api_port",           out s) && int.TryParse(s,  out var i)) cfg.ApiPort                 = i;
        if (data.TryGetValue("debounce_ms",        out s) && int.TryParse(s,  out i))     cfg.DebounceMs              = i;
        if (data.TryGetValue("fsw_buffer_bytes",   out s) && int.TryParse(s,  out i))     cfg.FswBufferBytes          = i;
        if (data.TryGetValue("catch_up_yield_threshold", out s) && int.TryParse(s, out i)) cfg.CatchUpYieldThreshold  = i;
        if (data.TryGetValue("recovery_delay_ms",  out s) && int.TryParse(s,  out i))     cfg.RecoveryDelayMs        = i;
        if (data.TryGetValue("max_content_bytes",  out s) && long.TryParse(s, out var l)) cfg.MaxContentBytes        = l;
        if (data.TryGetValue("capture_content",    out s) && bool.TryParse(s, out var b)) cfg.CaptureContent         = b;
        return cfg;
    }

    public async Task<FileBaseline?> GetBaselineAsync(string filepath)
    {
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText = "SELECT filepath,last_hash,last_seen,last_content FROM file_baselines WHERE filepath=@fp";
        cmd.Parameters.AddWithValue("@fp", filepath);
        using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;
        return new FileBaseline { Filepath=r.GetString(0), LastHash=r.GetString(1),
                                  LastSeen=r.GetString(2), LastContent=r.IsDBNull(3)?null:r.GetString(3) };
    }

    public async Task<List<FileBaseline>> GetAllBaselinesAsync()
    {
        var list = new List<FileBaseline>();
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText = "SELECT filepath,last_hash,last_seen,last_content FROM file_baselines";
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new FileBaseline { Filepath=r.GetString(0), LastHash=r.GetString(1),
                                        LastSeen=r.GetString(2), LastContent=r.IsDBNull(3)?null:r.GetString(3) });
        return list;
    }

    public async Task DeleteBaselineAsync(string filepath)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = "DELETE FROM file_baselines WHERE filepath=@fp";
            cmd.Parameters.AddWithValue("@fp", filepath);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    public void Dispose()
    {
        _writeLock.Dispose();
        _conn.Dispose();
        _readConn.Dispose();
    }
}
'@

New-File "FalconAuditService\ShardRegistry.cs" @'
namespace FalconAuditService;

using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;

public class ShardRegistry : IDisposable
{
    private readonly ConcurrentDictionary<string, SqliteRepository?> _shards =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly ILoggerFactory        _loggerFactory;
    private readonly ILogger<ShardRegistry> _logger;

    public ShardRegistry(ILoggerFactory loggerFactory)
    {
        _loggerFactory = loggerFactory;
        _logger        = loggerFactory.CreateLogger<ShardRegistry>();
    }

    public SqliteRepository? GetOrCreate(string jobName, string jobPath)
    {
        if (_shards.TryGetValue(jobName, out var existing)) return existing;

        var auditDir = Path.Combine(jobPath, ".audit");
        var dbPath   = Path.Combine(auditDir, "audit.db");
        try
        {
            Directory.CreateDirectory(auditDir);
            _logger.LogInformation("ShardRegistry: opening shard for job '{J}' at {D}", jobName, dbPath);
            var repo = new SqliteRepository(dbPath, _loggerFactory.CreateLogger<SqliteRepository>());
            _shards.TryAdd(jobName, repo);
            return _shards[jobName];
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "ShardRegistry: failed to open shard for {J}; NOT cached. DB={D}", jobName, dbPath);
            return null;
        }
    }

    public bool TryGet(string jobName, out SqliteRepository? repo) =>
        _shards.TryGetValue(jobName, out repo);

    public void Remove(string jobName)
    {
        if (_shards.TryRemove(jobName, out var repo))
        {
            _logger.LogInformation("ShardRegistry: closed shard for job '{J}'.", jobName);
            repo?.Dispose();
        }
    }

    public IEnumerable<string> JobNames => _shards.Keys;

    public void Dispose()
    {
        foreach (var repo in _shards.Values) repo?.Dispose();
        _shards.Clear();
    }
}
'@

New-File "FalconAuditService\ManifestManager.cs" @'
namespace FalconAuditService;

using System.Collections.Concurrent;
using System.Text.Json;
using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class ManifestManager
{
    private static readonly JsonSerializerOptions _jsonOpts =
        new() { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    private readonly ILogger<ManifestManager> _logger;
    private readonly ConcurrentDictionary<string, SemaphoreSlim> _locks =
        new(StringComparer.OrdinalIgnoreCase);

    public ManifestManager(ILogger<ManifestManager> logger) => _logger = logger;

    private SemaphoreSlim LockFor(string manifestPath) =>
        _locks.GetOrAdd(manifestPath, _ => new SemaphoreSlim(1, 1));

    public async Task IncrementEventsAsync(string jobPath)
    {
        var manifestPath = Path.Combine(jobPath, ".audit", "manifest.json");
        var sem = LockFor(manifestPath);
        await sem.WaitAsync();
        try
        {
            var manifest = ReadManifest(manifestPath);
            if (manifest is null) return;
            var last = manifest.History.LastOrDefault(e => e.To == null);
            if (last is null) return;
            last.Events++;
            WriteManifest(manifestPath, manifest);
        }
        finally { sem.Release(); }
    }

    public void RecordArrival(string jobPath, string machineName)
    {
        var auditDir     = Path.Combine(jobPath, ".audit");
        var manifestPath = Path.Combine(auditDir, "manifest.json");
        var jobName      = Path.GetFileName(jobPath.TrimEnd('\\', '/'));

        var sem = LockFor(manifestPath);
        sem.Wait();
        try
        {
            var manifest = ReadManifest(manifestPath) ?? new JobManifest
            {
                JobName = jobName,
                Created = new MachineTimestamp { Machine = machineName, At = DateTime.UtcNow }
            };

            var last = manifest.History.LastOrDefault();

            if (last?.To == null && !string.Equals(last?.Machine, machineName, StringComparison.OrdinalIgnoreCase))
                last!.To = DateTime.UtcNow;

            if (last == null || !string.Equals(last.Machine, machineName, StringComparison.OrdinalIgnoreCase) || last.To != null)
                manifest.History.Add(new HistoryEntry { Machine = machineName, From = DateTime.UtcNow });

            WriteManifest(manifestPath, manifest);
        }
        finally { sem.Release(); }
    }

    public void RecordDeparture(string jobPath)
    {
        var manifestPath = Path.Combine(jobPath, ".audit", "manifest.json");
        var sem = LockFor(manifestPath);
        sem.Wait();
        try
        {
            var manifest = ReadManifest(manifestPath);
            if (manifest is null) return;
            var last = manifest.History.LastOrDefault();
            if (last?.To == null) { last!.To = DateTime.UtcNow; WriteManifest(manifestPath, manifest); }
        }
        finally { sem.Release(); }
    }

    private JobManifest? ReadManifest(string path)
    {
        if (!File.Exists(path)) return null;
        try { return JsonSerializer.Deserialize<JobManifest>(File.ReadAllText(path), _jsonOpts); }
        catch (Exception ex) { _logger.LogWarning(ex, "ManifestManager: could not read {P}", path); return null; }
    }

    private void WriteManifest(string path, JobManifest manifest)
    {
        var tmp = path + ".tmp";
        try
        {
            File.WriteAllText(tmp, JsonSerializer.Serialize(manifest, _jsonOpts));
            if (!string.Equals(Path.GetPathRoot(tmp), Path.GetPathRoot(path), StringComparison.OrdinalIgnoreCase))
                _logger.LogWarning("ManifestManager: temp and target are on different volumes — manifest write is not atomic.");
            File.Move(tmp, path, overwrite: true);
        }
        catch (Exception ex) { _logger.LogWarning(ex, "ManifestManager: could not write {P}", path); }
    }
}
'@

New-File "FalconAuditService\DirectoryWatcher.cs" @'
namespace FalconAuditService;

using Microsoft.Extensions.Logging;

public class DirectoryWatcher : IDisposable
{
    private FileSystemWatcher?              _watcher;
    private readonly string                 _watchPath;
    private readonly Action<string, string> _onArrived;
    private readonly Action<string>         _onDeparted;
    private readonly ILogger<DirectoryWatcher> _logger;

    public DirectoryWatcher(string watchPath, Action<string, string> onArrived,
                             Action<string> onDeparted, ILogger<DirectoryWatcher> logger)
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
            NotifyFilters = NotifyFilters.DirectoryName, IncludeSubdirectories = false,
            EnableRaisingEvents = true
        };
        _watcher.Created += OnCreated;
        _watcher.Deleted += OnDeleted;
        _watcher.Renamed += OnRenamed;
        _logger.LogInformation("DirectoryWatcher: watching {P} for job folder changes.", _watchPath);
    }

    public void Stop() { _watcher?.Dispose(); _watcher = null; }

    public void EnumerateExisting()
    {
        foreach (var dir in Directory.EnumerateDirectories(_watchPath))
        {
            var name = Path.GetFileName(dir);
            if (!string.IsNullOrEmpty(name)) _onArrived(name, dir);
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
        _logger.LogInformation("DirectoryWatcher: job folder renamed '{O}' -> '{N}'.", e.OldName, e.Name);
        if (!string.IsNullOrEmpty(e.OldName)) _onDeparted(e.OldName!);
        if (!string.IsNullOrEmpty(e.Name))    _onArrived(e.Name!, e.FullPath);
    }

    public void Dispose() => _watcher?.Dispose();
}
'@

New-File "FalconAuditService\ChangeEvent.cs" @'
namespace FalconAuditService;

internal record ChangeEvent(
    string             FullPath,
    WatcherChangeTypes ChangeType,
    DateTime           DetectedAt,
    string?            OldPath = null
);
'@

New-File "FalconAuditService\FileChangeHandler.cs" @'
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileChangeHandler
{
    private readonly ShardRegistry             _shards;
    private readonly SqliteRepository          _globalRepo;
    private readonly FileClassifier            _classifier;
    private readonly ContentCache              _contentCache;
    private readonly ManifestManager           _manifest;
    private readonly ChangeDescriptionEnricher _enricher;
    private readonly MonitorConfig             _config;
    private readonly ILogger<FileChangeHandler> _logger;

    public FileChangeHandler(ShardRegistry shards, SqliteRepository globalRepo,
        FileClassifier classifier, ContentCache contentCache, ManifestManager manifest,
        ChangeDescriptionEnricher enricher, MonitorConfig config, ILogger<FileChangeHandler> logger)
    {
        _shards       = shards;
        _globalRepo   = globalRepo;
        _classifier   = classifier;
        _contentCache = contentCache;
        _manifest     = manifest;
        _enricher     = enricher;
        _config       = config;
        _logger       = logger;
    }

    public async Task HandleAsync(ChangeEvent ev)
    {
        var repo     = GetRepo(ev.FullPath);
        var cls      = _classifier.Classify(ev.FullPath);
        var baseline = await repo.GetBaselineAsync(ev.FullPath);

        string? oldHash = baseline?.LastHash;
        string? newHash = null, oldContent = null, newContent = null, diffText = null;
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
                if (newHash is null) { _logger.LogWarning("Could not hash {P} — skipping.", ev.FullPath); return; }
                if (newHash == oldHash) return;
                changeType = baseline is null ? "Created" : "Modified";

                if (cls.MonitorPriority == "P1" && _config.CaptureContent)
                {
                    var fi = new FileInfo(ev.FullPath);
                    if (fi.Length <= _config.MaxContentBytes)
                    {
                        newContent = await ReadTextAsync(ev.FullPath);
                        oldContent = baseline?.LastContent ?? _contentCache.Get(ev.FullPath);
                        if (changeType == "Modified" && oldContent is not null && newContent is not null)
                            diffText = DiffHelper.UnifiedDiff(oldContent, newContent, Path.GetFileName(ev.FullPath));
                        if (newContent is not null) _contentCache.Set(ev.FullPath, newContent);
                    }
                    else { diffText = $"[content omitted: size {fi.Length:N0} bytes exceeds max_content_bytes]"; }
                }
                break;

            case WatcherChangeTypes.Renamed:
                changeType = "Renamed";
                oldContent = baseline?.LastContent ?? _contentCache.Get(ev.OldPath ?? ev.FullPath);
                newHash    = HashHelper.ComputeSha256(ev.FullPath);
                diffText   = ev.OldPath is not null
                    ? $"{Path.GetFileName(ev.OldPath)} -> {Path.GetFileName(ev.FullPath)}" : null;
                if (ev.OldPath is not null) { await repo.DeleteBaselineAsync(ev.OldPath); _contentCache.Remove(ev.OldPath); }
                break;

            default: return;
        }

        var watch = _config.WatchPath.TrimEnd('\\', '/');
        var relFilepath = ev.FullPath.StartsWith(watch, StringComparison.OrdinalIgnoreCase)
            ? ev.FullPath[(watch.Length)..].TrimStart('\\', '/') : ev.FullPath;

        var entry = new AuditLogEntry
        {
            Filepath        = ev.FullPath,
            RelFilepath     = relFilepath,
            EventType       = changeType,
            OldContent      = oldContent,
            DiffText        = diffText,
            Module          = cls.Module,
            OwnerService    = cls.OwnerService,
            MonitorPriority = cls.MonitorPriority,
            ChangedAt       = ev.DetectedAt.ToString("O"),
            MachineName     = _config.MachineName,
            Sha256Hash      = newHash ?? oldHash ?? "",
            FileDescription = cls.Description,
            ChangeSummary   = _enricher.Enrich(cls.MatchedPattern, changeType, diffText),
            OldFilepath     = changeType == "Renamed" ? ev.OldPath : null
        };

        var bl = new FileBaseline { Filepath=ev.FullPath, LastHash=newHash??oldHash??"",
                                    LastSeen=DateTime.UtcNow.ToString("O"), LastContent=oldContent };
        await repo.InsertAuditEventAsync(entry, bl);

        _logger.LogInformation("Audit event written. File={F} Type={T} Module={M}",
                                Path.GetFileName(ev.FullPath), changeType, cls.Module);

        var (_, jobPath) = ExtractJob(ev.FullPath);
        if (jobPath is not null) await _manifest.IncrementEventsAsync(jobPath);

        if (ev.ChangeType == WatcherChangeTypes.Deleted)
        {
            await repo.DeleteBaselineAsync(ev.FullPath);
            _contentCache.Remove(ev.FullPath);
        }
    }

    private SqliteRepository GetRepo(string filePath)
    {
        var (jobName, jobPath) = ExtractJob(filePath);
        if (jobName is null || jobPath is null) return _globalRepo;
        return _shards.GetOrCreate(jobName, jobPath) ?? _globalRepo;
    }

    private (string? jobName, string? jobPath) ExtractJob(string filePath)
    {
        var watch = _config.WatchPath.TrimEnd('\\', '/');
        if (!filePath.StartsWith(watch, StringComparison.OrdinalIgnoreCase)) return (null, null);
        var relative = filePath[(watch.Length)..].TrimStart('\\', '/');
        var sep      = relative.IndexOfAny(new[] { '\\', '/' });
        if (sep <= 0) return (null, null);
        var jobName = relative[..sep];
        return (jobName, Path.Combine(watch, jobName));
    }

    private static async Task<string?> ReadTextAsync(string path)
    {
        try
        {
            using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return null; }
    }
}
'@

New-File "FalconAuditService\FileMonitorService.cs" @'
namespace FalconAuditService;

using System.Collections.Concurrent;
using System.Threading.Channels;
using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileMonitorService : IDisposable
{
    private FileSystemWatcher?                                         _watcher;
    private readonly ConcurrentDictionary<string, Timer>              _debounce    = new();
    private readonly ConcurrentDictionary<string, FileSystemEventArgs> _latestEvent = new();
    private int _recoveryScheduled;
    private readonly Channel<ChangeEvent> _queue = Channel.CreateBounded<ChangeEvent>(
        new BoundedChannelOptions(1024) { FullMode=BoundedChannelFullMode.Wait, SingleReader=false, SingleWriter=false });
    private Task[]?               _consumers;
    private readonly FileChangeHandler  _handler;
    private readonly CatchUpScanner     _catchUp;
    private readonly MonitorConfig      _config;
    private readonly ILogger<FileMonitorService> _logger;
    private CancellationToken           _ct;

    public FileMonitorService(FileChangeHandler handler, CatchUpScanner catchUp,
                               MonitorConfig config, ILogger<FileMonitorService> logger)
    { _handler=handler; _catchUp=catchUp; _config=config; _logger=logger; }

    public void Start(CancellationToken ct)
    {
        _ct = ct;
        InitWatcher();
        int workerCount = Math.Max(2, Environment.ProcessorCount);
        _consumers = Enumerable.Range(0, workerCount).Select(_ => Task.Run(ConsumeAsync, ct)).ToArray();
        _logger.LogInformation("FileMonitorService: FSW enabled. Path={P} Workers={W}", _config.WatchPath, workerCount);
    }

    public void Stop() => StopAsync().GetAwaiter().GetResult();

    public async Task StopAsync()
    {
        _watcher?.Dispose();
        _queue.Writer.TryComplete();
        if (_consumers is not null) await Task.WhenAll(_consumers).WaitAsync(TimeSpan.FromSeconds(10));
    }

    private void InitWatcher()
    {
        _watcher?.Dispose();
        _watcher = new FileSystemWatcher(_config.WatchPath)
        {
            NotifyFilters         = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.DirectoryName,
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
        _latestEvent[e.FullPath] = e;
        _debounce.AddOrUpdate(
            e.FullPath,
            key => new Timer(FireDebounce, key, _config.DebounceMs, Timeout.Infinite),
            (_, existing) => { existing.Change(_config.DebounceMs, Timeout.Infinite); return existing; });
    }

    private void OnRenamed(object _, RenamedEventArgs e) =>
        _ = TryEnqueueAsync(new ChangeEvent(e.FullPath, WatcherChangeTypes.Renamed, DateTime.UtcNow, e.OldFullPath));

    private void FireDebounce(object? state)
    {
        var key = (string)state!;
        if (_debounce.TryRemove(key, out var t)) t.Dispose();
        if (!_latestEvent.TryRemove(key, out var e)) return;
        _ = TryEnqueueAsync(new ChangeEvent(e.FullPath, e.ChangeType, DateTime.UtcNow));
    }

    private void OnError(object _, ErrorEventArgs e)
    {
        _logger.LogWarning("FSW overflow: {M}. Restarting watcher.", e.GetException().Message);
        InitWatcher();
        if (Interlocked.Exchange(ref _recoveryScheduled, 1) == 0)
            _ = Task.Delay(_config.RecoveryDelayMs, _ct).ContinueWith(_ =>
            {
                Interlocked.Exchange(ref _recoveryScheduled, 0);
                _ = _catchUp.RunAllJobsParallelAsync(_ct);
            }, TaskScheduler.Default);
    }

    private async Task TryEnqueueAsync(ChangeEvent ev)
    {
        using var cts    = new CancellationTokenSource(TimeSpan.FromSeconds(1));
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(_ct, cts.Token);
        try { await _queue.Writer.WriteAsync(ev, linked.Token); }
        catch (OperationCanceledException) when (cts.IsCancellationRequested)
        {
            _logger.LogWarning("Queue full — triggering CatchUpScanner. Path={P}", ev.FullPath);
            _ = Task.Run(() => _catchUp.RunAllJobsParallelAsync(_ct));
        }
    }

    private async Task ConsumeAsync()
    {
        await foreach (var ev in _queue.Reader.ReadAllAsync(_ct))
        {
            try { await _handler.HandleAsync(ev); }
            catch (Exception ex) { _logger.LogError(ex, "Error processing event. Path={P}", ev.FullPath); }
        }
    }

    public void Dispose()
    {
        _watcher?.Dispose();
        foreach (var t in _debounce.Values) t.Dispose();
        _latestEvent.Clear();
    }
}
'@

New-File "FalconAuditService\CatchUpScanner.cs" @'
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class CatchUpScanner
{
    private readonly ShardRegistry             _shards;
    private readonly SqliteRepository          _globalRepo;
    private readonly FileClassifier            _classifier;
    private readonly ContentCache              _contentCache;
    private readonly ChangeDescriptionEnricher _enricher;
    private readonly MonitorConfig             _config;
    private readonly ILogger<CatchUpScanner>   _logger;
    private readonly SemaphoreSlim             _guard = new(1, 1);

    private static readonly HashSet<string> IncludedExts = new(StringComparer.OrdinalIgnoreCase)
    {
        ".txt",".ini",".json",".xml",".csv",".log",".yaml",".yml",
        ".cfg",".dat",".seq",".md",".properties",".conf",".config",
        ".bat",".cmd",".ps1",".sql"
    };

    public CatchUpScanner(ShardRegistry shards, SqliteRepository globalRepo, FileClassifier classifier,
        ContentCache contentCache, ChangeDescriptionEnricher enricher, MonitorConfig config,
        ILogger<CatchUpScanner> logger)
    {
        _shards=shards; _globalRepo=globalRepo; _classifier=classifier;
        _contentCache=contentCache; _enricher=enricher; _config=config; _logger=logger;
    }

    public async Task RunAllJobsParallelAsync(CancellationToken ct)
    {
        var jobNames = Directory.EnumerateDirectories(_config.WatchPath)
                                .Select(Path.GetFileName).Where(n => !string.IsNullOrEmpty(n))
                                .Cast<string>().ToList();

        await Task.WhenAll(jobNames.Select(async jn =>
        {
            var jp = Path.Combine(_config.WatchPath, jn);
            try { await RunJobAsync(jn, jp, ct); }
            catch (Exception ex) { _logger.LogError(ex, "CatchUp failed for {Job}", jn); }
        }));
    }

    public async Task RunJobAsync(string jobName, string jobPath, CancellationToken ct)
    {
        var repo = _shards.GetOrCreate(jobName, jobPath);
        if (repo is null) { _logger.LogWarning("CatchUpScanner: skipping {Job} — shard unavailable.", jobName); return; }
        await CoreAsync(_config.WatchPath, ct, jobPath);
    }

    public async Task RunAsync(string watchPath, CancellationToken ct, string? jobPath = null)
    {
        if (!await _guard.WaitAsync(0)) { _logger.LogWarning("CatchUpScanner: already running — skipping."); return; }
        try   { await CoreAsync(watchPath, ct, jobPath); }
        finally { _guard.Release(); }
    }

    private async Task CoreAsync(string watchPath, CancellationToken ct, string? jobPath)
    {
        var scanRoot = jobPath ?? watchPath;
        var sw       = System.Diagnostics.Stopwatch.StartNew();
        _logger.LogInformation("CatchUpScanner: starting scan. Root={R}", scanRoot);

        var currentFiles = Directory.EnumerateFiles(scanRoot, "*.*", SearchOption.AllDirectories)
                                    .Where(f => IncludedExts.Contains(Path.GetExtension(f))).ToList();

        var repo         = jobPath is not null ? GetRepo(Path.Combine(jobPath, "_dummy")) : null;
        var allBaselines = repo is not null
            ? await repo.GetAllBaselinesAsync()
            : await GetAllBaselinesAsync(currentFiles);

        var baselineMap = allBaselines.ToDictionary(b => b.Filepath, StringComparer.OrdinalIgnoreCase);
        var currentSet  = new HashSet<string>(currentFiles, StringComparer.OrdinalIgnoreCase);
        int created=0, modified=0, deleted=0, unchanged=0;

        foreach (var path in currentFiles)
        {
            ct.ThrowIfCancellationRequested();
            string? hash; long size;
            try { hash=HashHelper.ComputeSha256(path); size=new FileInfo(path).Length; }
            catch (IOException) { continue; }
            if (hash is null) continue;

            var cls      = _classifier.Classify(path);
            var fileRepo = GetRepo(path);
            baselineMap.TryGetValue(path, out var bl);
            var rel = MakeRelPath(path);

            if (bl is null)
            {
                string? content = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (content is not null) _contentCache.Set(path, content);
                await fileRepo.InsertAuditEventAsync(new AuditLogEntry
                {
                    Filepath=path, RelFilepath=rel, EventType="Created", Sha256Hash=hash,
                    OldContent=content, Module=cls.Module, OwnerService=cls.OwnerService,
                    MonitorPriority=cls.MonitorPriority, ChangedAt=DateTime.UtcNow.ToString("O"),
                    MachineName=_config.MachineName, FileDescription=cls.Description,
                    ChangeSummary=_enricher.Enrich(cls.MatchedPattern,"Created",null), IsBackfill=true
                }, new FileBaseline { Filepath=path, LastHash=hash, LastSeen=DateTime.UtcNow.ToString("O"), LastContent=content });
                created++;
            }
            else if (hash != bl.LastHash)
            {
                string? newContent = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (newContent is not null) _contentCache.Set(path, newContent);
                string? diffText = null;
                if (cls.MonitorPriority=="P1" && bl.LastContent is not null && newContent is not null)
                    diffText = DiffHelper.UnifiedDiff(bl.LastContent, newContent, Path.GetFileName(path));
                await fileRepo.InsertAuditEventAsync(new AuditLogEntry
                {
                    Filepath=path, RelFilepath=rel, EventType="Modified", Sha256Hash=hash,
                    OldContent=bl.LastContent, DiffText=diffText, Module=cls.Module, OwnerService=cls.OwnerService,
                    MonitorPriority=cls.MonitorPriority, ChangedAt=DateTime.UtcNow.ToString("O"),
                    MachineName=_config.MachineName, FileDescription=cls.Description,
                    ChangeSummary=_enricher.Enrich(cls.MatchedPattern,"Modified",diffText), IsBackfill=true
                }, new FileBaseline { Filepath=path, LastHash=hash, LastSeen=DateTime.UtcNow.ToString("O"), LastContent=newContent });
                modified++;
            }
            else
            {
                if (cls.MonitorPriority=="P1" && _config.CaptureContent && size<=_config.MaxContentBytes)
                { var c=await ReadIfP1Async(path,cls.MonitorPriority,size); if (c is not null) _contentCache.Set(path,c); }
                await fileRepo.UpsertBaselineAsync(new FileBaseline
                    { Filepath=path, LastHash=hash, LastSeen=DateTime.UtcNow.ToString("O"), LastContent=bl.LastContent });
                unchanged++;
            }
        }

        foreach (var bl in allBaselines)
        {
            ct.ThrowIfCancellationRequested();
            if (currentSet.Contains(bl.Filepath)) continue;
            var fileRepo = GetRepo(bl.Filepath);
            var cls2     = _classifier.Classify(bl.Filepath);
            await fileRepo.InsertAuditEventAsync(new AuditLogEntry
            {
                Filepath=bl.Filepath, RelFilepath=MakeRelPath(bl.Filepath), EventType="Deleted",
                Sha256Hash=bl.LastHash, OldContent=bl.LastContent, Module=cls2.Module, OwnerService=cls2.OwnerService,
                MonitorPriority=cls2.MonitorPriority, ChangedAt=DateTime.UtcNow.ToString("O"),
                MachineName=_config.MachineName, FileDescription=cls2.Description,
                ChangeSummary=_enricher.Enrich(cls2.MatchedPattern,"Deleted",null), IsBackfill=true
            }, new FileBaseline { Filepath=bl.Filepath, LastHash=bl.LastHash, LastSeen=bl.LastSeen });
            await fileRepo.DeleteBaselineAsync(bl.Filepath);
            _contentCache.Remove(bl.Filepath);
            deleted++;
        }

        sw.Stop();
        _logger.LogInformation("CatchUpScanner: done. Created={C} Modified={M} Deleted={D} Unchanged={U} Elapsed={E}ms",
            created, modified, deleted, unchanged, sw.ElapsedMilliseconds);
    }

    private SqliteRepository GetRepo(string filePath)
    {
        var watch = _config.WatchPath.TrimEnd('\\', '/');
        if (!filePath.StartsWith(watch, StringComparison.OrdinalIgnoreCase)) return _globalRepo;
        var relative = filePath[(watch.Length)..].TrimStart('\\', '/');
        var sep      = relative.IndexOfAny(new[] { '\\', '/' });
        if (sep <= 0) return _globalRepo;
        var jobName = relative[..sep];
        return _shards.GetOrCreate(jobName, Path.Combine(watch, jobName)) ?? _globalRepo;
    }

    private string MakeRelPath(string filePath)
    {
        var watch = _config.WatchPath.TrimEnd('\\', '/');
        return filePath.StartsWith(watch, StringComparison.OrdinalIgnoreCase)
            ? filePath[(watch.Length)..].TrimStart('\\', '/') : filePath;
    }

    private async Task<List<FileBaseline>> GetAllBaselinesAsync(List<string> currentFiles)
    {
        var result   = new List<FileBaseline>();
        var jobNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var watch    = _config.WatchPath.TrimEnd('\\', '/');
        foreach (var f in currentFiles)
        {
            var rel = f[(watch.Length)..].TrimStart('\\', '/');
            var sep = rel.IndexOfAny(new[] { '\\', '/' });
            if (sep > 0) jobNames.Add(rel[..sep]);
        }
        result.AddRange(await _globalRepo.GetAllBaselinesAsync());
        foreach (var jn in jobNames)
        {
            var jp   = Path.Combine(_config.WatchPath, jn);
            var repo = _shards.GetOrCreate(jn, jp);
            if (repo is not null) result.AddRange(await repo.GetAllBaselinesAsync());
        }
        return result;
    }

    private async Task<string?> ReadIfP1Async(string path, string priority, long size)
    {
        if (priority != "P1" || !_config.CaptureContent || size > _config.MaxContentBytes) return null;
        try
        {
            using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex) { _logger.LogWarning(ex, "ReadIfP1Async: could not read {P}", path); return null; }
    }
}
'@

New-File "FalconAuditService\Worker.cs" @'
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public class Worker : BackgroundService
{
    private readonly FileMonitorService  _monitor;
    private readonly CatchUpScanner      _catchUp;
    private readonly ShardRegistry       _shards;
    private readonly ManifestManager     _manifest;
    private readonly DirectoryWatcher    _dirWatcher;
    private readonly MonitorConfig       _config;
    private readonly ILogger<Worker>     _logger;

    public Worker(FileMonitorService monitor, CatchUpScanner catchUp, ShardRegistry shards,
        ManifestManager manifest, DirectoryWatcher dirWatcher, MonitorConfig config, ILogger<Worker> logger)
    {
        _monitor=monitor; _catchUp=catchUp; _shards=shards;
        _manifest=manifest; _dirWatcher=dirWatcher; _config=config; _logger=logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("FalconAuditService starting. WatchPath={W}", _config.WatchPath);
        if (!Directory.Exists(_config.WatchPath))
        {
            _logger.LogCritical("WatchPath does not exist: {P}", _config.WatchPath);
            return;
        }

        _monitor.Start(stoppingToken);
        _dirWatcher.Start();
        _logger.LogInformation("FalconAuditService FSW live.");

        _dirWatcher.EnumerateExisting();

        _ = Task.Run(async () =>
        {
            using var scanTimeout = new CancellationTokenSource(TimeSpan.FromMinutes(5));
            using var scanCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, scanTimeout.Token);
            try
            {
                await _catchUp.RunAllJobsParallelAsync(scanCts.Token);
                _logger.LogInformation("CatchUpScanner: full reconciliation complete.");
            }
            catch (OperationCanceledException) when (scanTimeout.IsCancellationRequested)
            { _logger.LogWarning("CatchUpScanner exceeded 5-min limit."); }
            catch (Exception ex) { _logger.LogError(ex, "CatchUpScanner failed."); }
        }, stoppingToken);

        _logger.LogInformation("FalconAuditService running.");
        try { await Task.Delay(Timeout.Infinite, stoppingToken); }
        catch (TaskCanceledException) { }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("StopAsync requested. Draining queue.");
        foreach (var jobName in _shards.JobNames)
            _manifest.RecordDeparture(Path.Combine(_config.WatchPath, jobName));
        _dirWatcher.Stop();
        _monitor.Stop();
        await base.StopAsync(cancellationToken);
        _logger.LogInformation("FalconAuditService stopped.");
    }
}
'@

New-File "FalconAuditService\Program.cs" @'
using FalconAuditService;
using FalconAuditService.Models;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(new ConfigurationBuilder().AddJsonFile("appsettings.json").Build())
    .CreateLogger();

try
{
    IHost host = Host.CreateDefaultBuilder(args)
        .UseWindowsService(o => o.ServiceName = "FalconAuditService")
        .UseSerilog()
        .ConfigureServices((ctx, services) =>
        {
            services.AddSingleton(sp =>
            {
                var globalDbPath = ctx.Configuration["AuditService:GlobalDbPath"] ?? @"C:\bis\auditlog\global.db";
                return new SqliteRepository(globalDbPath,
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<SqliteRepository>>());
            });

            services.AddSingleton(sp =>
            {
                var cfg     = sp.GetRequiredService<SqliteRepository>().LoadConfig();
                var section = ctx.Configuration.GetSection("AuditService");
                var rules   = section["ClassificationRulesPath"];
                var param   = section["ParameterDescriptionsPath"];
                var global  = section["GlobalDbPath"];
                if (!string.IsNullOrEmpty(rules))  cfg.ClassificationRulesPath   = rules;
                if (!string.IsNullOrEmpty(param))   cfg.ParameterDescriptionsPath = param;
                if (!string.IsNullOrEmpty(global))  cfg.GlobalDbPath              = global;
                return cfg;
            });

            services.AddSingleton<ContentCache>();
            services.AddSingleton<ShardRegistry>();
            services.AddSingleton<ManifestManager>();

            services.AddSingleton(sp =>
            {
                var config     = sp.GetRequiredService<MonitorConfig>();
                var classifier = new FileClassifier(
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<FileClassifier>>());
                classifier.LoadRules(config.ClassificationRulesPath);
                return classifier;
            });

            services.AddSingleton(sp =>
            {
                var config  = sp.GetRequiredService<MonitorConfig>();
                var enricher = new ChangeDescriptionEnricher(
                    sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<ChangeDescriptionEnricher>>());
                enricher.Load(config.ParameterDescriptionsPath);
                return enricher;
            });

            services.AddSingleton(sp =>
            {
                var config   = sp.GetRequiredService<MonitorConfig>();
                var shards   = sp.GetRequiredService<ShardRegistry>();
                var manifest = sp.GetRequiredService<ManifestManager>();
                var logger   = sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<DirectoryWatcher>>();
                return new DirectoryWatcher(config.WatchPath,
                    onArrived: (jobName, jobPath) =>
                    {
                        shards.GetOrCreate(jobName, jobPath);
                        manifest.RecordArrival(jobPath, config.MachineName);
                    },
                    onDeparted: (jobName) =>
                    {
                        manifest.RecordDeparture(Path.Combine(config.WatchPath, jobName));
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
catch (Exception ex) { Log.Fatal(ex, "FalconAuditService terminated unexpectedly."); }
finally { Log.CloseAndFlush(); }
'@

New-File "FalconAuditService\install.ps1" @'
#Requires -RunAsAdministrator
param(
    [ValidateSet("Install","Uninstall")]
    [string]$Action      = "Install",
    [string]$InstallPath = "C:\bis\bin\FalconAuditService",
    [string]$DbPath      = "C:\bis\auditlog"
)

$ServiceName = "FalconAuditService"
$ExePath     = Join-Path $InstallPath "FalconAuditService.exe"

if ($Action -eq "Install") {
    if (-not (Test-Path $ExePath)) { Write-Error "Executable not found: $ExePath"; exit 1 }

    if (-not (Test-Path $DbPath)) { New-Item -ItemType Directory -Path $DbPath | Out-Null }

    foreach ($file in @("FileClassificationRules.json","ParameterDescriptions.json")) {
        $src = Join-Path $InstallPath $file
        $dst = Join-Path $DbPath      $file
        if ((Test-Path $src) -and -not (Test-Path $dst)) { Copy-Item $src $dst }
    }

    icacls "C:\job"    /grant "NT SERVICE\FalconAuditSvc:(OI)(CI)R" /T | Out-Null
    icacls $DbPath     /grant "NT SERVICE\FalconAuditSvc:(OI)(CI)M" /T | Out-Null

    sc.exe create $ServiceName binPath= "`"$ExePath`"" start= auto obj= "NT SERVICE\FalconAuditSvc"
    sc.exe description $ServiceName "Monitors c:\job\ for file changes and writes per-job SQLite audit shards."
    sc.exe failure      $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000

    Start-Service -Name $ServiceName
    Write-Host "Service '$ServiceName' installed and started."

} elseif ($Action -eq "Uninstall") {
    if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)?.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force
    }
    sc.exe delete $ServiceName
    Write-Host "Service '$ServiceName' uninstalled."
}
'@

# ============================================================
# FALCONAUDITWEBSERVER
# ============================================================

New-File "FalconAuditWebServer\FalconAuditWebServer.csproj" @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net6.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>true</PublishSingleFile>
    <AssemblyName>FalconAuditWebServer</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite"                 Version="7.0.*" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.Negotiate" Version="6.0.*" />
    <PackageReference Include="Serilog.AspNetCore"                    Version="6.0.*" />
  </ItemGroup>
</Project>
'@

New-File "FalconAuditWebServer\appsettings.json" @'
{
  "AuditWebServer": {
    "WatchPath": "C:\\job",
    "GlobalDb":  "C:\\bis\\auditlog\\global.db"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": { "Url": "http://0.0.0.0:5100" }
    }
  },
  "Logging": {
    "LogLevel": { "Default": "Information", "Microsoft.AspNetCore": "Warning" }
  }
}
'@

New-File "FalconAuditWebServer\Models\AuditEventSummary.cs" @'
namespace FalconAuditWebServer.Models;

public record AuditEventSummary
{
    public long   Id              { get; init; }
    public string ChangedAt       { get; init; } = "";
    public string EventType       { get; init; } = "";
    public string Filepath        { get; init; } = "";
    public string RelFilepath     { get; init; } = "";
    public string Module          { get; init; } = "";
    public string OwnerService    { get; init; } = "";
    public string MonitorPriority { get; init; } = "";
    public string MachineName     { get; init; } = "";
    public string Sha256Hash      { get; init; } = "";
    public string FileDescription { get; init; } = "";
    public string ChangeSummary   { get; init; } = "";
    public bool   IsBackfill      { get; init; }
}
'@

New-File "FalconAuditWebServer\Models\AuditEventDetail.cs" @'
namespace FalconAuditWebServer.Models;

public record AuditEventDetail
{
    public long    Id              { get; init; }
    public string  ChangedAt       { get; init; } = "";
    public string  EventType       { get; init; } = "";
    public string  Filepath        { get; init; } = "";
    public string  RelFilepath     { get; init; } = "";
    public string  Module          { get; init; } = "";
    public string  OwnerService    { get; init; } = "";
    public string  MonitorPriority { get; init; } = "";
    public string  MachineName     { get; init; } = "";
    public string  Sha256Hash      { get; init; } = "";
    public string  FileDescription { get; init; } = "";
    public string  ChangeSummary   { get; init; } = "";
    public string? OldContent      { get; init; }
    public string? DiffText        { get; init; }
    public string? OldFilepath     { get; init; }
    public bool    IsBackfill      { get; init; }
}
'@

New-File "FalconAuditWebServer\Models\JobSummary.cs" @'
namespace FalconAuditWebServer.Models;

public record JobSummary
{
    public string JobName       { get; init; } = "";
    public string ShardPath     { get; init; } = "";
    public long   TotalEvents   { get; init; }
    public string FirstEvent    { get; init; } = "";
    public string LastEvent     { get; init; } = "";
    public string Machines      { get; init; } = "";
    public long   ShardSizeBytes{ get; init; }
}
'@

New-File "FalconAuditWebServer\Models\EventFilter.cs" @'
namespace FalconAuditWebServer.Models;

public record EventFilter
{
    public string? Module    { get; init; }
    public string? Priority  { get; init; }
    public string? Service   { get; init; }
    public string? EventType { get; init; }
    public string? Machine   { get; init; }
    public string? From      { get; init; }
    public string? To        { get; init; }
    public string? Path      { get; init; }
    public int     Page      { get; init; } = 1;
    public int     PageSize  { get; init; } = 50;
    public string  Sort      { get; init; } = "desc";
}
'@

New-File "FalconAuditWebServer\Models\FileHistoryItem.cs" @'
namespace FalconAuditWebServer.Models;

public record FileHistoryItem
{
    public long    Id          { get; init; }
    public string  ChangedAt   { get; init; } = "";
    public string  EventType   { get; init; } = "";
    public string  MachineName { get; init; } = "";
    public string  Sha256Hash  { get; init; } = "";
    public string? OldContent  { get; init; }
    public string? DiffText    { get; init; }
    public bool    IsBackfill  { get; init; }
}
'@

New-File "FalconAuditWebServer\Services\JobDiscoveryService.cs" @'
namespace FalconAuditWebServer.Services;

using FalconAuditWebServer.Models;
using Microsoft.Data.Sqlite;

public class JobDiscoveryService : IDisposable
{
    private readonly string _watchPath;
    private readonly string _globalDb;
    private readonly ILogger<JobDiscoveryService> _logger;
    private readonly Timer _refreshTimer;
    private volatile IReadOnlyList<string> _knownJobs = Array.Empty<string>();

    public JobDiscoveryService(IConfiguration cfg, ILogger<JobDiscoveryService> logger)
    {
        _watchPath   = cfg["AuditWebServer:WatchPath"] ?? @"C:\job";
        _globalDb    = cfg["AuditWebServer:GlobalDb"]  ?? @"C:\bis\auditlog\global.db";
        _logger      = logger;
        Refresh();
        _refreshTimer = new Timer(_ => Refresh(), null, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
    }

    public IReadOnlyList<string> KnownJobs => _knownJobs;
    public string WatchPath => _watchPath;
    public string GlobalDb  => _globalDb;

    public void Refresh()
    {
        try
        {
            var jobs = Directory.EnumerateDirectories(_watchPath)
                .Where(d => File.Exists(Path.Combine(d, ".audit", "audit.db")))
                .Select(d => Path.GetFileName(d)!)
                .ToList();
            _knownJobs = jobs;
        }
        catch (Exception ex) { _logger.LogWarning(ex, "JobDiscoveryService: refresh failed."); }
    }

    public string? ShardPath(string jobName)
    {
        var path = Path.Combine(_watchPath, jobName, ".audit", "audit.db");
        return File.Exists(path) ? path : null;
    }

    public void Dispose() => _refreshTimer.Dispose();
}
'@

New-File "FalconAuditWebServer\Services\QueryRepository.cs" @'
namespace FalconAuditWebServer.Services;

using System.Collections.Concurrent;
using FalconAuditWebServer.Models;
using Microsoft.Data.Sqlite;

public class QueryRepository : IDisposable
{
    private readonly ConcurrentDictionary<string, SqliteConnection> _connections = new(StringComparer.OrdinalIgnoreCase);
    private readonly JobDiscoveryService _discovery;
    private readonly ILogger<QueryRepository> _logger;

    public QueryRepository(JobDiscoveryService discovery, ILogger<QueryRepository> logger)
    { _discovery=discovery; _logger=logger; }

    private SqliteConnection? GetConnection(string dbPath)
    {
        return _connections.GetOrAdd(dbPath, path =>
        {
            try
            {
                var conn = new SqliteConnection($"Data Source={path};Mode=ReadOnly");
                conn.Open();
                using var p = conn.CreateCommand();
                p.CommandText = "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=3000;";
                p.ExecuteNonQuery();
                return conn;
            }
            catch (Exception ex) { _logger.LogError(ex, "QueryRepository: cannot open {P}", path); throw; }
        });
    }

    public List<JobSummary> ListJobs()
    {
        var result = new List<JobSummary>();
        foreach (var job in _discovery.KnownJobs)
        {
            var shardPath = _discovery.ShardPath(job);
            if (shardPath is null) continue;
            try
            {
                var conn = GetConnection(shardPath);
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT COUNT(*), MIN(changed_at), MAX(changed_at), GROUP_CONCAT(DISTINCT machine_name) FROM audit_log";
                using var r = cmd.ExecuteReader();
                if (r.Read())
                    result.Add(new JobSummary
                    {
                        JobName        = job,
                        ShardPath      = shardPath,
                        TotalEvents    = r.IsDBNull(0) ? 0 : r.GetInt64(0),
                        FirstEvent     = r.IsDBNull(1) ? "" : r.GetString(1),
                        LastEvent      = r.IsDBNull(2) ? "" : r.GetString(2),
                        Machines       = r.IsDBNull(3) ? "" : r.GetString(3),
                        ShardSizeBytes = new FileInfo(shardPath).Length
                    });
            }
            catch (Exception ex) { _logger.LogWarning(ex, "QueryRepository: stats failed for {J}", job); }
        }
        return result;
    }

    public (List<AuditEventSummary> Items, long Total) GetEvents(string jobName, EventFilter f)
    {
        var shardPath = _discovery.ShardPath(jobName);
        if (shardPath is null) return (new(), 0);

        var conn   = GetConnection(shardPath);
        var where  = BuildWhere(f);
        var order  = f.Sort == "asc" ? "ASC" : "DESC";
        int offset = (f.Page - 1) * f.PageSize;

        long total = 0;
        using (var cnt = conn.CreateCommand())
        {
            cnt.CommandText = $"SELECT COUNT(*) FROM audit_log WHERE {where}";
            BindFilter(cnt, f);
            total = (long)(cnt.ExecuteScalar() ?? 0L);
        }

        var items = new List<AuditEventSummary>();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $@"SELECT id,changed_at,event_type,filepath,rel_filepath,module,
            owner_service,monitor_priority,machine_name,sha256_hash,file_description,change_summary,is_backfill
            FROM audit_log WHERE {where} ORDER BY changed_at {order} LIMIT @ps OFFSET @off";
        BindFilter(cmd, f);
        cmd.Parameters.AddWithValue("@ps",  f.PageSize);
        cmd.Parameters.AddWithValue("@off", offset);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            items.Add(new AuditEventSummary
            {
                Id=r.GetInt64(0), ChangedAt=r.GetString(1), EventType=r.GetString(2),
                Filepath=r.GetString(3), RelFilepath=r.GetString(4), Module=r.GetString(5),
                OwnerService=r.GetString(6), MonitorPriority=r.GetString(7), MachineName=r.GetString(8),
                Sha256Hash=r.GetString(9),
                FileDescription=r.IsDBNull(10)?"":r.GetString(10),
                ChangeSummary=r.IsDBNull(11)?"":r.GetString(11),
                IsBackfill=!r.IsDBNull(12) && r.GetInt32(12)==1
            });
        return (items, total);
    }

    public AuditEventDetail? GetEvent(string jobName, long id)
    {
        var shardPath = _discovery.ShardPath(jobName);
        if (shardPath is null) return null;
        var conn = GetConnection(shardPath);
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT id,changed_at,event_type,filepath,rel_filepath,module,
            owner_service,monitor_priority,machine_name,sha256_hash,file_description,change_summary,
            old_content,diff_text,old_filepath,is_backfill
            FROM audit_log WHERE id=@id";
        cmd.Parameters.AddWithValue("@id", id);
        using var r = cmd.ExecuteReader();
        if (!r.Read()) return null;
        return new AuditEventDetail
        {
            Id=r.GetInt64(0), ChangedAt=r.GetString(1), EventType=r.GetString(2),
            Filepath=r.GetString(3), RelFilepath=r.GetString(4), Module=r.GetString(5),
            OwnerService=r.GetString(6), MonitorPriority=r.GetString(7), MachineName=r.GetString(8),
            Sha256Hash=r.GetString(9),
            FileDescription=r.IsDBNull(10)?"":r.GetString(10),
            ChangeSummary=r.IsDBNull(11)?"":r.GetString(11),
            OldContent=r.IsDBNull(12)?null:r.GetString(12),
            DiffText=r.IsDBNull(13)?null:r.GetString(13),
            OldFilepath=r.IsDBNull(14)?null:r.GetString(14),
            IsBackfill=!r.IsDBNull(15) && r.GetInt32(15)==1
        };
    }

    public List<FileHistoryItem> GetFileHistory(string jobName, string relFilepath)
    {
        var shardPath = _discovery.ShardPath(jobName);
        if (shardPath is null) return new();
        var conn = GetConnection(shardPath);
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT id,changed_at,event_type,machine_name,sha256_hash,
            old_content,diff_text,is_backfill
            FROM audit_log WHERE rel_filepath=@p ORDER BY changed_at ASC";
        cmd.Parameters.AddWithValue("@p", relFilepath);
        var result = new List<FileHistoryItem>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add(new FileHistoryItem
            {
                Id=r.GetInt64(0), ChangedAt=r.GetString(1), EventType=r.GetString(2),
                MachineName=r.GetString(3), Sha256Hash=r.GetString(4),
                OldContent=r.IsDBNull(5)?null:r.GetString(5),
                DiffText=r.IsDBNull(6)?null:r.GetString(6),
                IsBackfill=!r.IsDBNull(7) && r.GetInt32(7)==1
            });
        return result;
    }

    private static string BuildWhere(EventFilter f)
    {
        var clauses = new List<string> { "1=1" };
        if (f.Module    is not null) clauses.Add("module            = @module");
        if (f.Priority  is not null) clauses.Add("monitor_priority  = @priority");
        if (f.Service   is not null) clauses.Add("owner_service     = @service");
        if (f.EventType is not null) clauses.Add("event_type        = @type");
        if (f.Machine   is not null) clauses.Add("machine_name      = @machine");
        if (f.From      is not null) clauses.Add("changed_at       >= @from");
        if (f.To        is not null) clauses.Add("changed_at       <= @to");
        if (f.Path      is not null) clauses.Add("instr(filepath, @path) > 0");
        return string.Join(" AND ", clauses);
    }

    private static void BindFilter(SqliteCommand cmd, EventFilter f)
    {
        if (f.Module    is not null) cmd.Parameters.AddWithValue("@module",   f.Module);
        if (f.Priority  is not null) cmd.Parameters.AddWithValue("@priority", f.Priority);
        if (f.Service   is not null) cmd.Parameters.AddWithValue("@service",  f.Service);
        if (f.EventType is not null) cmd.Parameters.AddWithValue("@type",     f.EventType);
        if (f.Machine   is not null) cmd.Parameters.AddWithValue("@machine",  f.Machine);
        if (f.From      is not null) cmd.Parameters.AddWithValue("@from",     f.From);
        if (f.To        is not null) cmd.Parameters.AddWithValue("@to",       f.To);
        if (f.Path      is not null) cmd.Parameters.AddWithValue("@path",     f.Path);
    }

    public void Dispose()
    {
        foreach (var c in _connections.Values) c.Dispose();
    }
}
'@

New-File "FalconAuditWebServer\Endpoints\JobsEndpoints.cs" @'
namespace FalconAuditWebServer.Endpoints;

using FalconAuditWebServer.Services;
using System.Text.Json;

public static class JobsEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/jobs", (QueryRepository repo) =>
            Results.Ok(repo.ListJobs()));

        api.MapGet("/jobs/{jobName}/manifest", (string jobName, JobDiscoveryService discovery) =>
        {
            var manifestPath = Path.Combine(discovery.WatchPath, jobName, ".audit", "manifest.json");
            if (!File.Exists(manifestPath)) return Results.NotFound();
            try
            {
                var json = File.ReadAllText(manifestPath);
                return Results.Content(json, "application/json");
            }
            catch { return Results.StatusCode(500); }
        });

        api.MapGet("/jobs/{jobName}/files", (string jobName, QueryRepository repo) =>
        {
            var shardPath = repo.GetType().GetField("_discovery",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.GetValue(repo) is JobDiscoveryService d ? d.ShardPath(jobName) : null;
            if (shardPath is null) return Results.NotFound();
            return Results.Ok(new object());   // implemented in QueryRepository if needed
        });
    }
}
'@

New-File "FalconAuditWebServer\Endpoints\EventsEndpoints.cs" @'
namespace FalconAuditWebServer.Endpoints;

using FalconAuditWebServer.Models;
using FalconAuditWebServer.Services;
using Microsoft.AspNetCore.Authorization;

public static class EventsEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/jobs/{jobName}/events", (
            string jobName, QueryRepository repo,
            string? module, string? priority, string? service,
            string? eventType, string? machine, string? from, string? to, string? path,
            int page = 1, int pageSize = 50, string sort = "desc") =>
        {
            pageSize = Math.Min(pageSize, 500);
            var filter = new EventFilter
            {
                Module=module, Priority=priority, Service=service, EventType=eventType,
                Machine=machine, From=from, To=to, Path=path, Page=page, PageSize=pageSize, Sort=sort
            };
            var (items, total) = repo.GetEvents(jobName, filter);
            return Results.Ok(new { Total = total, Page = page, PageSize = pageSize, Items = items });
        });

        api.MapGet("/jobs/{jobName}/events/{id:long}", [Authorize(Policy = "AuditorOnly")]
            (string jobName, long id, QueryRepository repo) =>
        {
            var detail = repo.GetEvent(jobName, id);
            return detail is null ? Results.NotFound() : Results.Ok(detail);
        });

        api.MapGet("/global/events", (
            QueryRepository repo, JobDiscoveryService discovery,
            int page = 1, int pageSize = 50, string sort = "desc") =>
        {
            pageSize = Math.Min(pageSize, 500);
            var filter = new EventFilter { Page=page, PageSize=pageSize, Sort=sort };
            // Route through global.db by using a pseudo job name
            var (items, total) = repo.GetEventsFromDb(discovery.GlobalDb, filter);
            return Results.Ok(new { Total = total, Page = page, PageSize = pageSize, Items = items });
        });
    }
}
'@

New-File "FalconAuditWebServer\Endpoints\FileHistoryEndpoints.cs" @'
namespace FalconAuditWebServer.Endpoints;

using FalconAuditWebServer.Services;

public static class FileHistoryEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/jobs/{jobName}/history/{*filePath}", (
            string jobName, string filePath, QueryRepository repo, JobDiscoveryService discovery) =>
        {
            // Path traversal guard
            var jobRoot = Path.Combine(discovery.WatchPath, jobName);
            var full    = Path.GetFullPath(Path.Combine(jobRoot, filePath));
            if (!full.StartsWith(jobRoot, StringComparison.OrdinalIgnoreCase))
                return Results.BadRequest("Invalid file path.");

            var relPath = filePath.Replace('/', '\\');
            var history = repo.GetFileHistory(jobName, relPath);
            return Results.Ok(history);
        });
    }
}
'@

New-File "FalconAuditWebServer\Program.cs" @'
using FalconAuditWebServer.Endpoints;
using FalconAuditWebServer.Services;
using Microsoft.AspNetCore.Authentication.Negotiate;
using Microsoft.AspNetCore.Authorization;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(new ConfigurationBuilder().AddJsonFile("appsettings.json").Build())
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();

builder.Services.AddSingleton<JobDiscoveryService>();
builder.Services.AddSingleton<QueryRepository>();

builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme).AddNegotiate();
builder.Services.AddAuthorization(o =>
{
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();
    o.AddPolicy("AuditorOnly", p => p.RequireRole("Auditor"));
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

var api = app.MapGroup("/api");
JobsEndpoints.Map(api);
EventsEndpoints.Map(api);
FileHistoryEndpoints.Map(api);

app.Run();
'@

# ============================================================
# Copy JSON config files if they exist alongside this script
# ============================================================
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
foreach ($jsonFile in @("FileClassificationRules.json","ParameterDescriptions.json")) {
    $src = Join-Path $scriptDir $jsonFile
    $dst = Join-Path $OutputPath "FalconAuditService\$jsonFile"
    if (Test-Path $src) { Copy-Item $src $dst -Force; Write-Host "  Copied $jsonFile" }
    else { Write-Host "  WARNING: $jsonFile not found next to script — copy it manually to FalconAuditService\" }
}

Write-Host "`nDone. Project scaffolded to: $OutputPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  cd `"$OutputPath\FalconAuditService`"  && dotnet build"
Write-Host "  cd `"$OutputPath\FalconAuditWebServer`" && dotnet build"
```

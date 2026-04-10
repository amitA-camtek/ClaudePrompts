# Top-level dirs
Write-Host "=== TOP LEVEL DIRS ==="
Get-ChildItem -Path 'C:\job' -Directory | Select-Object Name | Format-Table -AutoSize

# Count by extension
Write-Host "=== EXTENSION COUNTS ==="
$include = @('.txt','.ini','.json','.xml','.csv','.log','.yaml','.yml','.cfg','.dat','.seq','.md','.properties','.conf','.config','.bat','.cmd','.ps1','.sql')
$exclude = @('.exe','.dll','.pdb','.bin','.img','.bmp','.tiff','.tif','.jpg','.jpeg','.png','.gif','.db','.sqlite','.mdb','.ldf','.mdf','.zip','.gz','.7z','.rar','.obj','.lib','.pyd','.pyc','.class')

Get-ChildItem -Path 'C:\job' -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLower()
    ($include -contains $ext) -and ($exclude -notcontains $ext)
} | Group-Object { $_.Extension.ToLower() } | Sort-Object Count -Descending |
    Select-Object Name, Count, @{N='TotalKB';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum/1KB,1)}} |
    Format-Table -AutoSize

# Root-level files
Write-Host "=== ROOT LEVEL FILES ==="
Get-ChildItem -Path 'C:\job' -File | Select-Object Name, Extension, Length | Format-Table -AutoSize

# Total count and size
Write-Host "=== TOTALS ==="
$all = Get-ChildItem -Path 'C:\job' -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLower()
    ($include -contains $ext) -and ($exclude -notcontains $ext)
}
Write-Host "Total files: $($all.Count)"
Write-Host "Total size: $([math]::Round(($all | Measure-Object Length -Sum).Sum/1KB,1)) KB"

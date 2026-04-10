$include = @('.txt','.ini','.json','.xml','.csv','.log','.yaml','.yml','.cfg','.dat','.seq','.md','.properties','.conf','.config','.bat','.cmd','.ps1','.sql')
$exclude = @('.exe','.dll','.pdb','.bin','.img','.bmp','.tiff','.tif','.jpg','.jpeg','.png','.gif','.db','.sqlite','.mdb','.ldf','.mdf','.zip','.gz','.7z','.rar','.obj','.lib','.pyd','.pyc','.class')

$results = Get-ChildItem -Path 'C:\job' -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLower()
    ($include -contains $ext) -and ($exclude -notcontains $ext)
} | ForEach-Object {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $sample = if ($bytes.Length -gt 512) { $bytes[0..511] } else { $bytes }
        $nonPrint = ($sample | Where-Object { $_ -lt 9 -or ($_ -gt 13 -and $_ -lt 32) -or $_ -eq 127 }).Count
        $ratio = if ($sample.Count -gt 0) { $nonPrint / $sample.Count } else { 0 }
        if ($ratio -le 0.30) {
            $firstBytes = [System.Text.Encoding]::UTF8.GetString($sample)
            $firstLine = ($firstBytes -replace '[\r\n].*','').Trim()
            $firstLine = $firstLine -replace '[^\x20-\x7E]',''
            [PSCustomObject]@{
                FullPath     = $_.FullName
                Extension    = $_.Extension.ToLower()
                SizeBytes    = $_.Length
                LastModified = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                Created      = $_.CreationTime.ToString('yyyy-MM-dd HH:mm')
                FirstLine    = $firstLine.Substring(0, [Math]::Min(120, $firstLine.Length))
                WritableSystem = 'unknown'
            }
        }
    } catch {}
}

$results | ConvertTo-Json -Depth 3

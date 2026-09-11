# Checks src/larp against a manifest exported from Studio.
# Manifest lines: <studioPath>|<className>|<fnv1a32 hex>|<byteLength>
# Produce it with the Luau snippet in src/larp/README.md.
param([Parameter(Mandatory = $true)][string]$Manifest)

$root = Split-Path -Parent $PSScriptRoot
$larp = Join-Path $root "src/larp"

function Get-Fnv1a([byte[]]$bytes) {
	[uint64]$h = 2166136261
	foreach ($b in $bytes) {
		$h = $h -bxor $b
		$h = ((($h -shl 24) -band 0xFFFFFFFF) + $h * 403) % 4294967296
	}
	return ('{0:x8}' -f $h)
}

function Get-RepoPath([string]$studioPath, [string]$class, [bool]$hasChildren) {
	$rel = $studioPath -replace '\.', '/'
	$suffix = switch ($class) { 'Script' { '.server.lua' } 'LocalScript' { '.client.lua' } default { '.lua' } }
	if ($hasChildren) { return "$rel/init$suffix" }
	return "$rel$suffix"
}

$entries = Get-Content $Manifest | Where-Object { $_ -match '\|' } | ForEach-Object {
	$p = $_.Split('|'); [pscustomobject]@{ Path = $p[0]; Class = $p[1]; Hash = $p[2]; Len = [int]$p[3] }
}
$parents = @{}
foreach ($e in $entries) { foreach ($o in $entries) { if ($o.Path.StartsWith($e.Path + '.')) { $parents[$e.Path] = $true } } }

$bad = 0
foreach ($e in $entries) {
	$file = Join-Path $larp (Get-RepoPath $e.Path $e.Class ([bool]$parents[$e.Path]))
	if (-not (Test-Path $file)) { Write-Output "MISSING  $($e.Path) -> $file"; $bad++; continue }
	$text = [IO.File]::ReadAllText($file, [Text.UTF8Encoding]::new($false)) -replace "`r", ''
	$bytes = [Text.Encoding]::UTF8.GetBytes($text)
	$h = Get-Fnv1a $bytes
	if ($h -ne $e.Hash) { Write-Output "DIFFERS  $($e.Path) (studio $($e.Hash)/$($e.Len)B, repo $h/$($bytes.Length)B)"; $bad++ }
}
Write-Output "$($entries.Count - $bad)/$($entries.Count) match"

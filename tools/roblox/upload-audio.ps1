param([string[]]$Files, [string]$Out = "$PSScriptRoot\..\..\.local\roblox\audio-ids.json")
# Uploads audio files to Roblox (Open Cloud Assets API) as the user in .env's ROBLOX_API_KEY,
# waits for each to finish, and records file -> asset id in $Out. Never prints the key.
Add-Type -AssemblyName System.Net.Http
$root = 'C:\Users\omarm\Documents\Larpmaxxing'
$key = (Get-Content "$root\.env" | Where-Object { $_ -match '^\s*ROBLOX_API_KEY\s*=' } | Select-Object -First 1) -replace '^\s*ROBLOX_API_KEY\s*=\s*', ''
$key = $key.Trim().Trim('"')
if (-not $key) { Write-Output "no ROBLOX_API_KEY in .env"; exit 1 }
$userId = '2065214055'
$client = [System.Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Add('x-api-key', $key)
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$results = @{}
if (Test-Path $Out) { (Get-Content $Out -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $results[$_.Name] = $_.Value } }
foreach ($path in $Files) {
	$name = [IO.Path]::GetFileNameWithoutExtension($path)
	if ($results[$name]) { Write-Output "$name already uploaded: $($results[$name])"; continue }
	$pretty = (Get-Culture).TextInfo.ToTitleCase(($name -replace '_take', ' take '))
	$request = @{ assetType = 'Audio'; displayName = "Larpmaxxing $pretty"; description = 'Vocal-only zone music for Larpmaxxing'; creationContext = @{ creator = @{ userId = $userId } } } | ConvertTo-Json -Depth 5 -Compress
	$form = [System.Net.Http.MultipartFormDataContent]::new()
	$form.Add([System.Net.Http.StringContent]::new($request), 'request')
	$file = [System.Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($path))
	$file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('audio/ogg')
	$form.Add($file, 'fileContent', [IO.Path]::GetFileName($path))
	$resp = $client.PostAsync('https://apis.roblox.com/assets/v1/assets', $form).Result
	$body = $resp.Content.ReadAsStringAsync().Result
	if (-not $resp.IsSuccessStatusCode) { Write-Output "$name FAILED $([int]$resp.StatusCode): $body"; continue }
	$op = $body | ConvertFrom-Json
	$opId = if ($op.operationId) { $op.operationId } else { ($op.path -split '/')[-1] }
	$assetId = $null
	for ($i = 0; $i -lt 30 -and -not $assetId; $i++) {
		Start-Sleep -Seconds 2
		$poll = $client.GetAsync("https://apis.roblox.com/assets/v1/operations/$opId").Result
		$pb = $poll.Content.ReadAsStringAsync().Result | ConvertFrom-Json
		if ($pb.done -and $pb.response) { $assetId = $pb.response.assetId }
		elseif ($pb.done -and $pb.error) { Write-Output "$name ERROR: $($pb.error | ConvertTo-Json -Compress)"; break }
	}
	if ($assetId) {
		$results[$name] = $assetId
		Write-Output "$name -> $assetId"
		$results | ConvertTo-Json | Set-Content $Out -Encoding utf8
	} elseif (-not $pb.error) { Write-Output "$name still processing (operation $opId)" }
}

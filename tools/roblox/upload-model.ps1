param([Parameter(Mandatory = $true)][string]$File, [Parameter(Mandatory = $true)][string]$Name, [string]$Description = 'Larpmaxxing car')
# Uploads a 3D model file (FBX) to Roblox as a Model asset (Open Cloud Assets API) with
# .env's ROBLOX_API_KEY, waits for it and prints the asset id. Never prints the key.
Add-Type -AssemblyName System.Net.Http
$root = 'C:\Users\omarm\Documents\Larpmaxxing'
$key = (Get-Content "$root\.env" | Where-Object { $_ -match '^\s*ROBLOX_API_KEY\s*=' } | Select-Object -First 1) -replace '^\s*ROBLOX_API_KEY\s*=\s*', ''
$key = $key.Trim().Trim('"')
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(5)
$client.DefaultRequestHeaders.Add('x-api-key', $key)
$request = @{ assetType = 'Model'; displayName = $Name; description = $Description; creationContext = @{ creator = @{ userId = '2065214055' } } } | ConvertTo-Json -Depth 5 -Compress
$form = [System.Net.Http.MultipartFormDataContent]::new()
$form.Add([System.Net.Http.StringContent]::new($request), 'request')
$content = [System.Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($File))
$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('model/fbx')
$form.Add($content, 'fileContent', [IO.Path]::GetFileName($File))
$resp = $client.PostAsync('https://apis.roblox.com/assets/v1/assets', $form).Result
$body = $resp.Content.ReadAsStringAsync().Result
if (-not $resp.IsSuccessStatusCode) { Write-Output "FAILED $([int]$resp.StatusCode): $body"; exit 1 }
$op = $body | ConvertFrom-Json
$opId = if ($op.operationId) { $op.operationId } else { ($op.path -split '/')[-1] }
for ($i = 0; $i -lt 60; $i++) {
	Start-Sleep -Seconds 3
	$pb = $client.GetAsync("https://apis.roblox.com/assets/v1/operations/$opId").Result.Content.ReadAsStringAsync().Result | ConvertFrom-Json
	if ($pb.done -and $pb.response) { Write-Output "asset $($pb.response.assetId)"; exit 0 }
	if ($pb.done -and $pb.error) { Write-Output "ERROR $($pb.error | ConvertTo-Json -Compress)"; exit 1 }
}
Write-Output "still processing (operation $opId)"

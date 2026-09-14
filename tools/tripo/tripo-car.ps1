param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$Prompt, [string]$Negative = 'logo, text, letters, brand badge, emblem, license plate, wheels, tires, rims', [int]$Faces = 16000)
# Makes a car body with Tripo (text_to_model, textured PBR), converts it to FBX with its pivot
# at the bottom centre, and downloads the preview render, the GLB and the FBX to
# scratchpad\tripo\<Name>. Reads TRIPO_API_KEY from .env and never prints it.
$root = 'C:\Users\omarm\Documents\Larpmaxxing'
$key = (Get-Content "$root\.env" | Where-Object { $_ -match '^\s*TRIPO_API_KEY\s*=' } | Select-Object -First 1) -replace '^\s*TRIPO_API_KEY\s*=\s*', ''
$key = $key.Trim().Trim('"')
$out = Join-Path $PSScriptRoot "..\..\.local\tripo\$Name"
New-Item -ItemType Directory -Force $out | Out-Null
$headers = @{ Authorization = "Bearer $key" }
$api = 'https://api.tripo3d.ai/v2/openapi/task'

function Start-Task($body) {
	$json = $body | ConvertTo-Json -Depth 5 -Compress
	$r = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($json))
	if ($r.code -ne 0) { throw "task failed to start: $($r | ConvertTo-Json -Compress)" }
	return $r.data.task_id
}
function Wait-Task($id) {
	for ($i = 0; $i -lt 180; $i++) {
		Start-Sleep -Seconds 5
		$r = Invoke-RestMethod -Uri "$api/$id" -Headers $headers
		$s = $r.data.status
		if ($s -eq 'success') { return $r.data }
		if ($s -in @('failed', 'cancelled', 'banned', 'expired', 'unknown')) { throw "task $id $s" }
		if ($i % 6 -eq 0) { Write-Output "  $id $s $($r.data.progress)%" }
	}
	throw "task $id timed out"
}
function Save($url, $file) {
	if ($url) { Invoke-WebRequest -Uri $url -OutFile (Join-Path $out $file) -UseBasicParsing; Write-Output "  saved $file" }
}

Write-Output "generating $Name"
$gen = Start-Task @{ type = 'text_to_model'; prompt = $Prompt; negative_prompt = $Negative; model_version = 'v3.1-20260211'; texture = $true; pbr = $true; texture_quality = 'detailed'; face_limit = $Faces }
$done = Wait-Task $gen
Save $done.output.rendered_image 'preview.webp'
Save ($(if ($done.output.pbr_model) { $done.output.pbr_model } else { $done.output.model })) 'model.glb'
Write-Output "converting to FBX"
$conv = Start-Task @{ type = 'convert_model'; original_model_task_id = $gen; format = 'FBX'; face_limit = $Faces; pivot_to_center_bottom = $true; texture_size = 1024; texture_format = 'PNG' }
$cdone = Wait-Task $conv
$url = $cdone.output.model
$ext = if ($url -match '\.zip') { 'zip' } else { 'fbx' }
Save $url "model.$ext"
@{ name = $Name; prompt = $Prompt; generateTask = $gen; convertTask = $conv } | ConvertTo-Json | Set-Content (Join-Path $out 'task.json') -Encoding utf8
Write-Output "done: $out"

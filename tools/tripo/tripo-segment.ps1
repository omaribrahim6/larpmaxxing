param([Parameter(Mandatory = $true)][string]$Name, [int]$Faces = 16000)
# Splits a generated Tripo car (scratchpad\tripo\<Name>\task.json) into named parts with
# mesh_segmentation, then converts the result to FBX (one mesh per part, pivot at the bottom
# centre) and saves seg.glb and seg.fbx next to it. Reads TRIPO_API_KEY from .env, never prints it.
$root = 'C:\Users\omarm\Documents\Larpmaxxing'
$key = (Get-Content "$root\.env" | Where-Object { $_ -match '^\s*TRIPO_API_KEY\s*=' } | Select-Object -First 1) -replace '^\s*TRIPO_API_KEY\s*=\s*', ''
$key = $key.Trim().Trim('"')
$out = Join-Path $PSScriptRoot "..\..\.local\tripo\$Name"
$task = Get-Content (Join-Path $out 'task.json') -Raw | ConvertFrom-Json
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
		if ($r.data.status -eq 'success') { return $r.data }
		if ($r.data.status -in @('failed', 'cancelled', 'banned', 'expired', 'unknown')) { throw "task $id $($r.data.status)" }
	}
	throw "task $id timed out"
}
Write-Output "segmenting $Name"
$seg = Start-Task @{ type = 'mesh_segmentation'; original_model_task_id = $task.generateTask }
$done = Wait-Task $seg
$done.output | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'seg-output.json') -Encoding utf8
$url = if ($done.output.model) { $done.output.model } else { $done.output.pbr_model }
if ($url) { Invoke-WebRequest -Uri $url -OutFile (Join-Path $out 'seg.glb') -UseBasicParsing; Write-Output "  saved seg.glb" }
Write-Output "converting the parts to FBX"
$conv = Start-Task @{ type = 'convert_model'; original_model_task_id = $seg; format = 'FBX'; face_limit = $Faces; pivot_to_center_bottom = $true; texture_size = 1024; texture_format = 'PNG' }
$cdone = Wait-Task $conv
Invoke-WebRequest -Uri $cdone.output.model -OutFile (Join-Path $out 'seg.fbx') -UseBasicParsing
Write-Output "  saved seg.fbx (segment task $seg, convert task $conv)"

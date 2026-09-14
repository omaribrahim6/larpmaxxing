param([string]$Out = "$PSScriptRoot\..\..\.local\roblox\store-ids.json", [switch]$ListOnly)
# Creates Larpmaxxing's game passes and developer products (Open Cloud, beta APIs) with the
# key in .env's ROBLOX_API_KEY, skipping any that already exist by name. Records key -> id
# in $Out. Never prints the key.
Add-Type -AssemblyName System.Net.Http
$root = 'C:\Users\omarm\Documents\Larpmaxxing'
$key = (Get-Content "$root\.env" | Where-Object { $_ -match '^\s*ROBLOX_API_KEY\s*=' } | Select-Object -First 1) -replace '^\s*ROBLOX_API_KEY\s*=\s*', ''
$key = $key.Trim().Trim('"')
$universe = '10765964739'
$client = [System.Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Add('x-api-key', $key)

$passes = @(
	@{ key = 'Reality'; name = 'Turn LARP to Reality'; price = 999; description = 'Your own world where the larps are real: drive the T5 on the highway, walk a real runway with the fit you pick, bench 500 lb in front of a crowd, win a Nobel Prize, and skate with a matcha. Also opens the VIP++ Arena.' },
	@{ key = 'MegaBundle'; name = 'Mega Bundle'; price = 299; description = '2x Points, 2x Magnet and 2x Speed in one, for less than buying all three. Also opens the VIP++ Arena.' },
	@{ key = 'DoublePickups'; name = '2x Points'; price = 199; description = 'Every prop you pick up is worth double, forever. Also opens the VIP++ Arena.' },
	@{ key = 'Magnet'; name = '2x Magnet'; price = 149; description = 'Props fly to you from twice as far away. Also opens the VIP++ Arena.' },
	@{ key = 'Speed'; name = '2x Speed'; price = 149; description = 'Walk and sprint twice as fast. Also opens the VIP++ Arena.' }
)
$products = @(
	@{ key = 'Boost'; name = '2x Boost (15 min)'; price = 29; description = 'Every pickup is worth double for 15 minutes.' },
	@{ key = 'Boost60'; name = '2x Boost (1 hour)'; price = 79; description = 'Every pickup is worth double for a whole hour.' },
	@{ key = 'SummonRush'; name = 'Summon a Stat Rush'; price = 49; description = 'Start a stat rush for the whole server, with your name on it.' }
)

function Get-Json($url) {
	$r = $client.GetAsync($url).Result
	$b = $r.Content.ReadAsStringAsync().Result
	if (-not $r.IsSuccessStatusCode) { Write-Output "LIST FAILED $([int]$r.StatusCode) $url : $b"; return $null }
	return $b | ConvertFrom-Json
}
# every item already on the experience, name -> id
function Get-Existing($url, $idField) {
	$map = @{}
	$json = Get-Json $url
	if ($json -is [string]) { Write-Output $json; return $map }
	foreach ($prop in $json.PSObject.Properties) {
		if ($prop.Value -is [array]) { foreach ($item in $prop.Value) { $map[$item.name] = $item.$idField } }
	}
	return $map
}
function New-Item2($url, $item) {
	$form = [System.Net.Http.MultipartFormDataContent]::new()
	$form.Add([System.Net.Http.StringContent]::new($item.name), 'name')
	$form.Add([System.Net.Http.StringContent]::new($item.description), 'description')
	$form.Add([System.Net.Http.StringContent]::new([string]$item.price), 'price')
	$form.Add([System.Net.Http.StringContent]::new('true'), 'isForSale')
	$form.Add([System.Net.Http.StringContent]::new('false'), 'isRegionalPricingEnabled')
	$r = $client.PostAsync($url, $form).Result
	$b = $r.Content.ReadAsStringAsync().Result
	if (-not $r.IsSuccessStatusCode) { return @{ error = "$([int]$r.StatusCode) $b" } }
	return $b | ConvertFrom-Json
}

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$ids = @{}
$passBase = "https://apis.roblox.com/game-passes/v1/universes/$universe/game-passes"
$productBase = "https://apis.roblox.com/developer-products/v2/universes/$universe/developer-products"
$havePasses = Get-Existing "$passBase/creator?pageSize=100" 'gamePassId'
$haveProducts = Get-Existing "$productBase/creator?pageSize=100" 'productId'
Write-Output ("existing passes: {0}; products: {1}" -f ($havePasses.Keys -join ', '), ($haveProducts.Keys -join ', '))
if ($ListOnly) { exit 0 }
foreach ($p in $passes) {
	if ($havePasses[$p.name]) { $ids[$p.key] = $havePasses[$p.name]; Write-Output "pass $($p.key) exists: $($ids[$p.key])"; continue }
	$res = New-Item2 $passBase $p
	if ($res.error) { Write-Output "pass $($p.key) FAILED $($res.error)" } else { $ids[$p.key] = $res.gamePassId; Write-Output "pass $($p.key) -> $($res.gamePassId)" }
}
foreach ($p in $products) {
	if ($haveProducts[$p.name]) { $ids[$p.key] = $haveProducts[$p.name]; Write-Output "product $($p.key) exists: $($ids[$p.key])"; continue }
	$res = New-Item2 $productBase $p
	if ($res.error) { Write-Output "product $($p.key) FAILED $($res.error)" } else { $ids[$p.key] = $res.productId; Write-Output "product $($p.key) -> $($res.productId)" }
}
$ids | ConvertTo-Json | Set-Content $Out -Encoding utf8

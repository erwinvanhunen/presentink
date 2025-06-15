$mainRaw = get-content package.json -Raw
$targetRaw = get-content ./src/distpackage.json -Raw
$mainJson = $mainRaw | ConvertFrom-Json
$targetJson = $targetRaw | ConvertFrom-Json

$targetJson.version = $mainJson.version
Set-Content ./src/distpackage.json -Value ($targetJson | ConvertTo-Json -Depth 10)
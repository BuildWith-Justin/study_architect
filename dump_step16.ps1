$root = (Get-Location).Path
$out = Join-Path $root 'dump_step16.txt'

'=== STEP 16 DUMP ===' | Set-Content -Path $out -Encoding utf8

'--- lib file tree ---' | Add-Content -Path $out -Encoding utf8
Get-ChildItem -Path lib -Recurse -File | ForEach-Object {
  $_.FullName.Substring($root.Length + 1)
} | Add-Content -Path $out -Encoding utf8

$fixed = @(
  'pubspec.yaml',
  'lib\main.dart',
  'android\app\src\main\AndroidManifest.xml'
)

$patterns = @(
  'notif','reminder','backup','export','import','settings','appearance',
  'theme','more','goal','database','sync_service','route','router','profile','photo'
)

$files = @()
foreach ($f in $fixed) {
  if (Test-Path $f) { $files += (Resolve-Path $f).Path }
}

$found = Get-ChildItem -Path lib -Recurse -File -Filter *.dart | Where-Object {
  $name = $_.Name.ToLower()
  $hit = $false
  foreach ($p in $patterns) { if ($name -like "*$p*") { $hit = $true } }
  $hit -and ($name -notlike '*.g.dart')
}
foreach ($f in $found) { $files += $f.FullName }

$files = $files | Select-Object -Unique

foreach ($file in $files) {
  $rel = $file.Substring($root.Length + 1)
  "`n===== FILE: $rel =====" | Add-Content -Path $out -Encoding utf8
  Get-Content -Path $file -Raw | Add-Content -Path $out -Encoding utf8
}

Write-Host "Done. Files included: $($files.Count)"
Write-Host "Output: $out"

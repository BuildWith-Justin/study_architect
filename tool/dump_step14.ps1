$root = (Get-Location).Path
$out = Join-Path $root 'step14_dump.txt'
Set-Content -Path $out -Value 'STEP 14 DUMP' -Encoding utf8

$files = Get-ChildItem -Path (Join-Path $root 'lib') -Recurse -Filter *.dart | Where-Object {
  $_.Name -match 'insight|suggestion|home_screen|more_screen|study_stats|date_utils|_repository|router|^main\.dart$' -or
  $_.FullName -match '\\models\\'
}

foreach ($f in $files) {
  $rel = $f.FullName.Substring($root.Length + 1)
  Add-Content -Path $out -Value "`n===== FILE: $rel =====" -Encoding utf8
  Add-Content -Path $out -Value (Get-Content -Raw $f.FullName) -Encoding utf8
}

Add-Content -Path $out -Value "`n===== FILE: pubspec.yaml =====" -Encoding utf8
Add-Content -Path $out -Value (Get-Content -Raw (Join-Path $root 'pubspec.yaml')) -Encoding utf8

Write-Host "Done. Files included: $($files.Count)"
Write-Host "Output: $out"

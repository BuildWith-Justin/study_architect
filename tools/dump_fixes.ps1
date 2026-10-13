$root = (Get-Location).Path
$out = Join-Path $root 'dump_fixes.txt'

$all = Get-ChildItem -Path (Join-Path $root 'lib') -Recurse -Filter *.dart |
  Where-Object { $_.Name -notmatch '\.g\.dart$|\.freezed\.dart$' }

$namePattern = 'splash|auth|gate|router|^main\.dart$|profile|student|setup|onboarding|database_service|sync_service|backup|more_screen|settings|data_'
$byName = $all | Where-Object { $_.Name -match $namePattern }

$textPattern = 'could not reach your account|set up a new profile instead|delete all|erase all|clear all data|education'
$byText = $all | Select-String -Pattern $textPattern -List | ForEach-Object { Get-Item $_.Path }

$sql = Get-ChildItem -Path $root -Recurse -Filter *.sql -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(build|\.dart_tool|node_modules|\.git)\\' }

$files = @($byName) + @($byText) + @($sql) | Sort-Object FullName -Unique

Set-Content -Path $out -Value "DUMP FOR FIXES (delete-all-data, splash loader, education level)" -Encoding utf8
foreach ($f in $files) {
  $rel = $f.FullName.Substring($root.Length + 1)
  Add-Content -Path $out -Value "`n===== FILE: $rel =====" -Encoding utf8
  Add-Content -Path $out -Value (Get-Content -Raw -Path $f.FullName) -Encoding utf8
  Write-Host "Added: $rel"
}
Write-Host ""
Write-Host "Done. $($files.Count) files written to dump_fixes.txt"

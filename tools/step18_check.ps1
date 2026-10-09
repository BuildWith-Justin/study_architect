# Study Architect V2 - Step 18 automatic checks
# Run from the project root:  powershell -ExecutionPolicy Bypass -File tools\step18_check.ps1

if (-not (Test-Path "pubspec.yaml")) {
  Write-Host "Run this from the project root (the folder with pubspec.yaml)." -ForegroundColor Red
  exit 1
}

Start-Transcript -Path "tools\step18_report.txt" -Force | Out-Null
$summary = @()

function Add-Result($name, $ok) {
  $script:summary += [pscustomobject]@{ Check = $name; Result = $(if ($ok) { "PASS" } else { "FAIL" }) }
}

Write-Host "`n=== 1. flutter pub get ===" -ForegroundColor Cyan
flutter pub get
Add-Result "pub get" ($LASTEXITCODE -eq 0)

Write-Host "`n=== 2. dart format (check only, nothing is changed) ===" -ForegroundColor Cyan
dart format --output=none --set-exit-if-changed lib test
Add-Result "dart format" ($LASTEXITCODE -eq 0)

Write-Host "`n=== 3. flutter analyze ===" -ForegroundColor Cyan
flutter analyze
Add-Result "flutter analyze" ($LASTEXITCODE -eq 0)

Write-Host "`n=== 4. flutter test ===" -ForegroundColor Cyan
if (Test-Path "test") {
  flutter test
  Add-Result "flutter test" ($LASTEXITCODE -eq 0)
} else {
  Write-Host "No test folder found, skipped."
  Add-Result "flutter test (no test folder)" $true
}

Write-Host "`n=== 5. Refresh audit of every screen ===" -ForegroundColor Cyan
if (Test-Path "lib\screens") {
  Get-ChildItem -Path "lib\screens" -Recurse -Filter "*.dart" | ForEach-Object {
    $t = Get-Content $_.FullName -Raw
    [pscustomobject]@{
      File          = $_.FullName.Replace((Get-Location).Path + "\", "")
      Mixin         = [bool]($t -match "RefreshableScreenMixin")
      PullToRefresh = [bool]($t -match "RefreshIndicator")
      DataBus       = [bool]($t -match "DataRefreshBus")
    }
  } | Format-Table -AutoSize
  Write-Host "Reminder: Tasks screen is a known exception. Onboarding/auth screens do not need refresh."
} else {
  Write-Host "lib\screens not found."
}

Write-Host "`n=== 6. TODO / FIXME left in code ===" -ForegroundColor Cyan
$todos = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | Select-String -Pattern "TODO|FIXME"
if ($todos) { $todos | ForEach-Object { "{0}:{1}  {2}" -f $_.Path.Replace((Get-Location).Path + "\", ""), $_.LineNumber, $_.Line.Trim() } }
else { Write-Host "None found." }

Write-Host "`n=== 7. Secrets safety ===" -ForegroundColor Cyan
$tracked = git ls-files .env 2>$null
if ($tracked) {
  Write-Host ".env is TRACKED by Git. Remove it from Git and rotate your keys!" -ForegroundColor Red
  Add-Result ".env not tracked" $false
} else {
  Write-Host ".env is not tracked by Git. Good."
  Add-Result ".env not tracked" $true
}
$gi = if (Test-Path ".gitignore") { Get-Content ".gitignore" -Raw } else { "" }
Add-Result ".env listed in .gitignore" ($gi -match "(?m)^\.env\s*$")

Write-Host "`n=== 8. Debug print() calls in lib ===" -ForegroundColor Cyan
$prints = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | Select-String -Pattern "^\s*print\("
Write-Host ("Found {0} print() call(s)." -f @($prints).Count)

Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
$summary | Format-Table -AutoSize
Stop-Transcript | Out-Null
Write-Host "Report saved to tools\step18_report.txt"

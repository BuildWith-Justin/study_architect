param([switch]$SkipFreshClone)

$script:Fail = 0
$script:Warn = 0
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:Fail++ }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow; $script:Warn++ }
function Info($m) { Write-Host ""; Write-Host "=== $m ===" -ForegroundColor Cyan }

$report = Join-Path $env:TEMP 'github_sync_report.txt'
Start-Transcript -Path $report -Force | Out-Null

# ---------------------------------------------------------------
Info 'STEP 1 - Git and repository'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Bad 'Git is not installed or not in PATH.'
    Stop-Transcript | Out-Null
    exit 1
}
$inside = git rev-parse --is-inside-work-tree 2>$null
if ($inside -ne 'true') {
    Bad 'This folder is not a Git repository. Run the script from your project root.'
    Stop-Transcript | Out-Null
    exit 1
}
$root = git rev-parse --show-toplevel
Set-Location $root
Ok "Repository root: $root"

$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Bad "No remote called 'origin'. Add one with: git remote add origin <url>"
    Stop-Transcript | Out-Null
    exit 1
}
Ok "origin = $remote"

# ---------------------------------------------------------------
Info 'STEP 2 - Current branch'
$branch = git rev-parse --abbrev-ref HEAD
if ($branch -eq 'main') {
    Ok "You are on 'main'."
} else {
    Bad "You are on '$branch', not 'main'. Work on other branches is NOT on main until merged."
}

# ---------------------------------------------------------------
Info 'STEP 3 - Contacting GitHub (fetch)'
git fetch origin --prune 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Bad 'git fetch failed. Check internet, login, or repository URL.'
    Stop-Transcript | Out-Null
    exit 1
}
Ok 'Fetched latest state from GitHub.'

$remoteMain = git rev-parse --verify origin/main 2>$null
if (-not $remoteMain) {
    Bad "Branch 'main' does not exist on GitHub."
    Stop-Transcript | Out-Null
    exit 1
}
Ok "origin/main exists ($($remoteMain.Substring(0,7)))."

$defaultBranch = (git remote show origin 2>$null | Select-String 'HEAD branch').ToString().Split(':')[1].Trim()
if ($defaultBranch -eq 'main') {
    Ok "GitHub default branch is 'main'."
} else {
    Warn "GitHub default branch is '$defaultBranch', not 'main'. Change it in Repo > Settings > Branches."
}

# ---------------------------------------------------------------
Info 'STEP 4 - Uncommitted or untracked files'
$status = git -c core.quotepath=false status --porcelain
if ($status) {
    Bad 'Files that are NOT committed yet (?? = new, M = modified, D = deleted):'
    $status | ForEach-Object { Write-Host "       $_" }
} else {
    Ok 'Working tree is clean. Everything is committed.'
}

# ---------------------------------------------------------------
Info 'STEP 5 - Local main vs GitHub main'
$counts = (git rev-list --left-right --count 'origin/main...HEAD') -split '\s+'
$behind = [int]$counts[0]
$ahead  = [int]$counts[1]
if ($ahead -eq 0 -and $behind -eq 0) {
    Ok 'Local HEAD and origin/main are identical.'
} else {
    if ($ahead  -gt 0) { Bad "$ahead commit(s) exist locally but are NOT on GitHub. Run: git push origin main" }
    if ($behind -gt 0) { Bad "$behind commit(s) exist on GitHub but not locally. Run: git pull --rebase origin main" }
}

# ---------------------------------------------------------------
Info 'STEP 6 - File-by-file comparison (local tracked vs GitHub main)'
$localFiles  = @(git -c core.quotepath=false ls-files)
$remoteFiles = @(git -c core.quotepath=false ls-tree -r --name-only origin/main)
Write-Host "       Local tracked files : $($localFiles.Count)"
Write-Host "       GitHub main files   : $($remoteFiles.Count)"
if ($localFiles.Count -gt 0 -and $remoteFiles.Count -gt 0) {
    $diff = Compare-Object $localFiles $remoteFiles
    $onlyLocal  = @($diff | Where-Object SideIndicator -eq '<=')
    $onlyRemote = @($diff | Where-Object SideIndicator -eq '=>')
    if ($onlyLocal.Count -eq 0 -and $onlyRemote.Count -eq 0) {
        Ok 'Both file lists match exactly.'
    }
    if ($onlyLocal.Count -gt 0) {
        Bad 'Tracked locally but MISSING on GitHub main:'
        $onlyLocal  | ForEach-Object { Write-Host "       $($_.InputObject)" }
    }
    if ($onlyRemote.Count -gt 0) {
        Warn 'On GitHub main but not in your local tracked files:'
        $onlyRemote | ForEach-Object { Write-Host "       $($_.InputObject)" }
    }
} else {
    Bad 'One of the file lists is empty.'
}

# ---------------------------------------------------------------
Info 'STEP 7 - Files hidden by .gitignore (never pushed)'
$ignoredNoise = '^!! (build/|\.dart_tool/|\.idea/|\.gradle/|android/\.gradle/|android/local\.properties|.*\.iml$|ios/Pods/|ios/\.symlinks/|\.pub-cache/|\.pub/|node_modules/|\.vscode/|.*/Flutter/ephemeral/|.*GeneratedPluginRegistrant|.*generated_plugin|\.flutter-plugins|\.packages)'
$ignored = @(git -c core.quotepath=false status --ignored --porcelain | Where-Object { $_ -like '!!*' -and $_ -notmatch $ignoredNoise })
if ($ignored.Count -eq 0) {
    Ok 'No unexpected ignored files.'
} else {
    Warn 'These files/folders exist locally but are ignored by Git. Make sure none is real source code:'
    $ignored | ForEach-Object { Write-Host "       $_" }
    Write-Host '       (Secrets like .env, key.properties, google-services.json SHOULD stay ignored.)'
}

# ---------------------------------------------------------------
Info 'STEP 8 - Important project files are tracked'
$important = @('pubspec.yaml','pubspec.lock','analysis_options.yaml','.gitignore','.metadata','README.md','lib/main.dart')
foreach ($f in $important) {
    if (Test-Path $f) {
        git ls-files --error-unmatch -- $f 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "$f is tracked." } else { Bad "$f exists locally but is NOT tracked by Git." }
    } else {
        if ($f -in @('README.md','analysis_options.yaml')) { Warn "$f does not exist (optional but recommended)." }
    }
}

# ---------------------------------------------------------------
Info 'STEP 9 - Broken-file checks'
# 9a conflict markers
$markers = git grep -I -n -E '^(<<<<<<< |>>>>>>> )' -- . 2>$null
if ($markers) {
    Bad 'Merge-conflict markers found:'
    $markers | ForEach-Object { Write-Host "       $_" }
} else { Ok 'No merge-conflict markers.' }

# 9b empty Dart files
$empty = @($localFiles | Where-Object { $_ -like '*.dart' -and (Test-Path $_) -and ((Get-Item $_).Length -eq 0) })
if ($empty.Count -gt 0) {
    Bad 'Empty .dart files (probably a failed save):'
    $empty | ForEach-Object { Write-Host "       $_" }
} else { Ok 'No empty .dart files.' }

# 9c big files
$big = @($localFiles | Where-Object { (Test-Path $_) -and ((Get-Item $_).Length -gt 50MB) })
if ($big.Count -gt 0) {
    Warn 'Files over 50 MB (GitHub refuses files over 100 MB):'
    $big | ForEach-Object { Write-Host "       $_" }
} else { Ok 'No oversized files.' }

# 9d case-only duplicates (break on Linux/macOS)
$dups = @($localFiles | Group-Object { $_.ToLower() } | Where-Object Count -gt 1)
if ($dups.Count -gt 0) {
    Bad 'Paths that differ only by upper/lower case:'
    $dups | ForEach-Object { $_.Group | ForEach-Object { Write-Host "       $_" } }
} else { Ok 'No case-only duplicate paths.' }

# 9e nested repos / submodules (appear on GitHub as empty folders)
$gitlinks = @(git ls-files --stage | Where-Object { $_ -match '^160000' })
if ($gitlinks.Count -gt 0) {
    Bad 'Nested repositories/submodules found (their content is NOT in your repo):'
    $gitlinks | ForEach-Object { Write-Host "       $_" }
} else { Ok 'No nested repositories.' }

# 9f repository integrity
$fsck = git fsck --no-progress 2>&1
if ($LASTEXITCODE -eq 0 -and -not ($fsck | Select-String -Pattern 'error|missing|corrupt')) {
    Ok 'git fsck: repository database is healthy.'
} else {
    Bad 'git fsck reported problems:'
    $fsck | ForEach-Object { Write-Host "       $_" }
}

# ---------------------------------------------------------------
Info 'STEP 10 - Fresh clone from GitHub (the real proof)'
if ($SkipFreshClone) {
    Warn 'Fresh-clone test skipped (-SkipFreshClone).'
} else {
    $tmp = Join-Path $env:TEMP ('fresh_clone_' + [guid]::NewGuid().ToString('N').Substring(0,8))
    git clone --quiet --branch main --single-branch $remote $tmp
    if ($LASTEXITCODE -ne 0) {
        Bad 'Could not clone main from GitHub (login/permissions/URL problem).'
    } else {
        Ok "Cloned main into $tmp"
        Push-Location $tmp
        $cloneHead = git rev-parse HEAD
        if ($cloneHead -eq $remoteMain) { Ok 'Clone commit matches origin/main.' } else { Bad 'Clone commit differs from origin/main.' }

        if (Test-Path 'pubspec.yaml') {
            if ((Test-Path '.env.example') -and -not (Test-Path '.env')) {
                Copy-Item '.env.example' '.env'
                Write-Host 'Created .env from .env.example for the test.'
            } elseif (-not (Test-Path '.env.example')) {
                Warn 'No .env.example in the repo: fresh clones cannot build if pubspec lists .env as an asset.'
            }
                        Write-Host '--- flutter pub get ---'
            flutter pub get
            if ($LASTEXITCODE -eq 0) { Ok 'flutter pub get succeeded on the fresh clone.' } else { Bad 'flutter pub get FAILED on the fresh clone.' }

            Write-Host '--- dart format check ---'
            dart format --output=none --set-exit-if-changed .
            if ($LASTEXITCODE -eq 0) { Ok 'Formatting is clean.' } else { Warn 'Some files are not formatted. Run: dart format .' }

            Write-Host '--- flutter analyze ---'
            flutter analyze --no-fatal-infos
            if ($LASTEXITCODE -eq 0) { Ok 'flutter analyze: no issues.' } else { Bad 'flutter analyze found issues on the fresh clone.' }

            if (Test-Path 'test') {
                Write-Host '--- flutter test ---'
                flutter test
                if ($LASTEXITCODE -eq 0) { Ok 'flutter test: all tests passed.' } else { Bad 'flutter test FAILED on the fresh clone.' }
            } else {
                Warn "No 'test' folder in the clone, tests skipped."
            }
        } else {
            Warn 'No pubspec.yaml in the clone, Flutter checks skipped.'
        }
        Pop-Location
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------
Info 'SUMMARY'
if ($script:Fail -eq 0) {
    Write-Host "RESULT: PASS  ($($script:Warn) warning(s))" -ForegroundColor Green
} else {
    Write-Host "RESULT: FAIL  ($($script:Fail) failure(s), $($script:Warn) warning(s))" -ForegroundColor Red
}
Write-Host "Full report saved to: $report"
Stop-Transcript | Out-Null
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }


# Clean Windows install gate. The release workflow runs this before publish.
# A fresh install, a deleted install folder, an upgrade, and an uninstall
# followed by a reinstall must all leave working shortcuts and a running app.
param(
  [Parameter(Mandatory = $true)][string]$Installer,
  [int]$HoldSeconds = 60
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Same-Path([string]$A, [string]$B) {
  $na = ([string]$A).Trim().TrimEnd('\').ToLower()
  $nb = ([string]$B).Trim().TrimEnd('\').ToLower()
  if ($na.Length -gt 0 -and $na -eq $nb) { return $true }
  try {
    if ((Test-Path -LiteralPath $A) -and (Test-Path -LiteralPath $B)) {
      $ra = (Resolve-Path -LiteralPath $A).Path.TrimEnd('\').ToLower()
      $rb = (Resolve-Path -LiteralPath $B).Path.TrimEnd('\').ToLower()
      return $ra -eq $rb
    }
  } catch {}
  return $false
}

function Get-ShortcutPaths {
  $desktop = [Environment]::GetFolderPath('Desktop')
  return @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Prompt Picker.lnk'),
    (Join-Path $desktop 'Prompt Picker.lnk')
  )
}

function Show-CrashLog {
  foreach ($name in @('crash.log', 'startup.log')) {
    $log = Join-Path $env:APPDATA "Prompt Picker\$name"
    if (Test-Path -LiteralPath $log) {
      Write-Host "--- $name ---"
      Get-Content -LiteralPath $log -Tail 120
    }
  }
}

function Stop-PromptPicker {
  $roots = @(
    'C:\Prompt Picker',
    (Join-Path $env:USERPROFILE 'Prompt Picker'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker'),
    (Join-Path $env:APPDATA 'Prompt Picker')
  )
  for ($try = 0; $try -lt 6; $try++) {
    foreach ($name in @('Prompt Picker', 'crashpad_handler')) {
      Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
      $exePath = [string]$_.ExecutablePath
      if (-not $exePath) { return }
      # The uninstaller runs from the install folder when _?= is set.
      # Killing it leaves the app exe in place.
      if ([IO.Path]::GetFileName($exePath) -like 'Uninstall*.exe') { return }
      foreach ($root in $roots) {
        if ($exePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
          Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
      }
    }
    Start-Sleep -Seconds 1
    $left = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
    if ($left.Count -eq 0) { return }
  }
  throw 'Prompt Picker did not exit'
}

function Remove-Tree([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) { return }
  for ($try = 0; $try -lt 8; $try++) {
    try {
      Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction Stop
      return
    } catch {
      Stop-PromptPicker
      Start-Sleep -Seconds 1
      if ($try -eq 7) { throw }
    }
  }
}

function Remove-PromptPickerRegistry {
  foreach ($key in @(
    'HKCU:\Software\Prompt Picker',
    'HKCU:\Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d'
  )) {
    if (Test-Path $key) { Remove-Item $key -Recurse -Force }
  }
  $uninstall = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
  if (Test-Path $uninstall) {
    Get-ChildItem $uninstall | ForEach-Object {
      $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
      if ($props.DisplayName -eq 'Prompt Picker') { Remove-Item $_.PSPath -Recurse -Force }
    }
  }
}

function Resolve-Uninstaller([string]$InstallDir) {
  $un = Join-Path $InstallDir 'Uninstall Prompt Picker.exe'
  if (Test-Path -LiteralPath $un) { return $un }
  if (Test-Path -LiteralPath $InstallDir) {
    $found = Get-ChildItem -LiteralPath $InstallDir -Filter 'Uninstall*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
  }
  return $un
}

function Wait-Gone([string]$Path, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Test-Path -LiteralPath $Path) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
  }
  return -not (Test-Path -LiteralPath $Path)
}

function Invoke-Uninstall([string]$InstallDir, [string]$Mode = 'wipe') {
  $installDir = $InstallDir.TrimEnd('\')
  $un = Resolve-Uninstaller $installDir
  if (-not (Test-Path -LiteralPath $un)) {
    if (Test-Path -LiteralPath $installDir) {
      Write-Host ((Get-ChildItem -LiteralPath $installDir | ForEach-Object { $_.Name }) -join ', ')
    }
    throw "uninstaller missing: $un"
  }
  Stop-PromptPicker
  if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $un }
  # Without _?=, NSIS copies itself to %TEMP% and the process we started
  # exits immediately, before Prompt Picker.exe is deleted. _?= must be
  # last and unquoted, including when the folder name contains spaces.
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $un
  $flag = '/WIPE'
  if ($Mode -eq 'keep') { $flag = '/KEEP' }
  # /S /KEEP or /S /WIPE, then _?= last and unquoted.
  $psi.Arguments = "/S $flag _?=$installDir"
  $psi.UseShellExecute = $false
  $psi.WorkingDirectory = $env:TEMP
  Write-Host "uninstall $un"
  try {
    $p = [Diagnostics.Process]::Start($psi)
  } catch {
    throw "uninstall failed to start: $($_.Exception.Message)"
  }
  if (-not $p.WaitForExit(180000)) {
    try { $p.Kill() } catch {}
    throw 'uninstall timed out'
  }
  if ($p.ExitCode -ne 0) { throw "uninstall exit $($p.ExitCode)" }
  $exe = Join-Path $installDir 'Prompt Picker.exe'
  $deadline = (Get-Date).AddSeconds(15)
  while ((Test-Path -LiteralPath $exe) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
  }
  if (Test-Path -LiteralPath $exe) {
    $names = @(Get-ChildItem -LiteralPath $installDir -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    throw "exe still present after uninstall: $exe (left: $($names -join ', '))"
  }
  if ($Mode -eq 'keep') {
    $unLeft = Join-Path $installDir 'Uninstall Prompt Picker.exe'
    if (-not (Wait-Gone $unLeft 25)) { throw "uninstaller still present after keep: $unLeft" }
  } else {
    if (-not (Wait-Gone $installDir 25)) { throw "install folder still present after wipe: $installDir" }
  }
  Write-Host "uninstalled $installDir ($Mode)"
}

function Reset-Machine {
  Write-Host 'reset machine'
  Stop-PromptPicker
  foreach ($installDir in @(
    'C:\Prompt Picker',
    (Join-Path $env:USERPROFILE 'Prompt Picker'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker')
  )) {
    $un = Resolve-Uninstaller $installDir
    if (Test-Path -LiteralPath $un) { Invoke-Uninstall $installDir }
  }
  Stop-PromptPicker
  foreach ($dir in @(
    'C:\Prompt Picker',
    (Join-Path $env:USERPROFILE 'Prompt Picker'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker'),
    (Join-Path $env:APPDATA 'Prompt Picker'),
    (Join-Path $env:LOCALAPPDATA 'prompt-picker-updater')
  )) {
    Remove-Tree $dir
  }
  foreach ($lnk in (Get-ShortcutPaths)) {
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
  }
  Remove-PromptPickerRegistry
}

function Show-CrashEvents {
  try {
    $start = (Get-Date).AddMinutes(-10)
    Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$start} -ErrorAction SilentlyContinue |
      Select-Object -First 4 |
      ForEach-Object { Write-Host $_.Message }
  } catch {
    Write-Host "no application error events: $($_.Exception.Message)"
  }
}

function Install-Silent([string]$Path, [string]$Directory) {
  Stop-PromptPicker
  if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $Path }
  $dir = ''
  if ($Directory) { $dir = $Directory.TrimEnd('\') }
  for ($try = 1; $try -le 3; $try++) {
    # /D= is last and unquoted, including when the folder name contains spaces.
    $argLine = '/S /currentuser'
    if ($dir) { $argLine = "/S /currentuser /D=$dir" }
    Write-Host "install $Path (try $try) $argLine"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Path
    $psi.Arguments = $argLine
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $env:TEMP
    $p = [Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit(300000)) {
      try { $p.Kill() } catch {}
      throw "installer timed out: $Path"
    }
    if ($p.ExitCode -eq 0) { return }
    $hex = '0x{0:X8}' -f ($p.ExitCode -band 0xFFFFFFFF)
    Write-Host "installer exit $($p.ExitCode) ($hex)"
    Show-CrashEvents
    # NSIS reports setup failures as small positive codes. A negative code
    # is the process crashing (0xC0000005 on a runner) before setup finishes.
    $crashed = $p.ExitCode -lt 0
    if (-not $crashed -or $try -eq 3) { throw "installer exit $($p.ExitCode) ($hex): $Path" }
    Stop-PromptPicker
    Start-Sleep -Seconds 3
  }
}

function Resolve-AppExe {
  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($key in @(
    'HKCU:\Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d',
    'HKCU:\Software\Prompt Picker'
  )) {
    if (-not (Test-Path $key)) { continue }
    $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if ($props.InstallLocation) { $candidates.Add((Join-Path $props.InstallLocation 'Prompt Picker.exe')) }
  }
  $candidates.Add('C:\Prompt Picker\Prompt Picker.exe')
  $candidates.Add((Join-Path $env:USERPROFILE 'Prompt Picker\Prompt Picker.exe'))
  $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker\Prompt Picker.exe'))
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return (Resolve-Path -LiteralPath $c).Path }
  }
  throw "installed exe not found. looked at: $($candidates -join ' | ')"
}

function Assert-Shortcut([string]$Path, [string]$Exe, [switch]$RequireCwd) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "missing shortcut $Path" }
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($Path)
  $target = [string]$lnk.TargetPath
  if (-not $target) { throw "shortcut has no target: $Path" }
  if (-not (Test-Path -LiteralPath $target)) { throw "shortcut target does not exist: $Path -> $target" }
  if (-not (Same-Path $target $Exe)) { throw "shortcut target is stale: $Path -> $target expected $Exe" }
  if ($RequireCwd) {
    $want = Split-Path -Parent $Exe
    if (-not (Same-Path ([string]$lnk.WorkingDirectory) $want)) {
      throw "shortcut working directory is stale: $Path -> $($lnk.WorkingDirectory) expected $want"
    }
  }
  $raw = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Path))
  if ($raw.Contains('com.lineko.promptpicker')) {
    throw "shortcut carries AppUserModelID: $Path"
  }
  Write-Host "shortcut ok $Path"
}

function Assert-Desktop([string]$Exe, [switch]$RequireCwd) {
  Assert-Shortcut (Get-ShortcutPaths)[1] $Exe -RequireCwd:$RequireCwd
}

function Assert-StartMenuGone {
  $paths = @(
    (Get-ShortcutPaths)[0],
    (Join-Path $env:PROGRAMDATA 'Microsoft\Windows\Start Menu\Programs\Prompt Picker.lnk')
  )
  foreach ($lnk in $paths) {
    if (Test-Path -LiteralPath $lnk) { throw "start menu shortcut still present: $lnk" }
  }
  Write-Host 'start menu absent'
}

function Assert-StartupLog([string]$Exe) {
  $log = Join-Path $env:APPDATA 'Prompt Picker\startup.log'
  if (-not (Test-Path -LiteralPath $log)) { throw 'startup.log was not written' }
  $text = Get-Content -LiteralPath $log -Raw
  if ($text -notlike "*$Exe*") { throw "startup.log does not mention $Exe" }
  if ($text -notmatch 'execExists: true') { throw 'startup.log missing execExists' }
  if ($text -notmatch 'AppUserModelID:') { throw 'startup.log missing AppUserModelID' }
  if ($text -notmatch 'defender ') { throw 'startup.log missing defender check' }
  Write-Host 'startup.log ok'
}

function Assert-ShortcutLaunches([string]$Lnk) {
  Write-Host "open shortcut $Lnk"
  Start-Process -FilePath $Lnk -ErrorAction Stop | Out-Null
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt 20) {
    $alive = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
    if ($alive.Count -gt 0) {
      Write-Host 'shortcut launched the app'
      return
    }
    Start-Sleep -Seconds 1
  }
  throw "shortcut did not launch Prompt Picker: $Lnk"
}

function Assert-ShortcutsGone {
  foreach ($lnk in (Get-ShortcutPaths)) {
    if (Test-Path -LiteralPath $lnk) { throw "shortcut still present after uninstall: $lnk" }
  }
}

function Set-BadShortcut([string]$Path) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut($Path)
  $lnk.TargetPath = 'C:\missing\Prompt Picker.exe'
  $lnk.WorkingDirectory = 'C:\missing'
  $lnk.Save()
}

function Assert-StaysOpen {
  param([string]$Exe, [int]$Seconds, [switch]$CheckUi, [string]$Launch, [switch]$AlreadyRunning)
  $file = if ($Launch) { $Launch } else { $Exe }
  if ($AlreadyRunning) {
    Write-Host "watch running app for ${Seconds}s"
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 1
    }
    $proc = Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { throw 'app was not running after the update' }
  } else {
    Write-Host "launch $file for ${Seconds}s"
    if ($CheckUi -and -not $Launch) {
      $proc = Start-Process -FilePath $file -ArgumentList '--remote-debugging-port=9224' -PassThru
    } else {
      $proc = Start-Process -FilePath $file -PassThru
    }
  }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    if ($CheckUi) {
      & node (Join-Path $PSScriptRoot 'windows-ui-check.js') --port 9224 --timeout 40000
      if ($LASTEXITCODE -ne 0) { throw "empty-state UI check failed ($LASTEXITCODE)" }
    }
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
      $alive = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
      if ($alive.Count -eq 0) { throw "Prompt Picker exited after $([int]$sw.Elapsed.TotalSeconds)s (pid $($proc.Id))" }
      Start-Sleep -Seconds 2
    }
  } catch {
    Show-CrashLog
    throw
  }
  Write-Host "still open after ${Seconds}s"
}

function Assert-Version([string]$Exe, [string]$Version) {
  $info = (Get-Item -LiteralPath $Exe).VersionInfo
  $got = "$($info.ProductVersion) $($info.FileVersion)"
  if ($info.ProductVersion -notlike "$Version*" -and $info.FileVersion -notlike "$Version*") {
    throw "installed version '$got' is not $Version"
  }
  Write-Host "version $got"
}

function Compare-Version([string]$A, [string]$B) {
  $aa = $A.Split('.')
  $bb = $B.Split('.')
  for ($i = 0; $i -lt 3; $i++) {
    $da = [int]$aa[$i]
    $db = [int]$bb[$i]
    if ($da -ne $db) { return $da - $db }
  }
  return 0
}

function Get-ReleaseInstaller([string]$Version) {
  $headers = @{ 'User-Agent' = 'PromptPicker'; Accept = 'application/vnd.github+json' }
  if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $($env:GH_TOKEN)" }
  $rel = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/broplaygame75-ai/prompt-picker-releases/releases/tags/v$Version"
  $asset = $rel.assets | Where-Object { $_.name -eq "PromptPicker-Setup-$Version.exe" } | Select-Object -First 1
  if (-not $asset) { throw "no installer asset for $Version" }
  $dest = Join-Path $env:TEMP "PromptPicker-Setup-$Version.exe"
  Write-Host "download $Version"
  Invoke-WebRequest -Headers @{ 'User-Agent' = 'PromptPicker' } -Uri ([string]$asset.browser_download_url) -OutFile $dest
  return $dest
}

# 0.1.12 calls quitAndInstall(true, true): --updated /S --force-run, no /D=.
function Install-LikeOldUpdater([string]$Path) {
  if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $Path }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Path
  $psi.Arguments = '--updated /S --force-run'
  $psi.UseShellExecute = $false
  $psi.WorkingDirectory = $env:TEMP
  Write-Host "old-updater $($psi.Arguments)"
  $p = [Diagnostics.Process]::Start($psi)
  if (-not $p.WaitForExit(300000)) {
    try { $p.Kill() } catch {}
    throw 'old updater install timed out'
  }
  if ($p.ExitCode -ne 0) {
    $chosen = Join-Path $env:TEMP 'prompt-picker-chosen-dir.txt'
    if (Test-Path -LiteralPath $chosen) { Write-Host (Get-Content -LiteralPath $chosen -Raw) }
    throw "old updater install exit $($p.ExitCode)"
  }
}

function Assert-OneUninstallPage([string]$InstallDir) {
  $installDir = $InstallDir.TrimEnd('\')
  $un = Resolve-Uninstaller $installDir
  $exe = Join-Path $installDir 'Prompt Picker.exe'
  if (-not (Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $exe | Out-Null
    $deadline = (Get-Date).AddSeconds(20)
    while (-not (Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 1
    }
  }
  if (-not (Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)) { throw 'app did not start before uninstall' }
  Start-Sleep -Seconds 2
  $before = @(Get-Process | ForEach-Object { $_.Id })
  Write-Host "uninstall page from $un"
  $started = Start-Process -FilePath $un -WorkingDirectory $installDir -PassThru
  $stable = 0
  $high = 0
  $deadline = (Get-Date).AddSeconds(30)
  $ok = $false
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $app = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
    $wins = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 -and $_.ProcessName -ne 'Prompt Picker'
    })
    Write-Host "uninstall windows=$($wins.Count) app=$($app.Count)"
    if ($wins.Count -gt 1) {
      $high++
      if ($high -ge 3) { throw "uninstall opened $($wins.Count) windows" }
    } else { $high = 0 }
    if ($app.Count -eq 0 -and $wins.Count -eq 1) {
      $stable++
      if ($stable -ge 3) { $ok = $true; break }
    } else { $stable = 0 }
  }
  Get-Process -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id -and $_.ProcessName -ne 'Prompt Picker' } | Stop-Process -Force -ErrorAction SilentlyContinue
  if ($started -and -not $started.HasExited) { try { $started.Kill() } catch {} }
  Start-Sleep -Seconds 1
  if (Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue) { throw 'uninstall launched the app' }
  if (-not $ok) { throw 'uninstall did not show exactly one window' }
  Write-Host 'one uninstall window, app stayed closed'
}

function Get-PreviousInstaller([string]$CurrentVersion) {
  $headers = @{ 'User-Agent' = 'PromptPicker'; Accept = 'application/vnd.github+json' }
  if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $($env:GH_TOKEN)" }
  $releases = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/broplaygame75-ai/prompt-picker-releases/releases?per_page=20'
  $best = $null
  foreach ($rel in $releases) {
    if ($rel.draft -or $rel.prerelease) { continue }
    $v = ([string]$rel.tag_name) -replace '^v', ''
    if ($v -notmatch '^\d+\.\d+\.\d+$') { continue }
    if ((Compare-Version $v $CurrentVersion) -ge 0) { continue }
    $asset = $rel.assets | Where-Object { $_.name -eq "PromptPicker-Setup-$v.exe" } | Select-Object -First 1
    if (-not $asset) { continue }
    if ($best -and (Compare-Version $v $best.version) -le 0) { continue }
    $best = @{ version = $v; url = [string]$asset.browser_download_url }
  }
  if (-not $best) { throw "no previous installer before $CurrentVersion" }
  $dest = Join-Path $env:TEMP "PromptPicker-Setup-$($best.version).exe"
  Write-Host "download previous $($best.version)"
  Invoke-WebRequest -Headers @{ 'User-Agent' = 'PromptPicker' } -Uri $best.url -OutFile $dest
  return $dest
}

function Wait-ShortcutRepair([string]$Exe) {
  $deadline = (Get-Date).AddSeconds(20)
  $start = (Get-ShortcutPaths)[0]
  $desktop = (Get-ShortcutPaths)[1]
  while ((Get-Date) -lt $deadline) {
    $alive = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
    if ($alive.Count -eq 0) { throw 'app exited before shortcuts were repaired' }
    $shell = New-Object -ComObject WScript.Shell
    $desktopOk = $false
    if (Test-Path -LiteralPath $desktop) {
      $desktopOk = Same-Path ([string]$shell.CreateShortcut($desktop).TargetPath) $Exe
    }
    if (-not (Test-Path -LiteralPath $start) -and $desktopOk) { return }
    Start-Sleep -Seconds 1
  }
  throw 'shortcuts were not repaired to the running exe'
}

if ($env:OS -ne 'Windows_NT') { throw 'this test runs on Windows' }
if (-not (Test-Path -LiteralPath $Installer)) { throw "installer missing: $Installer" }
$version = [IO.Path]::GetFileNameWithoutExtension($Installer) -replace '^PromptPicker-Setup-', ''
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "cannot read version from $Installer" }
Write-Host "clean-machine test for $version"

try {
  Reset-Machine
  Install-Silent $Installer
  $exe = Resolve-AppExe
  if (-not (Same-Path $exe 'C:\Prompt Picker\Prompt Picker.exe')) { throw "default folder is $exe" }
  Assert-Version $exe $version
  Assert-Desktop $exe
  Assert-StartMenuGone
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -CheckUi
  Assert-StartupLog $exe
  Stop-PromptPicker
  Assert-Desktop $exe -RequireCwd
  Assert-ShortcutLaunches (Get-ShortcutPaths)[1]
  Stop-PromptPicker

  Write-Host 'self-heal stale shortcuts'
  foreach ($lnk in (Get-ShortcutPaths)) { Set-BadShortcut $lnk }
  Start-Process -FilePath $exe | Out-Null
  Wait-ShortcutRepair $exe
  Assert-Desktop $exe -RequireCwd
  Assert-StartMenuGone
  Stop-PromptPicker

  Write-Host 'reinstall when the saved install folder is gone'
  $exe = Resolve-AppExe
  Stop-PromptPicker
  foreach ($lnk in (Get-ShortcutPaths)) { Set-BadShortcut $lnk }
  $dead = Split-Path -Parent $exe
  Remove-Item -LiteralPath $dead -Recurse -Force
  if (Test-Path -LiteralPath $exe) { throw "deleted install folder still has $exe" }
  Install-Silent $Installer
  $exe = Resolve-AppExe
  if (-not (Same-Path $exe 'C:\Prompt Picker\Prompt Picker.exe')) { throw "reinstall folder is $exe" }
  Assert-Version $exe $version
  Assert-Desktop $exe
  Assert-StartMenuGone
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -Launch (Get-ShortcutPaths)[1]
  Stop-PromptPicker

  Write-Host 'custom folder'
  Reset-Machine
  $custom = Join-Path $env:USERPROFILE 'Prompt Picker'
  Install-Silent $Installer -Directory $custom
  $exe = Resolve-AppExe
  $customExe = Join-Path $custom 'Prompt Picker.exe'
  if (-not (Same-Path $exe $customExe)) { throw "custom folder install landed at $exe" }
  Assert-Version $exe $version
  Assert-Desktop $exe -RequireCwd
  Assert-StartMenuGone
  Assert-ShortcutLaunches (Get-ShortcutPaths)[1]
  Stop-PromptPicker

  Write-Host 'keep data, settings, and install choices'
  $marker = Join-Path $custom 'prompt-picker.install.json'
  $markerDeadline = (Get-Date).AddSeconds(20)
  while (-not (Test-Path -LiteralPath $marker) -and (Get-Date) -lt $markerDeadline) {
    Start-Sleep -Seconds 1
  }
  # Stop before writing settings so a late save cannot replace them.
  Stop-PromptPicker
  if (-not (Test-Path -LiteralPath $marker)) {
    $names = @(Get-ChildItem -LiteralPath $custom -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    throw "marker missing before keep: $marker (left: $($names -join ', '))"
  }
  $dataDir = Join-Path $env:APPDATA 'Prompt Picker\data'
  New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
  Set-Content -LiteralPath (Join-Path $dataDir 'KEEP-SENTINEL.txt') -Value 'keep' -Encoding ascii
  $promptsPath = Join-Path $dataDir 'prompts.json'
  $kept = @{ prompts = @(); lang = 'vi'; langChosen = $true; themeColors = @{ pri = '#112233' }; showHints = $true; logSort = 'name-desc'; fontScale = 1.3; ageOk = $true }
  if (Test-Path -LiteralPath $promptsPath) {
    try {
      $cur = Get-Content -LiteralPath $promptsPath -Raw -Encoding utf8 | ConvertFrom-Json
      if ($cur.prompts) { $kept.prompts = @($cur.prompts) }
    } catch {}
  }
  ($kept | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $promptsPath -Encoding utf8
  $userRoot = Join-Path $env:APPDATA 'Prompt Picker'
  @{ activeDataDir = $dataDir } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $userRoot 'config.json') -Encoding utf8
  foreach ($cache in @(
    (Join-Path $env:LOCALAPPDATA 'prompt-picker-updater'),
    (Join-Path $env:TEMP 'prompt-picker-updater')
  )) {
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    Set-Content -LiteralPath (Join-Path $cache 'stale.txt') -Value 'cache' -Encoding ascii
  }
  Invoke-Uninstall $custom 'keep'
  Assert-ShortcutsGone
  if (-not (Test-Path -LiteralPath $dataDir)) { throw 'keep removed the data folder' }
  if (-not (Test-Path -LiteralPath (Join-Path $dataDir 'KEEP-SENTINEL.txt'))) { throw 'keep removed the data sentinel' }
  if (-not (Test-Path -LiteralPath $promptsPath)) { throw 'keep removed prompts.json' }
  $keptNow = Get-Content -LiteralPath $promptsPath -Raw -Encoding utf8 | ConvertFrom-Json
  if ($keptNow.lang -ne 'vi') { throw "keep removed language $($keptNow.lang)" }
  if ($keptNow.logSort -ne 'name-desc') { throw 'keep removed sort' }
  if (-not $keptNow.showHints) { throw 'keep removed hints' }
  if (-not (Test-Path -LiteralPath (Join-Path $userRoot 'config.json'))) { throw 'keep removed config.json' }
  if (-not (Test-Path -LiteralPath $marker)) { throw 'keep removed the install marker' }
  $ppKey = Get-ItemProperty 'HKCU:\Software\Prompt Picker' -ErrorAction SilentlyContinue
  if (-not $ppKey -or -not (Same-Path $ppKey.InstallLocation $custom)) { throw "kept install location missing: $($ppKey.InstallLocation)" }
  if ($ppKey.DesktopShortcut -eq '0') { throw 'desktop shortcut choice was not kept' }
  if (-not $ppKey.'Installer Language') { throw 'installer language was not kept' }
  $guidKey = 'HKCU:\Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d'
  if (-not (Test-Path $guidKey)) { throw 'kept install registry key is missing' }
  $unKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\05ae8bdf-b478-52b5-acc4-ac809166ef4d'
  if (Test-Path $unKey) { throw 'uninstall key remained after keep' }
  foreach ($cache in @(
    (Join-Path $env:LOCALAPPDATA 'prompt-picker-updater'),
    (Join-Path $env:TEMP 'prompt-picker-updater')
  )) {
    if (Test-Path -LiteralPath $cache) { throw "updater cache remained after keep: $cache" }
  }
  Install-Silent $Installer
  $exe = Resolve-AppExe
  if (-not (Same-Path $exe $customExe)) { throw "keep reinstall landed at $exe" }
  Assert-Desktop $exe
  Assert-StartMenuGone
  Start-Process -FilePath $exe | Out-Null
  Start-Sleep -Seconds 8
  Stop-PromptPicker
  $after = Get-Content -LiteralPath $promptsPath -Raw -Encoding utf8 | ConvertFrom-Json
  if ($after.lang -ne 'vi' -or $after.logSort -ne 'name-desc' -or -not $after.showHints) { throw 'settings were not restored after reinstall' }
  if (-not $after.themeColors -or $after.themeColors.pri -ne '#112233') { throw 'theme was not restored after reinstall' }

  Write-Host 'wipe everything'
  Invoke-Uninstall $custom 'wipe'
  if (Test-Path -LiteralPath $userRoot) { throw 'userData remained after wipe' }
  if (Test-Path 'HKCU:\Software\Prompt Picker') { throw 'settings registry remained after wipe' }
  if (Test-Path $guidKey) { throw 'install registry remained after wipe' }
  Assert-ShortcutsGone
  foreach ($cache in @(
    (Join-Path $env:LOCALAPPDATA 'prompt-picker-updater'),
    (Join-Path $env:TEMP 'prompt-picker-updater')
  )) {
    if (Test-Path -LiteralPath $cache) { throw "updater cache remained after wipe: $cache" }
  }

  Write-Host 'upgrade from the previous release'
  Reset-Machine
  $previous = Get-PreviousInstaller $version
  Install-Silent $previous
  $oldExe = Resolve-AppExe
  $oldDir = Split-Path -Parent $oldExe
  Install-Silent $Installer
  $exe = Resolve-AppExe
  if (-not (Same-Path (Split-Path -Parent $exe) $oldDir)) { throw "upgrade did not stay in $oldDir (now $exe)" }
  Assert-Version $exe $version
  Assert-Desktop $exe
  Assert-StartMenuGone
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds
  Stop-PromptPicker

  Write-Host 'uninstall then reinstall'
  $installDir = Split-Path -Parent $exe
  Invoke-Uninstall $installDir
  Assert-ShortcutsGone
  Install-Silent $Installer
  $exe = Resolve-AppExe
  if (-not (Same-Path $exe 'C:\Prompt Picker\Prompt Picker.exe')) { throw "reinstall after uninstall landed at $exe" }
  Assert-Version $exe $version
  Assert-Desktop $exe
  Assert-StartMenuGone
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -CheckUi
  Stop-PromptPicker

  Write-Host 'upgrade 0.1.12 in place, the way its updater launches setup'
  Reset-Machine
  $oldSetup = Get-ReleaseInstaller '0.1.12'
  Install-Silent $oldSetup
  $oldExe = Resolve-AppExe
  $legacy = Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker\Prompt Picker.exe'
  if (-not (Same-Path $oldExe $legacy)) { throw "0.1.12 landed at $oldExe" }
  Start-Process -FilePath $oldExe | Out-Null
  Start-Sleep -Seconds 4
  Install-LikeOldUpdater $Installer
  $chosenFile = Join-Path $env:TEMP 'prompt-picker-chosen-dir.txt'
  if (-not (Test-Path -LiteralPath $chosenFile)) { throw 'setup did not record the install folder' }
  $chosen = (Get-Content -LiteralPath $chosenFile -Raw).Trim()
  if (-not (Same-Path $chosen (Split-Path -Parent $legacy))) { throw "setup chose $chosen" }
  $exe = Resolve-AppExe
  if (-not (Same-Path $exe $legacy)) { throw "0.1.12 update moved the install to $exe" }
  foreach ($extra in @(
    'C:\Prompt Picker\Prompt Picker.exe',
    (Join-Path $env:USERPROFILE 'Prompt Picker\Prompt Picker.exe')
  )) {
    if (Test-Path -LiteralPath $extra) { throw "second install left at $extra" }
  }
  Assert-Version $exe $version
  Assert-Desktop $exe -RequireCwd
  Assert-StartMenuGone
  Assert-StaysOpen -Exe $exe -Seconds 120 -AlreadyRunning
  Assert-StartupLog $exe
  Stop-PromptPicker
  Assert-OneUninstallPage (Split-Path -Parent $exe)
  Invoke-Uninstall (Split-Path -Parent $exe)
  Assert-ShortcutsGone
  Write-Host 'clean-machine ok'
} catch {
  Write-Host "CLEAN MACHINE FAILED: $($_.Exception.Message)"
  Show-CrashLog
  exit 1
}

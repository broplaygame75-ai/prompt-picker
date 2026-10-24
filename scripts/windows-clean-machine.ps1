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
  $log = Join-Path $env:APPDATA 'Prompt Picker\crash.log'
  if (Test-Path -LiteralPath $log) {
    Write-Host '--- crash.log ---'
    Get-Content -LiteralPath $log -Tail 120
  }
}

function Stop-PromptPicker {
  $roots = @(
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

function Reset-Machine {
  Write-Host 'reset machine'
  Stop-PromptPicker
  $installDir = Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker'
  $un = Join-Path $installDir 'Uninstall Prompt Picker.exe'
  if (-not (Test-Path -LiteralPath $un) -and (Test-Path -LiteralPath $installDir)) {
    $found = Get-ChildItem -LiteralPath $installDir -Filter 'Uninstall*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $un = $found.FullName }
  }
  if (Test-Path -LiteralPath $un) {
    if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $un }
    $p = Start-Process -FilePath $un -ArgumentList '/S' -PassThru
    if (-not $p.WaitForExit(120000)) { throw 'uninstall timed out during reset' }
  }
  Stop-PromptPicker
  foreach ($dir in @(
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

function Install-Silent([string]$Path) {
  Stop-PromptPicker
  if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $Path }
  Write-Host "install $Path"
  $p = Start-Process -FilePath $Path -ArgumentList '/S','/currentuser' -PassThru
  if (-not $p.WaitForExit(300000)) {
    try { $p.Kill() } catch {}
    throw "installer timed out: $Path"
  }
  if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode): $Path" }
}

function Resolve-AppExe {
  $candidates = New-Object System.Collections.Generic.List[string]
  $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Prompt Picker\Prompt Picker.exe'))
  foreach ($key in @(
    'HKCU:\Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d',
    'HKCU:\Software\Prompt Picker'
  )) {
    if (-not (Test-Path $key)) { continue }
    $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if ($props.InstallLocation) { $candidates.Add((Join-Path $props.InstallLocation 'Prompt Picker.exe')) }
  }
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
  Write-Host "shortcut ok $Path"
}

function Assert-Shortcuts([string]$Exe, [switch]$RequireCwd) {
  foreach ($lnk in (Get-ShortcutPaths)) { Assert-Shortcut $lnk $Exe -RequireCwd:$RequireCwd }
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
  param([string]$Exe, [int]$Seconds, [switch]$CheckUi, [string]$Launch)
  $file = if ($Launch) { $Launch } else { $Exe }
  Write-Host "launch $file for ${Seconds}s"
  if ($CheckUi -and -not $Launch) {
    $proc = Start-Process -FilePath $file -ArgumentList '--remote-debugging-port=9224' -PassThru
  } else {
    $proc = Start-Process -FilePath $file -PassThru
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
  while ((Get-Date) -lt $deadline) {
    $alive = @(Get-Process -Name 'Prompt Picker' -ErrorAction SilentlyContinue)
    if ($alive.Count -eq 0) { throw 'app exited before shortcuts were repaired' }
    $ready = $true
    foreach ($lnk in (Get-ShortcutPaths)) {
      if (-not (Test-Path -LiteralPath $lnk)) { $ready = $false; break }
      $shell = New-Object -ComObject WScript.Shell
      $target = [string]$shell.CreateShortcut($lnk).TargetPath
      if (-not (Same-Path $target $Exe)) { $ready = $false; break }
    }
    if ($ready) { return }
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
  Assert-Version $exe $version
  Assert-Shortcuts $exe
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -CheckUi
  Stop-PromptPicker
  Assert-Shortcuts $exe -RequireCwd

  Write-Host 'self-heal stale shortcuts'
  foreach ($lnk in (Get-ShortcutPaths)) { Set-BadShortcut $lnk }
  Start-Process -FilePath $exe | Out-Null
  Wait-ShortcutRepair $exe
  Assert-Shortcuts $exe -RequireCwd
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
  Assert-Version $exe $version
  Assert-Shortcuts $exe
  $start = (Get-ShortcutPaths)[0]
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -Launch $start
  Stop-PromptPicker

  Write-Host 'upgrade from the previous release'
  Reset-Machine
  $previous = Get-PreviousInstaller $version
  Install-Silent $previous
  Install-Silent $Installer
  $exe = Resolve-AppExe
  Assert-Version $exe $version
  Assert-Shortcuts $exe
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds
  Stop-PromptPicker

  Write-Host 'uninstall then reinstall'
  $un = Join-Path (Split-Path -Parent $exe) 'Uninstall Prompt Picker.exe'
  if (-not (Test-Path -LiteralPath $un)) { throw "uninstaller missing: $un" }
  $p = Start-Process -FilePath $un -ArgumentList '/S' -PassThru
  if (-not $p.WaitForExit(180000)) { throw 'uninstall timed out' }
  if ($p.ExitCode -ne 0) { throw "uninstall exit $($p.ExitCode)" }
  if (Test-Path -LiteralPath $exe) { throw "exe still present after uninstall: $exe" }
  Assert-ShortcutsGone
  Install-Silent $Installer
  $exe = Resolve-AppExe
  Assert-Version $exe $version
  Assert-Shortcuts $exe
  Assert-StaysOpen -Exe $exe -Seconds $HoldSeconds -CheckUi
  Stop-PromptPicker
  Write-Host 'clean-machine ok'
} catch {
  Write-Host "CLEAN MACHINE FAILED: $($_.Exception.Message)"
  Show-CrashLog
  exit 1
}

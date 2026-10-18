#Requires -Version 5.1
param([switch]$Once, [switch]$Restore, [switch]$ShowCandidates)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath=Join-Path $root 'config.json'
$includePath=Join-Path $root 'include.json'
$excludePath=Join-Path $root 'exclude.json'
function ReadRules([string]$file) {
  if(!(Test-Path -LiteralPath $file)){throw "Missing rules file: $file"}
  $rules=Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
  if($null -eq $rules.processNames -or $null -eq $rules.paths){throw "Invalid rules file (processNames / paths required): $file"}
  return $rules
}
$logPath=Join-Path $root 'gamepower.log'
$statePath=Join-Path $root 'state.json'
function Log([string]$s) { Add-Content -LiteralPath $logPath -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$s) -Encoding UTF8; Write-Host $s }
function GuidFromActive {
  $out=(& powercfg.exe /getactivescheme 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0 -or $out -notmatch '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') { throw "Cannot query active power scheme: $out" }
  return $Matches[1].ToLowerInvariant()
}
function SetPower([string]$guid,[bool]$dry) {
  if($dry) { Log "DRY RUN: would activate $guid"; return }
  $result=(& powercfg.exe /setactive $guid 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0) { throw "Power scheme change failed: $result" }
  Log "Activated power scheme $guid"
}
function PatternsMatch([string]$name,[object[]]$patterns) {
  foreach($pattern in $patterns) { if($name -like [string]$pattern){return $true} }
  return $false
}
function GetGameRoots {
  $roots=New-Object 'System.Collections.Generic.List[string]'
  $steamFiles=@()
  foreach($base in @(${env:ProgramFiles(x86)},$env:ProgramFiles,$env:LOCALAPPDATA)) {
    if($base) {$steamFiles+=Join-Path $base 'Steam\steamapps\libraryfolders.vdf'}
  }
  foreach($reg in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
    try {$p=(Get-ItemProperty -Path $reg -ErrorAction Stop).SteamPath; if($p){$steamFiles+=Join-Path $p 'steamapps\libraryfolders.vdf'}}catch{}
  }
  foreach($file in ($steamFiles|Select-Object -Unique)) {
    $steamapps=Split-Path $file -Parent
    if(Test-Path -LiteralPath $steamapps){
      $roots.Add((Join-Path $steamapps 'common'))
      if(Test-Path -LiteralPath $file){
        foreach($line in (Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)) {
          if($line -match '^\s*"path"\s+"([^"]+)"') {
            $folder=$Matches[1] -replace '\\\\','\'
            $roots.Add((Join-Path $folder 'steamapps\common'))
          }
        }
      }
    }
  }
  return @($roots | Select-Object -Unique)
}
function GetEpicRoots {
  $roots=New-Object 'System.Collections.Generic.List[string]'
  $manifestDir=Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
  if(Test-Path -LiteralPath $manifestDir) {
    foreach($file in (Get-ChildItem -LiteralPath $manifestDir -Filter '*.item' -File -ErrorAction SilentlyContinue)) {
      try {
        $item=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if($item.InstallLocation -and (Test-Path -LiteralPath ([string]$item.InstallLocation))) {$roots.Add([string]$item.InstallLocation)}
      }catch{}
    }
  }
  return @($roots | Select-Object -Unique)
}
function Detect($cfg,$include,$exclude,[string[]]$steam,[string[]]$epic) {
  $matches=New-Object 'System.Collections.Generic.List[string]'
  $candidates=New-Object 'System.Collections.Generic.List[string]'
  $processes=Get-CimInstance Win32_Process -Property ProcessId,Name,ExecutablePath -ErrorAction Stop
  foreach($p in $processes) {
    $name=[string]$p.Name; $path=[string]$p.ExecutablePath
    if(!$name -or !$path){continue}
    $path=$path.TrimEnd('\')
    $candidates.Add("$name | $path")
    if(PatternsMatch $name @($exclude.processNames)){continue}
    if(PatternsMatch $path @($exclude.paths)){continue}
    $reason=$null
    if(PatternsMatch $name @($include.processNames)){$reason='process'}
    if(!$reason -and (PatternsMatch $path @($include.paths))){$reason='include path'}
    if(!$reason -and $cfg.detectSteamLibraryGames) {
      foreach($root in $steam){if($path.StartsWith(($root.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){$reason='Steam library';break}}
    }
    if(!$reason -and $cfg.detectEpicInstalledGames) {
      foreach($root in $epic){if($path.StartsWith(($root.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){$reason='Epic installation';break}}
    }
    if($reason){$matches.Add("$name ($reason)")}
  }
  return @{Matches=@($matches);Candidates=@($candidates)}
}
if(!(Test-Path -LiteralPath $configPath)){throw "Missing config.json"}
$cfg=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if($Restore){
  if(Test-Path -LiteralPath $statePath){
    $s=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
    if($s.originalScheme){SetPower ([string]$s.originalScheme) ([bool]$cfg.dryRun)}
  };exit
}
$steam=@();$epic=@()
if($cfg.detectSteamLibraryGames){$steam=@(GetGameRoots)}
if($cfg.detectEpicInstalledGames){$epic=@(GetEpicRoots)}
Log ('Monitoring start. Steam roots={0}, Epic roots={1}, dryRun={2}' -f $steam.Count,$epic.Count,$cfg.dryRun)
$initial=GuidFromActive
if(!(Test-Path -LiteralPath $statePath)) {@{originalScheme=$initial;createdAt=(Get-Date -Format o)}|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8}
$lastGame=$null;$firstGame=$null;$lastMode='';$currentMatch=''
while($true){
  try {
    # Reload JSON lists every scan: edits do not require a restart.
    $include=ReadRules $includePath
    $exclude=ReadRules $excludePath
    $result=Detect $cfg $include $exclude $steam $epic
    if($ShowCandidates){$result.Candidates|Sort-Object|Out-Host;break}
    $now=Get-Date
    if($result.Matches.Count -gt 0){
      $lastGame=$now
      if(!$firstGame){$firstGame=$now}
      if(($now-$firstGame).TotalSeconds -ge [double]$cfg.gameStartConfirmSeconds){$target='GAME'}else{$target=$lastMode}
    } else {
      $firstGame=$null
      if($lastGame -and ($now-$lastGame).TotalSeconds -lt [double]$cfg.gameExitGraceSeconds){$target=$lastMode}
      else {$target='SAVE'}
    }
    if($target -and $target -ne $lastMode){
      $guid=if($target -eq 'GAME'){[string]$cfg.highPerformanceGuid}else{[string]$cfg.powerSaverGuid}
      if((GuidFromActive) -ne $guid){SetPower $guid ([bool]$cfg.dryRun)}
      $desc=if($target -eq 'GAME'){$result.Matches -join ', '}else{'No game detected'}
      Log "$target : $desc"
      $lastMode=$target
    }
  }catch{Log "ERROR: $($_.Exception.Message)"}
  if($Once){break}
  Start-Sleep -Seconds ([Math]::Max(2,[int]$cfg.pollSeconds))
}

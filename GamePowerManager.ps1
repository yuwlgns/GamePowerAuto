#Requires -Version 5.1
# Windows PowerShell 5.1 / Windows Forms companion UI for GamePowerAuto v2
param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
function Read-JsonFile([string]$name) { $p=Join-Path $root $name; if(!(Test-Path -LiteralPath $p)){throw "$name not found"}; Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json }
function Match-Rules([string]$value, $rules) {foreach($r in @($rules)){if($null -ne $r -and $value -like [string]$r){return $true}}; return $false}
function Steam-Roots {
  $files=@(); $roots=New-Object System.Collections.Generic.List[string]
  foreach($base in @(${env:ProgramFiles(x86)},$env:ProgramFiles,$env:LOCALAPPDATA)) {if($base){$files+=Join-Path $base 'Steam\steamapps\libraryfolders.vdf'}}
  foreach($reg in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {try{$p=(Get-ItemProperty -Path $reg -ErrorAction Stop).SteamPath;if($p){$files+=Join-Path $p 'steamapps\libraryfolders.vdf'}}catch{}}
  foreach($file in ($files|Select-Object -Unique)) {
    $steamapps=Split-Path $file -Parent
    if(Test-Path -LiteralPath $steamapps){$roots.Add((Join-Path $steamapps 'common'))
      if(Test-Path -LiteralPath $file){foreach($line in (Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)){if($line -match '^\s*"path"\s+"([^"]+)"'){$folder=$Matches[1] -replace '\\\\','\';$roots.Add((Join-Path $folder 'steamapps\common'))}}}
    }
  }
  return @($roots|Select-Object -Unique)
}
function Epic-Roots {
  $roots=New-Object System.Collections.Generic.List[string]; $folder=Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
  if(Test-Path -LiteralPath $folder){foreach($file in (Get-ChildItem -LiteralPath $folder -Filter '*.item' -File -ErrorAction SilentlyContinue)){try{$item=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json;if($item.InstallLocation -and (Test-Path -LiteralPath ([string]$item.InstallLocation))){$roots.Add([string]$item.InstallLocation)}}catch{}}}
  return @($roots|Select-Object -Unique)
}
function Has-Prefix([string]$path,$roots) {foreach($r in @($roots)){if($path.StartsWith(([string]$r).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
function Get-Status {
  try {$t=Get-ScheduledTask -TaskName 'GamePowerAuto' -ErrorAction Stop; return [string]$t.State} catch {return 'Not registered'}
}
$form=New-Object System.Windows.Forms.Form
$form.Text='GamePowerAuto - Live Process Manager';$form.Size=New-Object System.Drawing.Size(1090,735);$form.MinimumSize=New-Object System.Drawing.Size(850,600);$form.StartPosition='CenterScreen';$form.Font=New-Object System.Drawing.Font('Malgun Gothic',9)
$top=New-Object System.Windows.Forms.Panel;$top.Dock='Top';$top.Height=98;$form.Controls.Add($top)
$status=New-Object System.Windows.Forms.Label;$status.Location=New-Object System.Drawing.Point(14,12);$status.Size=New-Object System.Drawing.Size(1000,22);$status.Text='Loading...';$top.Controls.Add($status)
$hint=New-Object System.Windows.Forms.Label;$hint.Location=New-Object System.Drawing.Point(14,36);$hint.Size=New-Object System.Drawing.Size(1010,18);$hint.Text='Green=game detected | Orange=excluded | Gray=not detected (process list read every 5 seconds)';$top.Controls.Add($hint)
$filter=New-Object System.Windows.Forms.ComboBox;$filter.DropDownStyle='DropDownList';$filter.Location=New-Object System.Drawing.Point(14,64);$filter.Width=165;[void]$filter.Items.AddRange(@('All processes','Detected games','Excluded','Unclassified'));$filter.SelectedIndex=0;$top.Controls.Add($filter)
$refresh=New-Object System.Windows.Forms.Button;$refresh.Text='Refresh now';$refresh.Location=New-Object System.Drawing.Point(190,63);$refresh.Width=110;$top.Controls.Add($refresh)
$includeBtn=New-Object System.Windows.Forms.Button;$includeBtn.Text='Add to include';$includeBtn.Location=New-Object System.Drawing.Point(310,63);$includeBtn.Width=128;$top.Controls.Add($includeBtn)
$excludeBtn=New-Object System.Windows.Forms.Button;$excludeBtn.Text='Add to exclude';$excludeBtn.Location=New-Object System.Drawing.Point(447,63);$excludeBtn.Width=128;$top.Controls.Add($excludeBtn)
$restartBtn=New-Object System.Windows.Forms.Button;$restartBtn.Text='Restart monitor';$restartBtn.Location=New-Object System.Drawing.Point(585,63);$restartBtn.Width=135;$top.Controls.Add($restartBtn)
$openLog=New-Object System.Windows.Forms.Button;$openLog.Text='Open log';$openLog.Location=New-Object System.Drawing.Point(730,63);$openLog.Width=88;$top.Controls.Add($openLog)
$grid=New-Object System.Windows.Forms.DataGridView;$grid.Dock='Fill';$grid.ReadOnly=$true;$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false;$grid.MultiSelect=$false;$grid.SelectionMode='FullRowSelect';$grid.AutoSizeColumnsMode='Fill';$grid.RowHeadersVisible=$false;$grid.BackgroundColor=[System.Drawing.Color]::White;$grid.AutoGenerateColumns=$false
foreach($c in @(@('PID',70),@('EXE',220),@('Result',130),@('Reason',155),@('Executable path',410))){$col=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$col.Name=$c[0];$col.HeaderText=$c[0];$col.Width=[int]$c[1];if($c[0] -eq 'Executable path'){$col.FillWeight=190}else{$col.FillWeight=90};[void]$grid.Columns.Add($col)}
$form.Controls.Add($grid);$grid.BringToFront();$top.BringToFront()
$script:allRows=@();$script:busy=$false
function Render-Rows {
  # Preserve the user's viewport and selected process during each refresh.
  $topPid=$null; $topIndex=0; $selectedPid=$null; $horizontalOffset=0
  try {
    $topIndex=$grid.FirstDisplayedScrollingRowIndex
    if($topIndex -ge 0 -and $topIndex -lt $grid.Rows.Count){
      $topPid=[string]$grid.Rows[$topIndex].Cells['PID'].Value
    }
  } catch { $topIndex=0 }
  try {
    if($null -ne $grid.CurrentRow){$selectedPid=[string]$grid.CurrentRow.Cells['PID'].Value}
    $horizontalOffset=$grid.HorizontalScrollingOffset
  } catch {}

  $grid.SuspendLayout()
  try {
    $grid.Rows.Clear()
    $selected=[string]$filter.SelectedItem
    foreach($x in $script:allRows){
      if($selected -eq 'Detected games' -and $x.Result -ne 'GAME'){continue}
      if($selected -eq 'Excluded' -and $x.Result -ne 'EXCLUDE'){continue}
      if($selected -eq 'Unclassified' -and $x.Result -ne 'OTHER'){continue}
      $id=$grid.Rows.Add($x.PID,$x.Name,$x.Result,$x.Reason,$x.Path)
      if($x.Result -eq 'GAME'){$grid.Rows[$id].DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(222,247,226)}
      elseif($x.Result -eq 'EXCLUDE'){$grid.Rows[$id].DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(255,239,213)}
    }
    $grid.ClearSelection()
    if($grid.Rows.Count -gt 0){
      $restoreTop=[Math]::Max(0,[Math]::Min($topIndex,$grid.Rows.Count-1))
      if($null -ne $topPid){
        foreach($row in $grid.Rows){
          if([string]$row.Cells['PID'].Value -eq $topPid){$restoreTop=$row.Index;break}
        }
      }
      try{$grid.FirstDisplayedScrollingRowIndex=$restoreTop}catch{}
      if($null -ne $selectedPid){
        foreach($row in $grid.Rows){
          if([string]$row.Cells['PID'].Value -eq $selectedPid){
            $row.Selected=$true
            # Avoid setting CurrentCell: that scrolls the view to the selected row.
            break
          }
        }
      }
      try{$grid.HorizontalScrollingOffset=$horizontalOffset}catch{}
    }
  } finally { $grid.ResumeLayout() }
}
function Update-Snapshot {
  if($script:busy){return};$script:busy=$true
  try {
    $cfg=Read-JsonFile 'config.json';$inc=Read-JsonFile 'include.json';$exc=Read-JsonFile 'exclude.json'
    $steam=@();$epic=@();if($cfg.detectSteamLibraryGames){$steam=@(Steam-Roots)};if($cfg.detectEpicInstalledGames){$epic=@(Epic-Roots)}
    $items=New-Object System.Collections.Generic.List[object]
    foreach($p in (Get-CimInstance Win32_Process -Property ProcessId,Name,ExecutablePath)){
      $name=[string]$p.Name;$path=[string]$p.ExecutablePath
      if(!$name -or !$path){continue};$path=$path.TrimEnd('\')
      $result='OTHER';$reason='No rule'
      if((Match-Rules $name $exc.processNames) -or (Match-Rules $path $exc.paths)){$result='EXCLUDE';$reason='exclude.json'}
      elseif(Match-Rules $name $inc.processNames){$result='GAME';$reason='include: process'}
      elseif(Match-Rules $path $inc.paths){$result='GAME';$reason='include: path'}
      elseif($cfg.detectSteamLibraryGames -and (Has-Prefix $path $steam)){$result='GAME';$reason='Steam library'}
      elseif($cfg.detectEpicInstalledGames -and (Has-Prefix $path $epic)){$result='GAME';$reason='Epic installation'}
      $items.Add([pscustomobject]@{PID=[int]$p.ProcessId;Name=$name;Result=$result;Reason=$reason;Path=$path})
    }
    $script:allRows=@($items | Sort-Object @{Expression={switch($_.Result){'GAME'{0};'EXCLUDE'{1};default{2}}}},Name)
    Render-Rows
    $games=@($script:allRows | Where-Object Result -eq 'GAME');$excludes=@($script:allRows | Where-Object Result -eq 'EXCLUDE')
    $status.Text="$(Get-Date -Format 'HH:mm:ss')  |  Monitor: $(Get-Status)  |  GAME: $($games.Count)  |  EXCLUDED: $($excludes.Count)  |  Visible processes: $($script:allRows.Count)"
    $hint.Text=if($games.Count){'Detected: '+(($games|Select-Object -ExpandProperty Name -Unique) -join ', ')}else{'No game detected by current rules. Process access/paths may be limited by Windows permissions.'}
  }catch{$status.Text='ERROR: '+$_.Exception.Message}finally{$script:busy=$false}
}
function Add-Rule([string]$file) {
  if($grid.SelectedRows.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Select a process first.');return}
  $name=[string]$grid.SelectedRows[0].Cells['EXE'].Value
  if(!$name){return}
  $ans=[System.Windows.Forms.MessageBox]::Show("Add $name to ${file}?`nThis matches ALL processes with this name.",'Confirm',[System.Windows.Forms.MessageBoxButtons]::YesNo)
  if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return}
  try{
    $filePath=Join-Path $root $file;$obj=Read-JsonFile $file;$names=@($obj.processNames);if($names -notcontains $name){$obj.processNames=@($names+$name);$json=$obj|ConvertTo-Json -Depth 12;[System.IO.File]::WriteAllText($filePath,$json,(New-Object System.Text.UTF8Encoding($false)))}
    Update-Snapshot
  }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Failed')}
}
$refresh.Add_Click({Update-Snapshot});$filter.Add_SelectedIndexChanged({Render-Rows});$includeBtn.Add_Click({Add-Rule 'include.json'});$excludeBtn.Add_Click({Add-Rule 'exclude.json'})
$restartBtn.Add_Click({
  $ans=[System.Windows.Forms.MessageBox]::Show('Restart the GamePowerAuto scheduled task? This does NOT reboot Windows.','Restart monitor',[System.Windows.Forms.MessageBoxButtons]::YesNo)
  if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return}
  try{
    $t=Get-ScheduledTask -TaskName 'GamePowerAuto' -ErrorAction Stop
    if($t.State -eq 'Running'){Stop-ScheduledTask -TaskName 'GamePowerAuto' -ErrorAction Stop;Start-Sleep -Milliseconds 800}
    Start-ScheduledTask -TaskName 'GamePowerAuto' -ErrorAction Stop
    [System.Windows.Forms.MessageBox]::Show('Restart command sent. Check the log for successful startup.','GamePowerAuto')
    Update-Snapshot
  }catch{[System.Windows.Forms.MessageBox]::Show("Could not restart task. Try running this manager as Administrator.`n$($_.Exception.Message)",'Error')}
})
$openLog.Add_Click({$path=Join-Path $root 'gamepower.log';if(Test-Path -LiteralPath $path){Start-Process notepad.exe -ArgumentList ('"'+$path+'"')}else{[System.Windows.Forms.MessageBox]::Show('No log file yet.')}})
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=5000;$timer.Add_Tick({Update-Snapshot});$form.Add_Shown({Update-Snapshot;$timer.Start()});$form.Add_FormClosing({$timer.Stop()})
[void]$form.ShowDialog()

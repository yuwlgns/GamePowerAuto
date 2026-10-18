GamePowerAuto - Windows 10/11 Desktop, Windows PowerShell 5.1

Important: This is heuristic game detection, not foolproof game recognition.
It detects executables under installed Steam/Epic game folders, plus explicit process/path rules.
Xbox/Game Pass and non-Steam/Epic titles may require an includeProcessNames or includePaths entry.
Launchers and common non-game tools are excluded. Games can be missed when an install path is hidden.

QUICK START (PowerShell as administrator for actual power changes and installation):
1. Extract to C:\GamePowerAuto (do not run from a ZIP).
2. Run: powercfg /list
3. Open config.json. Check highPerformanceGuid and powerSaverGuid exist in /list.
   If absent, create schemes manually with:
   powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
   powercfg /duplicatescheme a1841308-3541-4fab-bc81-f71556f20b4a
   Copy NEW GUIDs printed by powercfg into config.json.
   Some modern standby devices do not permit these legacy schemes.
4. Keep dryRun=true and run:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\GamePowerAuto.ps1
5. Launch a game, quit it. Inspect gamepower.log. Ctrl+C to stop.
6. Change dryRun to false in config.json, and rerun the test.
7. If successful, run .\Install.ps1 as administrator to register at logon.
   Start the task from Task Scheduler once after installation.
8. Remove automation: .\Uninstall.ps1. Restore the original plan via .\GamePowerAuto.ps1 -Restore

TUNING:
- exclude.json processNames: names of non-game .exe files (highest priority)
- exclude.json paths: wildcard patterns of program paths to ignore
- include.json processNames: known game .exe files
- include.json paths: wildcard patterns for custom game directories, e.g. D:\\Games\\* in JSON
- 'ShowCandidates' option prints current processes and paths: .\GamePowerAuto.ps1 -ShowCandidates
- dryRun true logs changes without making them
- The original plan is stored on first run in state.json; delete state.json only if you want to reset this baseline.
- The launcher itself is never used to infer gameplay. Steam game tools in steamapps/common may cause false positives.
- Automatic power mode may impact background rendering/compilation; add exceptions as necessary.
- GameExitGraceSeconds prevents short process restarts causing mode flapping.
- Stop scheduled task before updating files. Does not modify CPU/GPU clocks, registry, BIOS, or voltage.

IMPORTANT: Edit include.json and exclude.json for rules; changes are reloaded during monitoring. Korean guide: README.md.

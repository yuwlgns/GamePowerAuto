# GamePowerAuto 사용 설명서 (한국어)

Windows 10/11 + Windows PowerShell 5.1용 게임 감지 자동 전원 계획 전환 도구입니다.

**중요:** 모든 게임을 확실하게 인식하는 기능은 아닙니다. Steam/Epic 설치 경로와 실행 파일 이름/경로 규칙을 이용합니다. Steam 폴더의 게임 외 프로그램(Wallpaper Engine 등)은 게임으로 오인될 수 있으므로 제외 목록으로 관리합니다.

## 파일 구성

- `GamePowerAuto.ps1`: 감지 및 전원 계획 전환 프로그램
- `config.json`: 검사 주기, 전원 계획 GUID, 테스트 모드 등 기본 설정
- `include.json`: **게임으로 추가할 프로그램** 목록 (한 줄에 하나씩)
- `exclude.json`: **감지에서 제외할 프로그램** 목록 (한 줄에 하나씩)
- `Install.ps1`: 로그인 시 자동 실행 작업 등록
- `Uninstall.ps1`: 자동 실행 작업 제거
- `gamepower.log`, `state.json`: 실행 시 자동 생성되는 로그/원래 전원 계획 기록

## 1. 설치 및 최초 테스트

1. ZIP 내부의 `GamePowerAuto` 폴더를 `C:\GamePowerAuto`에 복사합니다. ZIP 내부에서 직접 실행하지 마세요.
2. 관리자 권한 PowerShell을 열고 `cd C:\GamePowerAuto`를 입력합니다.
3. `powercfg /list`로 전원 계획 목록을 확인합니다. `config.json`의 `highPerformanceGuid`, `powerSaverGuid`가 실제로 있는지 확인하세요.
4. 해당 계획이 없으면 다음 명령으로 **복제 후 출력된 새 GUID를** `config.json`에 입력합니다.

```powershell
powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
powercfg /duplicatescheme a1841308-3541-4fab-bc81-f71556f20b4a
```

일부 PC에서는 해당 계획을 사용할 수 없을 수 있습니다.

5. `config.json`에서 `"dryRun": true`를 유지하고 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\GamePowerAuto.ps1
```

6. 게임 실행 및 종료 후 콘솔과 `gamepower.log`에서 `GAME`, `SAVE`, `DRY RUN` 표시를 확인합니다. `Ctrl+C`로 종료합니다.
7. 오탐이 없는지 확인한 뒤 `config.json`을 `"dryRun": false`로 변경하고 다시 테스트합니다. 이때는 **실제로 전원 계획이 변경됩니다.**

## 2. 추가/제외 목록 수정 (세로로 한 줄에 하나씩)

**게임 추가**는 `include.json`, **게임 제외**는 `exclude.json`에서 수정합니다.

```json
{
  "processNames": [
    "Overwatch.exe",
    "cs2.exe",
    "MyGame.exe"
  ],
  "paths": [
    "D:\\MyGames\\*"
  ]
}
```

`processNames`는 실행 파일명, `paths`는 전체 실행 경로에 대한 와일드카드 패턴입니다. 파일은 JSON 형식이므로 **마지막 줄 뒤에는 쉼표를 넣지 않고**, 각 항목 사이에만 쉼표를 둡니다. 전체 경로에서 백슬래시(`\`)는 JSON에 `\\`로 적어야 합니다. 대소문자는 구분하지 않고 `*`, `?` 와일드카드가 가능합니다.

```json
{
  "processNames": [
    "wallpaper64.exe",
    "webwallpaper64.exe",
    "winrtutil64.exe"
  ],
  "paths": [
    "*\\steamapps\\common\\Steamworks Shared\\*"
  ]
}
```

**제외 목록이 추가 목록보다 우선**합니다. 예를 들어 `javaw.exe`가 제외 목록에 있으면 직접 추가하더라도 감지되지 않습니다. 위는 형식 예시이며 실제 초기 목록은 JSON 파일에 들어 있습니다.

두 목록은 **매 검사 주기마다 자동 다시 읽기** 때문에 파일을 저장하면 실행 중인 프로그램에도 반영됩니다. 잘못된 JSON은 로그에 `ERROR`가 남고, 파일을 고치면 다음 검사에서 복구됩니다.

## 3. Windows 로그인 시 완전 자동 시작

관리자 권한 PowerShell에서 다음을 실행합니다.

```powershell
cd C:\GamePowerAuto
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
Start-ScheduledTask -TaskName GamePowerAuto
```

기존 수동 실행 창은 `Ctrl+C`로 종료한 뒤 작업을 시작하세요. 로그인 이후 자동 실행됩니다. 로그인 **전** 부팅 단계에서 실행되는 서비스는 아닙니다.

상태와 로그 확인:

```powershell
Get-ScheduledTask -TaskName GamePowerAuto | Select-Object TaskName, State
Get-Content C:\GamePowerAuto\gamepower.log -Tail 30 -Wait
powercfg /getactivescheme
```

## 4. 제거 및 복원

관리자 권한 PowerShell에서:

```powershell
cd C:\GamePowerAuto
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\GamePowerAuto.ps1 -Restore
```

`-Restore`는 최초 실행 때 저장한 `state.json`의 전원 계획으로 복귀합니다(`dryRun`이 `false`일 때 적용).

## 5. 자주 발생하는 문제

- `GAME : wallpaper64.exe`가 나옴: `exclude.json`에 Wallpaper Engine 관련 실행 파일 이름을 추가하세요(이번 버전은 기본 포함).
- 게임이 인식되지 않음: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\GamePowerAuto.ps1 -ShowCandidates`로 프로세스명을 보고 `include.json`에 추가하세요.
- 게임 종료 뒤 즉시 절전으로 돌아가지 않음: `config.json`의 `gameExitGraceSeconds` 기본값 45초가 경과해야 합니다.
- 실제 전원 변경이 안 됨: `dryRun` 여부, 관리자 권한, `powercfg /list`의 GUID를 확인하세요.
- 로그인 자동 실행 설정 후 변경할 때: 실행 중인 작업을 중지하고 스크립트를 교체하세요. JSON 규칙 파일은 실행 중 수정할 수 있습니다.

**주의:** 절전 전원 계획은 실행 중인 PC를 잠재우는 절전(Sleep)과 다릅니다. 이 도구는 CPU/GPU 클럭을 직접 설정하지 않으며, 절전 효과는 하드웨어와 사용 상태에 따라 달라집니다.

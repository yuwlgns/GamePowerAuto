# GamePowerAuto 실시간 EXE 관리 화면

`GamePowerManager.ps1`은 **기존 GamePowerAuto.ps1을 교체하지 않는** 별도 GUI 관리 도구입니다. Windows PowerShell 5.1 / Windows 10·11 전용입니다.

## 설치

1. `GamePowerManager.ps1`, `Launch-Manager.cmd`를 **기존 `GamePowerAuto.ps1`과 같은 폴더** (`C:\GamePowerAuto`)로 복사합니다.
2. `Launch-Manager.cmd`를 더블클릭하면 실시간 관리 화면이 표시됩니다. 관리자 권한이 필요한 환경에서는 우클릭 후 관리자 권한으로 실행하거나 관리자 PowerShell에서 아래처럼 실행합니다.

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File C:\GamePowerAuto\GamePowerManager.ps1
```

## 화면

- **GAME (초록색)**: 실행 파일이 게임으로 감지됨. 감지 근거(`include: process`, `include: path`, `Steam library`, `Epic installation`) 표시
- **EXCLUDE (주황색)**: 제외 목록에 일치해 게임으로 감지하지 않음
- **OTHER (기본색)**: 현재 규칙상 게임으로 감지하지 않음
- PID, EXE, 실행 경로를 확인 가능. **5초마다 자동 갱신**
- 필터로 게임·제외·기타 프로그램만 확인 가능
- 프로세스 선택 후 **Add to include** 또는 **Add to exclude**로 해당 EXE 이름을 JSON에 추가 (확인 창 제공)
- **Restart monitor**: 예약 작업 `GamePowerAuto`를 중지 후 다시 시작. **Windows PC 자체를 재부팅하지 않습니다.**
- **Open log**: 기존 `gamepower.log`를 메모장으로 열기

## 주의 사항

- 이 화면은 제공된 **GamePowerAuto v2 감지 규칙을 동일하게 구현하여 별도로 재평가**합니다. Windows 프로세스 조회 시점/권한 차이가 있을 수 있으며, 본래 감시 프로세스의 내부 상태나 유예 시간까지 직접 읽는 것은 아닙니다. 실제 전원 계획 전환 여부는 `gamepower.log` 및 `powercfg /getactivescheme`를 확인하세요.
- Windows 권한 때문에 실행 경로를 읽을 수 없는 일부 프로세스는 표에 표시되지 않습니다.
- `include.json` 및 `exclude.json`은 원래 감시 루프에서 다음 주기마다 읽으므로 일반적으로 **모니터 재시작 없이** 반영됩니다. `config.json` 또는 PowerShell 코드 변경 후에는 Restart monitor를 사용하세요.
- 동일한 EXE 파일명이 다른 일반 프로그램에도 사용될 수 있습니다. 이때는 `processNames`에 추가하지 말고 **`paths`로 범위를 좁히는 것이 안전**합니다.
- 제외 규칙이 추가 규칙보다 우선합니다. JSON을 잘못 편집했거나 권한 문제가 있으면 감지가 실패할 수 있습니다.
- `Restart monitor`는 등록된 작업이 없거나 권한이 부족한 경우 실패하며 알림이 표시됩니다. **관리자 권한으로 실행**하거나 작업 스케줄러 등록을 먼저 확인하세요.
- GUI 종료는 게임 감시 작업을 종료하지 않습니다.

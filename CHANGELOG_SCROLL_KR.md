# GamePowerAuto Manager — 스크롤 유지 패치

실시간 목록이 5초마다 갱신될 때 스크롤이 맨 위로 이동하는 문제를 수정했습니다.

- 이전 화면의 맨 위에 보이던 프로세스(PID)를 기준으로 스크롤 위치 복원
- 해당 프로세스가 종료된 경우 기존 행 위치에 최대한 가깝게 복원
- 현재 선택한 EXE도 동일 PID가 존재하면 선택 상태 유지
- 가로 스크롤 위치 유지
- 기존 5초 자동 갱신 및 게임 추가/제외 기능 유지

## 적용

1. 열려 있는 GamePowerAuto Manager 창을 닫습니다. **전원 감시 작업을 중지할 필요는 없습니다.**
2. `GamePowerManager.ps1`을 `C:\GamePowerAuto`에 덮어씁니다.
3. 기존 `Launch-Manager.cmd`를 더블클릭하여 관리자를 다시 엽니다.

기존 `include.json`, `exclude.json`, `config.json`은 변경하지 않습니다.

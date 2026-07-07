# Jansori Tomato 🍅👀

[English](README.md) · **한국어**

한 끗 다른 macOS 메뉴바 뽀모도로 타이머. 집중 시간에는 귀여운 눈 한 쌍(👀)이 메뉴바에서 쑥 튀어나와 "딴짓하지 말라"고 **잔소리**하고, 휴식 시간에는 잔잔한 전체화면이 작업을 멈춰 줍니다. 준비되면 다시 집중하도록 부드럽게 불러옵니다.

> 상태: 초기 릴리즈 (v0.1.0). 전체 기획은 [PRD.md](PRD.md) 참고.

## 기능

- **메뉴바 타이머** — 집중 / 짧은 휴식 / 긴 휴식, 남은 시간 메뉴바 표시.
- **감시하는 눈 👀** — 집중 중 눈알 캐릭터가 **무작위 간격**으로 메뉴바에서 아래로 튀어나와 커서를 좇고, 번갈아 바뀌는 문구로 잔소리합니다("집중하고 있나요? 👀"). 클릭 통과, 방해 없음.
- **전체화면 휴식 (Flow 앱 방식)** — 집중이 끝나면 프로스트 블러 휴식 화면이 떠서 진짜로 쉬게 합니다. 언제든 닫을 수 있고, 휴식이 끝나면 "집중 다시 시작" 프롬프트가 알아서 팝업됩니다.
- **네이티브 알림** — 세션 전환 시 알림, 완료 사운드(옵션).
- **한/영 지원** — 앱 안에서 즉시 전환.
- **로그인 시 자동 시작**, Dock 아이콘 없이 메뉴바에만 상주.

## 요구 사항

- macOS 13 (Ventura) 이상
- Swift 툴체인 (Command Line Tools 또는 전체 Xcode)

## 설치

### 다운로드

[Releases](https://github.com/han-hyeonmin/jansori-tomato/releases)에서 최신 `JansoriTomato-x.y.z.zip`을 받아 압축을 풀고 **Jansori Tomato.app**을 `/Applications`로 옮깁니다.

> 현재 **미서명** 앱이라 처음 열 때 Gatekeeper 경고가 뜹니다. 앱을 **우클릭 → 열기 → 열기** 하면 됩니다(최초 1회).

### Homebrew (지원 예정)

```bash
# 준비 중 — 개인 tap 경유
brew install --cask han-hyeonmin/tap/jansori-tomato
```

배포 계획은 [docs/HOMEBREW.md](docs/HOMEBREW.md) 참고.

### 소스에서 빌드

Swift Package라 전체 Xcode 없이 Command Line Tools만으로 빌드됩니다.

```bash
swift run                       # 개발 중 바로 실행

Scripts/make-icon.sh            # 앱 아이콘 생성 (최초 1회)
Scripts/bundle-app.sh release   # → build/Jansori Tomato.app
open "build/Jansori Tomato.app"
```

Xcode가 있다면 `open Package.swift` 로 열어 그대로 개발할 수 있습니다.

## 프로젝트 구조

```
Sources/PomodoroTimer/
  PomodoroTimerApp.swift        # @main, MenuBarExtra 진입점
  TimerEngine.swift             # 타이머 상태 머신 (ObservableObject)
  Models/                       # SessionType, PomodoroSettings
  Views/ControlPanelView.swift  # 메뉴바 팝오버
  CheckIn/                      # 감시하는 눈 캐릭터 (peek·커서 추적·말풍선)
  Break/                        # 전체화면 휴식 오버레이 (Flow 방식)
  Support/                      # 알림, 로그인 시 자동 시작, 다국어
Scripts/
  bundle-app.sh                 # 실행 파일 → .app 번들
  package-release.sh            # 릴리즈용 빌드 + zip + sha256
  IconGenerator.swift + make-icon.sh   # 코드로 그린 H-토마토 앱 아이콘
```

개발 팁: `CHECKIN_PREVIEW=1 swift run` → 캐릭터 즉시 등장, `BREAK_PREVIEW=1 swift run` → 휴식→재개 오버레이 표시.

## 로드맵

- [x] 타이머 코어 + 메뉴바 UI
- [x] 감시하는 눈 체크인 캐릭터 (메뉴바 peek, 커서 추적, 말풍선, 무작위 타이밍)
- [x] 전체화면 휴식 오버레이 (자동 시작 + 재개 프롬프트)
- [x] 네이티브 알림 + 사운드, 로그인 시 자동 시작, 다국어, 앱 아이콘
- [x] GitHub 릴리즈 (v0.1.0)
- [ ] Homebrew cask
- [ ] 코드 서명 / 공증

## 라이선스

MIT

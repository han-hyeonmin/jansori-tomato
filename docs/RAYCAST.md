# Raycast Store 배포 알아보기

## 결론 먼저

**Raycast Store에는 이 앱(.app)을 그대로 올릴 수 없다.** Raycast Store가 배포하는 건 macOS 앱이 아니라 **Raycast 익스텐션**(Raycast API 기반 TypeScript/React 프로젝트)이다. 즉 "우리 SwiftUI 메뉴바 앱"과 "Raycast 익스텐션"은 서로 다른 산출물이다.

Raycast에 존재감을 만들려면 **별도의 동반 익스텐션**을 만들어야 한다. 두 갈래가 있다.

---

## 옵션 A — 얇은 동반 익스텐션 (권장)

우리 앱은 그대로 두고, Raycast에서 타이머를 조작하는 명령만 익스텐션으로 제공한다.
"Start Focus / Pause / Skip / Reset" 같은 커맨드를 Raycast에서 실행하면 우리 앱을 제어한다.

- **연결 방법**: 앱에 **URL scheme**(예: `pomodoro://start`)을 등록하고, 익스텐션은 `open("pomodoro://start")` 로 호출.
  - 앱 쪽: `Info.plist` 에 `CFBundleURLTypes` 추가 + `onOpenURL` 처리.
  - 익스텐션 쪽: `@raycast/api` 의 `open` 또는 `exec`.
- 장점: 구현이 가볍고, 앱과 상태가 자연스럽게 연동.
- 단점: 사용자가 우리 앱을 이미 설치해야 함(익스텐션 단독으로는 동작 X).

## 옵션 B — 순수 Raycast 익스텐션으로 재구현

타이머 로직을 익스텐션 안에서 자체 구현(메뉴바 커맨드 `MenuBarExtra` 타입 지원). 우리 앱 없이도 동작.
- 장점: Raycast만 있으면 됨.
- 단점: 감시 캐릭터·전체화면 휴식 오버레이 같은 우리 핵심 경험을 Raycast 제약 안에서 재현하기 어렵다. 사실상 별도 제품.

→ 우리의 차별점(캐릭터·오버레이)을 살리려면 **옵션 A**가 맞다.

---

## 익스텐션 배포 절차 (공통)

Raycast 익스텐션은 `raycast/extensions` 모노레포에 PR로 등재한다.

```bash
# 1. 개발 환경
npm install -g @raycast/api        # 또는 npx
# Raycast 앱에서 "Create Extension" 커맨드로 스캐폴딩

# 2. 개발/빌드
npm run dev                        # 로컬 테스트
npm run build

# 3. 제출
npm run publish                    # raycast/extensions 에 PR 생성
```

- 리뷰 가이드라인: 아이콘·메타데이터·스크린샷·카테고리 필요.
- 참고: https://developers.raycast.com/basics/publish-an-extension

---

## 지금 할 일 (나중 단계)

Raycast는 **v1 이후 과제**. 우선순위는 GitHub 공개 → Homebrew. Raycast는 앱이 자리 잡은 뒤,
옵션 A(URL scheme + 얇은 익스텐션)로 추가하는 걸 권장.

> 앱에 URL scheme을 미리 넣어두면 나중에 Raycast·Shortcuts·Alfred 연동이 모두 쉬워진다. v1.x에서 `pomodoro://` scheme 도입을 고려.

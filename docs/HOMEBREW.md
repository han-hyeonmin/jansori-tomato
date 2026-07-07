# Homebrew 배포 가이드

macOS 메뉴바 앱을 `brew install --cask` 로 설치할 수 있게 하는 방법. 큰 그림은 **2단계**다.

1. **개인 tap** — 내 GitHub에 tap 저장소를 만들어 즉시 배포 (심사 없음)
2. **공식 `homebrew/cask`** — 사용자·스타가 쌓이면 본진에 제출 (notability 요건 있음)

앱 이름이 확정되면 아래 `jansori-tomato` / 앱 토큰을 실제 이름으로 바꾼다.

---

## 0. 사전 준비

Cask는 "이미 빌드된 `.app`을 받아서 설치"하는 방식이라, 배포 가능한 아티팩트가 먼저 필요하다.

1. **릴리즈 아티팩트**: `.app`을 `.zip`(또는 `.dmg`)으로 묶어 **GitHub Releases**에 올린다.
   ```bash
   Scripts/make-icon.sh
   Scripts/bundle-app.sh release
   ditto -c -k --keepParent "build/Jansori Tomato.app" "JansoriTomato-0.1.0.zip"
   shasum -a 256 JansoriTomato-0.1.0.zip   # cask에 넣을 sha256
   ```
2. **버전 태그**: `git tag v0.1.0 && git push --tags` → 그 태그로 Release 생성, zip 첨부.

### ⚠️ 코드 서명 / 공증 (중요)

- **미서명 앱**도 cask로 배포 가능하지만, 사용자가 처음 열 때 Gatekeeper가 막는다("확인되지 않은 개발자").
  cask에 아래를 넣으면 다운로드 시 격리 속성을 떼어내 실행이 수월해진다.
  ```ruby
  # 미서명 배포 시 완화책 (권장되진 않음)
  # 사용자는 "우클릭 → 열기" 또는 시스템 설정 > 개인정보 보호에서 허용
  ```
- **정식 배포라면 서명·공증 권장**: Apple Developer Program($99/년) → Developer ID로 `codesign` + `notarytool` 공증 + `stapler`.
  공식 `homebrew/cask`는 서명/공증된 앱을 강하게 선호한다.
- 이건 프로젝트 **Open Question** — 초기엔 미서명 + 개인 tap으로 시작하고, 사용자가 늘면 서명 도입.

---

## 1. 개인 tap 만들기 (지금 당장 가능)

1. GitHub에 저장소 생성: 이름은 반드시 **`homebrew-tap`** (또는 `homebrew-<원하는이름>`).
2. `Casks/jansori-tomato.rb` 추가:

   ```ruby
   cask "jansori-tomato" do
     version "0.1.0"
     sha256 "여기에_shasum_값"

     url "https://github.com/han-hyeonmin/jansori-tomato/releases/download/v#{version}/JansoriTomato-#{version}.zip"
     name "Jansori Tomato"
     desc "Menu bar Pomodoro timer with a watching eyeball character"
     homepage "https://github.com/han-hyeonmin/jansori-tomato"

     app "Jansori Tomato.app"

     zap trash: [
       "~/Library/Preferences/com.hanhyeonmin.jansoritomato.plist",
     ]
   end
   ```

3. 사용자는 이렇게 설치한다:
   ```bash
   brew install --cask han-hyeonmin/tap/jansori-tomato
   # 또는
   brew tap han-hyeonmin/tap && brew install --cask jansori-tomato
   ```

> `zap` 은 `brew uninstall --zap` 시 함께 지울 설정 파일. 번들 ID(`com.hanhyeonmin.jansoritomato`)가 확정되면 맞춰 수정.

---

## 2. 릴리즈 자동화 (GitHub Actions)

태그를 밀면 빌드→zip→Release까지 자동화. `.github/workflows/release.yml` 예시 골격:

```yaml
name: Release
on:
  push:
    tags: ["v*"]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: Scripts/make-icon.sh
      - run: Scripts/bundle-app.sh release
      - run: ditto -c -k --keepParent "build/Jansori Tomato.app" "JansoriTomato-${GITHUB_REF_NAME#v}.zip"
      - uses: softprops/action-gh-release@v2
        with:
          files: JansoriTomato-*.zip
```

이후 cask의 `version`/`sha256`만 갱신하면 된다. `livecheck` 스탠자를 넣으면 `brew` 가 새 버전을 자동 감지한다:

```ruby
livecheck do
  url :url
  strategy :github_latest
end
```

---

## 3. 공식 homebrew/cask 제출 (나중)

사용자·스타가 쌓인 뒤 본진(`homebrew/homebrew-cask`)에 올리는 단계.

- **Notability 요건**: 저장소가 대략 **스타 75+ / 포크 30+ / 워처 30+** 중 하나를 충족해야 심사 대상. → 1단계 개인 tap으로 먼저 사용자 기반을 만든다.
- 제출 전 로컬 검증:
  ```bash
  brew audit --new --cask jansori-tomato
  brew style jansori-tomato
  brew install --cask ./Casks/jansori-tomato.rb   # 실제 설치 테스트
  ```
- 통과하면 `homebrew/homebrew-cask` 에 PR. 리뷰어가 이름·중복·라이선스·서명 여부를 확인한다.

---

## 참고

- Homebrew Cask 문서: https://docs.brew.sh/Cask-Cookbook
- Acceptable Casks(등재 기준): https://docs.brew.sh/Acceptable-Casks
- Adding a Software Package: https://docs.brew.sh/Adding-Software-to-Homebrew

> 요건은 바뀔 수 있으니 제출 직전 위 문서로 최신 기준을 재확인할 것.

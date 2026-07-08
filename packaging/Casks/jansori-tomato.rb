# Homebrew Cask 템플릿.
# 개인 tap 저장소(homebrew-tap)의 Casks/ 아래에 두면 아래로 설치된다:
#   brew install --cask han-hyeonmin/tap/jansori-tomato
#
# 릴리즈할 때마다 version / sha256 을 갱신한다:
#   Scripts/package-release.sh   # sha256 출력

cask "jansori-tomato" do
  version "0.1.1"
  sha256 "3d04b2a30784fef50bec4d97c7ac617895e06e122db143270828b85de30626c6"

  url "https://github.com/han-hyeonmin/jansori-tomato/releases/download/v#{version}/JansoriTomato-#{version}.zip"
  name "Jansori Tomato"
  desc "Menu bar Pomodoro timer with watching eyes that nag you to focus"
  homepage "https://github.com/han-hyeonmin/jansori-tomato"

  # 새 버전 자동 감지(GitHub 최신 릴리즈 기준).
  livecheck do
    url :url
    strategy :github_latest
  end

  app "Jansori Tomato.app"

  zap trash: [
    "~/Library/Preferences/com.hanhyeonmin.jansoritomato.plist",
  ]
end

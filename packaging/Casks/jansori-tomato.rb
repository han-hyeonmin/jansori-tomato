# Reference copy of the cask. The live cask lives in the tap:
#   https://github.com/han-hyeonmin/homebrew-tap
# Bump version/sha256 on each release (Scripts/package-release.sh prints the sha256).

cask "jansori-tomato" do
  version "0.1.1"
  sha256 "3d04b2a30784fef50bec4d97c7ac617895e06e122db143270828b85de30626c6"

  url "https://github.com/han-hyeonmin/jansori-tomato/releases/download/v#{version}/JansoriTomato-#{version}.zip"
  name "Jansori Tomato"
  desc "Menu bar Pomodoro timer with watching eyes that nag you to focus"
  homepage "https://github.com/han-hyeonmin/jansori-tomato"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Jansori Tomato.app"

  zap trash: [
    "~/Library/Preferences/com.hanhyeonmin.jansoritomato.plist",
  ]
end

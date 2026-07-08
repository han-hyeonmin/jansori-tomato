# Reference copy of the cask. The live cask lives in the tap:
#   https://github.com/han-hyeonmin/homebrew-tap
# Bump version/sha256 on each release (Scripts/package-release.sh prints the sha256).

cask "jansori-tomato" do
  version "0.1.2"
  sha256 "588b464a4440d690d607accef71356a3ac3da3ae51fd52b2d4dd696fad5f602f"

  url "https://github.com/han-hyeonmin/jansori-tomato/releases/download/v#{version}/JansoriTomato-#{version}.zip"
  name "Jansori Tomato"
  desc "Menu bar Pomodoro timer with watching eyes that nag you to focus"
  homepage "https://github.com/han-hyeonmin/jansori-tomato"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Jansori Tomato.app"

  # The app is ad-hoc signed but not notarized yet, so macOS quarantines it.
  # Clear the flag on install so it opens without the Gatekeeper "damaged" error.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Jansori Tomato.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.hanhyeonmin.jansoritomato.plist",
  ]
end

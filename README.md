# Jansori Tomato 🍅👀

**English** · [한국어](README.ko.md)

A macOS menu bar Pomodoro timer with an attitude. During a focus session, a pair of eyes peeks out of your menu bar, follows your cursor, and *nags* you to stay on task — *jansori* (잔소리) is Korean for nagging. When the timer's up, a calm full-screen break takes over, then nudges you back when you're ready.

<p align="center">
  <img src="assets/peek-en.gif" width="500" alt="Watching eyes peeking out of the menu bar and following the cursor">
</p>

> Status: early release (v0.1.8).

## Features

- **Menu bar timer** — focus / short break / long break, live countdown in the menu bar.
- **Watching eyes 👀** — during focus, a pair of eyes drops out of the menu bar at random intervals, tracks your cursor, and drops a rotating one-liner ("No goofing off~ 👀"). Click-through, so it never gets in your way.
- **Full-screen breaks (Flow-style)** — when focus ends, a frosted break screen takes over so you actually rest. Close it anytime; when the break ends, a "resume focus" prompt pops up on its own. Prefer to stay in flow? Switch to a **sound-only break** in Settings.
- **Native notifications** on session changes, with an optional completion sound and an adjustable volume (drag the slider to preview). Stale notifications clear themselves as sessions advance.
- **Auto-pause on sleep / screen lock** — the timer pauses when your Mac sleeps or the screen locks, and resumes when you're back.
- **Bilingual** — English / Korean, switchable in-app.
- **Launch at login**, no Dock icon (menu bar only).

## Screenshots

The countdown lives in your menu bar:

<img src="assets/menubar.png" width="110" alt="Menu bar countdown">

Click it for the full control panel — with a full-screen break when the session ends:

<img src="assets/panel-en.png" width="280" alt="Menu bar control panel">

<img src="assets/break-en.png" width="680" alt="Full-screen break screen">

## Install

Requires **macOS 13 (Ventura) or later**.

### Homebrew (recommended)

```bash
brew install --cask han-hyeonmin/tap/jansori-tomato
```

The tap clears macOS's quarantine flag on install, so the app just opens. Update later with `brew upgrade --cask jansori-tomato` — the app also shows a banner when a new version is out.

### Manual download

Download the latest `JansoriTomato-x.y.z.zip` from [Releases](https://github.com/han-hyeonmin/jansori-tomato/releases), unzip, and drag **Jansori Tomato.app** to `/Applications`.

> The app is ad-hoc signed but **not notarized** yet. If macOS says it's **"damaged"** or won't open, clear the quarantine flag once:
> ```bash
> xattr -dr com.apple.quarantine "/Applications/Jansori Tomato.app"
> ```

### Build from source

The project is a Swift Package, so it builds with just Command Line Tools — no full Xcode required.

```bash
swift run                       # run directly during development

Scripts/make-icon.sh            # generate the app icon (once)
Scripts/bundle-app.sh release   # → build/Jansori Tomato.app
open "build/Jansori Tomato.app"
```

Have Xcode installed? Just `open Package.swift` to develop in Xcode.

## Project layout

```
Sources/PomodoroTimer/
  PomodoroTimerApp.swift        # @main, MenuBarExtra entry point
  TimerEngine.swift             # timer state machine (ObservableObject)
  Models/                       # SessionType, PomodoroSettings
  Views/ControlPanelView.swift  # menu bar popover
  CheckIn/                      # watching-eyes character (peek, gaze, speech bubble)
  Break/                        # full-screen break overlay (Flow-style)
  Support/                      # notifications, launch-at-login, localization
Scripts/
  bundle-app.sh                 # executable → .app bundle
  package-release.sh            # build + zip + sha256 for a release
  IconGenerator.swift + make-icon.sh   # code-drawn H-tomato app icon
```

Dev tips: `CHECKIN_PREVIEW=1 swift run` shows the character immediately; `BREAK_PREVIEW=1 swift run` shows the break → resume overlay.

## Roadmap

- [x] Timer core + menu bar UI
- [x] Watching-eyes check-in character (menu bar peek, cursor tracking, speech bubble, randomized timing)
- [x] Full-screen break overlay (auto-start + resume prompt)
- [x] Native notifications + completion sound, launch at login, bilingual, app icon
- [x] Keypad time entry, reset-to-defaults, in-app update check
- [x] GitHub release + Homebrew tap with ad-hoc signed builds (v0.1.8)
- [ ] Submit to `homebrew/cask`
- [ ] Code signing / notarization (Developer ID)

## License

MIT

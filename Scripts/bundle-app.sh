#!/usr/bin/env bash
#
# swift build 결과 실행 파일을 macOS .app 번들로 조립한다.
# 사용법: Scripts/bundle-app.sh [debug|release]   (기본값: release)
#
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="Jansori Tomato"
EXECUTABLE="PomodoroTimer"

# 스크립트 위치와 무관하게 프로젝트 루트에서 동작.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "▶︎ swift build (-c $CONFIG)"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="build/${APP_NAME}.app"

echo "▶︎ 번들 조립: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"
cp Info.plist "$APP_DIR/Contents/Info.plist"

# 앱 아이콘(있으면). 없으면 Scripts/make-icon.sh 로 먼저 생성.
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "⚠︎ AppIcon.icns 없음 — Scripts/make-icon.sh 로 생성하세요."
fi

# 번들 전체를 ad-hoc 서명한다. (안 하면 링커 서명이 번들 리소스와 어긋나
# 격리 상태에서 "손상됨"으로 뜬다. Developer ID/공증은 아직 없음.)
echo "▶︎ ad-hoc 코드 서명"
codesign --force --deep --sign - "$APP_DIR"

echo "✓ 완료: $ROOT_DIR/$APP_DIR"
echo "  실행: open \"$APP_DIR\""

#!/usr/bin/env bash
#
# 릴리즈용 .app을 빌드해 zip으로 묶고 sha256을 출력한다. (Homebrew cask에 넣을 값)
# 사용법: Scripts/package-release.sh [버전]   (기본값: Info.plist의 버전)
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Jansori Tomato"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)}"

echo "▶︎ 아이콘 + 릴리즈 번들"
Scripts/make-icon.sh >/dev/null
Scripts/bundle-app.sh release >/dev/null

ZIP="build/JansoriTomato-${VERSION}.zip"
rm -f "$ZIP"
echo "▶︎ zip 압축"
ditto -c -k --keepParent "build/${APP_NAME}.app" "$ZIP"

echo ""
echo "✓ 아티팩트: $ROOT_DIR/$ZIP"
echo "  version : $VERSION"
echo -n "  sha256  : "
shasum -a 256 "$ZIP" | awk '{print $1}'
echo ""
echo "→ 이 값들을 packaging/Casks/jansori-tomato.rb 의 version/sha256 에 넣으세요."

#!/usr/bin/env bash
#
# H 모티브 토마토 앱 아이콘을 그려 AppIcon.icns 를 만든다.
# 사용법: Scripts/make-icon.sh
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "▶︎ 아이콘 렌더링"
swift Scripts/IconGenerator.swift "$ICONSET"

echo "▶︎ icns 생성"
iconutil -c icns "$ICONSET" -o AppIcon.icns

echo "✓ 완료: $ROOT_DIR/AppIcon.icns"

#!/usr/bin/env bash
set -euo pipefail

# Local deploy: Release 빌드 → /Applications/cmux-dev.app 배포 → 스킬 동기화 → 재실행
# 프로덕션 cmux.app과 공존 가능 (별도 번들 ID + 소켓)
# Usage: ./scripts/deploy-local.sh [--no-launch] [--no-zig] [--no-skills]

LAUNCH=1
SKIP_ZIG=0
SKIP_SKILLS=0
INSTALL_DIR="/Applications"
BUILD_APP_NAME="cmux"               # xcodebuild 결과물 이름
DEPLOY_APP_NAME="cmux-dev"          # /Applications에 설치되는 이름
BUNDLE_ID="com.cmuxterm.app.dev"
DERIVED_DATA="build-local"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-launch)  LAUNCH=0; shift ;;
    --no-zig)     SKIP_ZIG=1; shift ;;
    --no-skills)  SKIP_SKILLS=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/deploy-local.sh [options]

Release 빌드 후 /Applications/cmux-dev.app 에 배포합니다.
프로덕션 cmux.app과 별도로 공존합니다.

Options:
  --no-launch   빌드+설치만 하고 앱을 실행하지 않음
  --no-zig      GhosttyKit/cmuxd/ghostty helper zig 빌드 스킵
  --no-skills   스킬/커맨드 동기화 스킵
  -h, --help    도움말
EOF
      exit 0
      ;;
    *) echo "error: unknown option $1" >&2; exit 1 ;;
  esac
done

echo "=== cmux local deploy ==="

# --- GhosttyKit ---
if [[ "$SKIP_ZIG" -eq 0 ]]; then
  if [[ ! -d "GhosttyKit.xcframework" ]]; then
    echo "[1/6] Building GhosttyKit..."
    (cd ghostty && zig build -Demit-xcframework=true -Demit-macos-app=false -Dxcframework-target=universal -Doptimize=ReleaseFast)
    rm -rf GhosttyKit.xcframework
    cp -R ghostty/macos/GhosttyKit.xcframework GhosttyKit.xcframework
  else
    echo "[1/6] GhosttyKit.xcframework exists, skipping"
  fi
else
  echo "[1/6] Zig build skipped (--no-zig)"
fi

# --- Xcode Release build ---
echo "[2/6] Building Release..."
XCODE_LOG="/tmp/cmux-deploy-local.log"
set +e
xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build 2>&1 | tee "$XCODE_LOG" | grep -E '(warning:|error:|fatal:|BUILD FAILED|BUILD SUCCEEDED|\*\* BUILD)'
XCODE_EXIT="${PIPESTATUS[0]}"
set -e
if [[ "$XCODE_EXIT" -ne 0 ]]; then
  echo "error: xcodebuild failed (log: $XCODE_LOG)" >&2
  exit "$XCODE_EXIT"
fi

BUILD_APP_PATH="${DERIVED_DATA}/Build/Products/Release/${BUILD_APP_NAME}.app"
if [[ ! -d "$BUILD_APP_PATH" ]]; then
  echo "error: ${BUILD_APP_NAME}.app not found at $BUILD_APP_PATH" >&2
  exit 1
fi

# --- cmuxd + ghostty helper ---
if [[ "$SKIP_ZIG" -eq 0 ]]; then
  echo "[3/6] Building cmuxd & ghostty helper..."
  if [[ -d "cmuxd" ]]; then
    (cd cmuxd && zig build -Doptimize=ReleaseFast)
  fi
  if [[ -d "ghostty" ]]; then
    (cd ghostty && zig build cli-helper -Dapp-runtime=none -Demit-macos-app=false -Demit-xcframework=false -Doptimize=ReleaseFast)
  fi
  BIN_DIR="$BUILD_APP_PATH/Contents/Resources/bin"
  mkdir -p "$BIN_DIR"
  [[ -x "cmuxd/zig-out/bin/cmuxd" ]] && cp cmuxd/zig-out/bin/cmuxd "$BIN_DIR/cmuxd"
  [[ -x "ghostty/zig-out/bin/ghostty" ]] && cp ghostty/zig-out/bin/ghostty "$BIN_DIR/ghostty"
else
  echo "[3/6] Zig helper build skipped (--no-zig)"
fi

# --- 기존 cmux-dev 종료 ---
DEPLOY_PATH="${INSTALL_DIR}/${DEPLOY_APP_NAME}.app"
echo "[4/6] Installing to ${DEPLOY_PATH} ..."
if pkill -f "${DEPLOY_APP_NAME}.app/Contents/MacOS/" 2>/dev/null; then
  echo "  Killed running ${DEPLOY_APP_NAME}"
  sleep 0.5
fi

# --- /Applications에 복사 + Info.plist 패치 ---
rm -rf "$DEPLOY_PATH"
cp -R "$BUILD_APP_PATH" "$DEPLOY_PATH"

INFO_PLIST="$DEPLOY_PATH/Contents/Info.plist"
if [[ -f "$INFO_PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $DEPLOY_APP_NAME" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleName string $DEPLOY_APP_NAME" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DEPLOY_APP_NAME" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DEPLOY_APP_NAME" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFO_PLIST"
  /usr/bin/codesign --force --sign - --timestamp=none --generate-entitlement-der "$DEPLOY_PATH" >/dev/null 2>&1 || true
fi
echo "  Installed: ${DEPLOY_PATH}"

# --- 스킬/커맨드 동기화 ---
if [[ "$SKIP_SKILLS" -eq 0 ]]; then
  echo "[5/6] Syncing skills & commands..."
  "$SCRIPT_DIR/sync-skills.sh"
else
  echo "[5/6] Skills sync skipped (--no-skills)"
fi

# --- 실행 ---
if [[ "$LAUNCH" -eq 1 ]]; then
  echo "[6/6] Launching ${DEPLOY_APP_NAME}..."
  open -g "$DEPLOY_PATH"
  sleep 0.5
  if pgrep -f "${DEPLOY_APP_NAME}.app/Contents/MacOS/" >/dev/null 2>&1; then
    echo "  Running!"
  else
    echo "  warning: app may not have launched correctly" >&2
  fi
else
  echo "[6/6] Skipping launch (--no-launch)"
fi

# --- Cleanup ---
rm -rf "$DERIVED_DATA"

echo ""
echo "=== Deploy complete ==="
echo "  ${DEPLOY_PATH}"

#!/usr/bin/env bash
# ============================================================================
# Twsil Admin — permanent Firebase Hosting deployment pipeline
#
# Deploys the Flutter Web admin panel to https://twsil-db653.web.app
#
# The pipeline ALWAYS:
#   1. removes stale build output (flutter clean + build dir deletion)
#   2. fetches dependencies (flutter pub get)
#   3. builds the CURRENT source in release mode (flutter build web --release)
#      and stamps the build with version / commit / timestamp identifiers
#   4. clears the local Firebase upload cache that can make the CLI skip
#      uploading changed files
#   5. deploys ONLY the freshly generated admin/build/web directory to the
#      hosting target "admin" (site twsil-db653)
#
# Any failing command aborts the whole pipeline immediately.
#
# Usage:
#   ./deploy_firebase.sh [ADMIN_API_URL]
#   ./deploy_firebase.sh                          # default production API
#   ./deploy_firebase.sh https://api.twsil.ps/api  # custom API base
# ============================================================================
set -euo pipefail

APP_VERSION="V1.0.0"
ADMIN_API_URL="${1:-https://twsil-api.onrender.com/api}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN_DIR="$REPO_ROOT/admin"

echo "== 1/5 flutter clean (remove stale build artifacts) =="
cd "$ADMIN_DIR"
rm -rf build .dart_tool
flutter clean

echo "== 2/5 flutter pub get =="
flutter pub get

BUILD_STAMP="$(date -u +%Y-%m-%d_%H:%M)_$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
echo "== 3/5 flutter build web --release (version $APP_VERSION, stamp $BUILD_STAMP) =="
flutter build web --release \
  --dart-define=ADMIN_API_URL="$ADMIN_API_URL" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=BUILD_STAMP="$BUILD_STAMP"

if [ ! -f "$ADMIN_DIR/build/web/main.dart.js" ]; then
  echo "FATAL: expected output admin/build/web/main.dart.js was not produced." >&2
  exit 1
fi

echo "== 4/5 clearing stale Firebase upload cache =="
rm -rf "$REPO_ROOT/.firebase/hosting."*.cache

echo "== 5/5 firebase deploy --only hosting:admin (project twsil-db653) =="
cd "$REPO_ROOT"
firebase deploy --only hosting:admin --project twsil-db653

echo ""
echo "== تم النشر بنجاح ✅ =="
echo "الإصدار: $APP_VERSION | البناء: $BUILD_STAMP"
echo "اللوحة متاحة على: https://twsil-db653.web.app"

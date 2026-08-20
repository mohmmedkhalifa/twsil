#!/usr/bin/env bash
set -e

# Usage: ./deploy_firebase.sh <ADMIN_API_URL>
# Example: ./deploy_firebase.sh https://api.twsil.ps/api

if [ -z "$1" ]; then
  echo "Usage: $0 <ADMIN_API_URL>"
  echo "Example: $0 https://api.twsil.ps/api"
  exit 1
fi

ADMIN_API_URL="$1"

echo "== 1. بناء لوحة التحكم بـ API: $ADMIN_API_URL =="
cd "$(dirname "$0")"
flutter build web --release --dart-define=ADMIN_API_URL="$ADMIN_API_URL"

echo "== 2. الرفع إلى Firebase Hosting (موقع admin: twsil-db653) =="
cd ..
firebase deploy --only hosting:admin

echo "== تم النشر بنجاح =="
echo "اللوحة متاحة على: https://twsil-db653.web.app"
#!/usr/bin/env bash
# Build hai bản APK song song:
#   prod — trỏ API + Supabase test qua HTTPS (bản "thật")
#   dev  — trỏ API local (10.0.2.2:3000), chỉ gọi HTTP
#
# Dùng:
#   cp tool/env.prod.json.example tool/env.prod.json   # điền anon key
#   tool/build_both.sh
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f tool/env.prod.json ] || {
  echo "Thiếu tool/env.prod.json — copy từ env.prod.json.example rồi điền anon key" >&2
  exit 1
}

flutter build apk --flavor prod --release --dart-define-from-file=tool/env.prod.json
flutter build apk --flavor dev  --debug   --dart-define-from-file=tool/env.dev.json

echo
echo "Xong:"
echo "  build/app/outputs/flutter-apk/app-prod-release.apk"
echo "  build/app/outputs/flutter-apk/app-dev-debug.apk"

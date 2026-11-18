#!/usr/bin/env bash
# Build IPA chưa ký bằng xtool rồi kiểm tra cấu trúc IPA.
# Dùng (từ thư mục gốc project):  ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf

command -v xtool >/dev/null || { echo "Chưa có xtool trong PATH (xem Bước 1)"; exit 1; }

# Icon placeholder nếu chưa có
[ -f Resources/AppIcon.png ] || { mkdir -p Resources; python3 -I scripts/make_icon.py Resources/AppIcon.png; }

# -c release: build tối ưu; --ipa: đóng gói Payload/HelloWorld.app thành .ipa
# KHÔNG dùng --sign: IPA để trống chữ ký, KSign sẽ ký lúc cài.
xtool dev build --ipa -c release

IPA="xtool/${APP_NAME}.ipa"
[ -f "$IPA" ] || { echo "Không thấy $IPA"; exit 1; }
python3 -I scripts/ipa_info.py "$IPA"

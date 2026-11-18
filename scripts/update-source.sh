#!/usr/bin/env bash
# Cập nhật repo.json từ một IPA đã build (chạy offline, không đụng GitHub).
#  - đọc version/build/bundleID/minOS thật từ Info.plist trong IPA
#  - size = số byte của file IPA
#  - thêm entry mới LÊN ĐẦU "versions" (KSign lấy versions[0] làm bản mới nhất),
#    xoá entry trùng version cũ nếu có, giữ các bản cũ khác
#  - đồng bộ iconURL/website/downloadURL theo GH_REPO trong release.conf
#
# Dùng:  ./scripts/update-source.sh [đường-dẫn-ipa] ["ghi chú bản này"]
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf

IPA="${1:-xtool/${APP_NAME}.ipa}"
NOTES="${2:-Bản ${APP_NAME} mới.}"
[ -f "$IPA" ] || { echo "Không thấy IPA: $IPA"; exit 1; }

INFO=$(python3 -I scripts/ipa_info.py "$IPA")
BID=$(jq -r .bundleIdentifier <<<"$INFO")
VER=$(jq -r .version <<<"$INFO")
BUILD=$(jq -r .build <<<"$INFO")
MINOS=$(jq -r .minOSVersion <<<"$INFO")
SIZE=$(stat -c %s "$IPA")
TAG="v${VER}"
DATE="${RELEASE_DATE:-$(date -u +%Y-%m-%d)}"
RAW="https://raw.githubusercontent.com/${GH_REPO}/${BRANCH}"
URL="https://github.com/${GH_REPO}/releases/download/${TAG}/${IPA_ASSET_NAME}"

jq -e --arg bid "$BID" '.apps | any(.bundleIdentifier == $bid)' repo.json >/dev/null || {
  echo "Bundle ID trong IPA ($BID) không có trong repo.json — sửa xtool.yml hoặc repo.json cho khớp"; exit 1; }

TMP=$(mktemp)
jq --arg bid "$BID" --arg ver "$VER" --arg build "$BUILD" --arg date "$DATE" \
   --arg url "$URL" --argjson size "$SIZE" --arg minos "$MINOS" --arg notes "$NOTES" \
   --arg icon "${RAW}/Resources/AppIcon.png" --arg site "https://github.com/${GH_REPO}" '
  .iconURL = $icon | .website = $site
  | .apps |= map(
      if .bundleIdentifier == $bid then
        .iconURL = $icon
        | .versions = ([{
            version: $ver, buildVersion: $build, date: $date,
            localizedDescription: $notes, downloadURL: $url,
            size: $size, minOSVersion: $minos
          }] + ((.versions // []) | map(select(.version != $ver))))
      else . end)
' repo.json > "$TMP"
mv "$TMP" repo.json

echo "repo.json: $BID $VER (build $BUILD), size=$SIZE, minOS=$MINOS"
echo "downloadURL: $URL"

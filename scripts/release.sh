#!/usr/bin/env bash
# Phát hành IPA đã build lên GitHub Releases + cập nhật repo.json + push.
#   ./scripts/release.sh ["ghi chú bản này"]
# Yêu cầu: code đã commit, IPA ở xtool/<APP_NAME>.ipa (chạy build.sh trước).
# Token GitHub: dùng $GITHUB_TOKEN nếu có, không thì lấy từ git credential helper
# (token cần quyền "repo"). Không cần cài gh.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf
NOTES="${1:-Bản phát hành mới.}"
API="https://api.github.com/repos/${GH_REPO}"

[[ "$GH_REPO" != YOUR_GITHUB_USER/* ]] || { echo "Sửa GH_REPO trong release.conf trước"; exit 1; }
TOKEN="${GITHUB_TOKEN:-$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')}"
[ -n "$TOKEN" ] || { echo "Không có token GitHub: export GITHUB_TOKEN=... hoặc lưu credential git cho github.com"; exit 1; }
gh_api() { curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

IPA="xtool/${APP_NAME}.ipa"
[ -f "$IPA" ] || { echo "Không thấy $IPA — chạy ./scripts/build.sh trước"; exit 1; }
VER=$(python3 -I scripts/ipa_info.py "$IPA" | jq -r .version)
TAG="v${VER}"

# Code phải được commit + push để tag trỏ đúng commit đã build
[ -z "$(git status --porcelain -- . ':!repo.json')" ] || { echo "Còn thay đổi chưa commit:"; git status --short; exit 1; }
git push origin "HEAD:${BRANCH}"

CODE=$(gh_api -o /dev/null -w '%{http_code}' "$API/releases/tags/$TAG")
if [ "$CODE" = 200 ]; then
  echo "Release $TAG đã tồn tại. Tăng CFBundleShortVersionString trong Info.plist rồi build lại."
  exit 1
fi

mkdir -p dist
cp "$IPA" "dist/${IPA_ASSET_NAME}"
SIZE=$(stat -c %s "dist/${IPA_ASSET_NAME}")

echo "Tạo release $TAG ..."
REL=$(jq -n --arg tag "$TAG" --arg target "$BRANCH" --arg name "${APP_NAME} ${VER}" --arg body "$NOTES" \
      '{tag_name: $tag, target_commitish: $target, name: $name, body: $body}' \
      | gh_api -X POST "$API/releases" -d @-)
REL_ID=$(jq -r '.id // empty' <<<"$REL")
[ -n "$REL_ID" ] || { echo "Tạo release lỗi: $(jq -c '{message, errors}' <<<"$REL")"; exit 1; }

echo "Upload ${IPA_ASSET_NAME} ($SIZE bytes) ..."
ASSET=$(gh_api -X POST -H "Content-Type: application/octet-stream" --data-binary @"dist/${IPA_ASSET_NAME}" \
        "https://uploads.github.com/repos/${GH_REPO}/releases/${REL_ID}/assets?name=${IPA_ASSET_NAME}")
[ "$(jq -r '.size // 0' <<<"$ASSET")" = "$SIZE" ] || { echo "Upload lỗi: $(jq -c '{message, errors}' <<<"$ASSET")"; exit 1; }
echo "Release: $(jq -r .html_url <<<"$REL")"

./scripts/update-source.sh "dist/${IPA_ASSET_NAME}" "$NOTES"
./scripts/verify-source.sh

git add repo.json
git commit -m "source: ${APP_NAME} ${VER}"
git push origin "HEAD:${BRANCH}"

echo
echo "Kiểm tra online (raw.githubusercontent có thể cache ~5 phút):"
./scripts/verify-source.sh --online || true
echo
echo "URL source cho KSign: https://raw.githubusercontent.com/${GH_REPO}/${BRANCH}/repo.json"

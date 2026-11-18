#!/usr/bin/env bash
# Phát hành IPA đã build lên GitHub Releases + cập nhật repo.json + push.
#   ./scripts/release.sh ["ghi chú bản này"]
# Yêu cầu: gh đã login (gh auth login), code đã commit, IPA ở xtool/<APP_NAME>.ipa (chạy build.sh trước).
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf
NOTES="${1:-Bản phát hành mới.}"

command -v gh >/dev/null || { echo "Chưa cài gh (xem Bước 4)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Chưa đăng nhập: gh auth login"; exit 1; }
[[ "$GH_REPO" != YOUR_GITHUB_USER/* ]] || { echo "Sửa GH_REPO trong release.conf trước"; exit 1; }

IPA="xtool/${APP_NAME}.ipa"
[ -f "$IPA" ] || { echo "Không thấy $IPA — chạy ./scripts/build.sh trước"; exit 1; }
VER=$(python3 -I scripts/ipa_info.py "$IPA" | jq -r .version)
TAG="v${VER}"

# Code phải được commit + push để tag trỏ đúng commit đã build
[ -z "$(git status --porcelain -- . ':!repo.json')" ] || { echo "Còn thay đổi chưa commit:"; git status --short; exit 1; }
git push origin "HEAD:${BRANCH}"

if gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
  echo "Release $TAG đã tồn tại. Tăng CFBundleShortVersionString trong Info.plist rồi build lại,"
  echo "hoặc thay IPA của bản này: gh release upload $TAG dist/${IPA_ASSET_NAME} --clobber --repo $GH_REPO"
  exit 1
fi

mkdir -p dist
cp "$IPA" "dist/${IPA_ASSET_NAME}"
gh release create "$TAG" "dist/${IPA_ASSET_NAME}" \
  --repo "$GH_REPO" --target "$BRANCH" \
  --title "${APP_NAME} ${VER}" --notes "$NOTES"

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

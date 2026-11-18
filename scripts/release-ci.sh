#!/usr/bin/env bash
# Phát hành bản mới KHÔNG cần Xcode/xtool trên máy: build trên macOS runner của GitHub Actions.
#   1) Sửa code + tăng version trong Info.plist, commit
#   2) ./scripts/release-ci.sh "ghi chú bản này"
# Script: push → chạy workflow build-ipa-macos.yml (tag v<version>) → chờ xong
#         → tải IPA từ Release → cập nhật repo.json → push → kiểm tra online.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf
NOTES="${1:-Bản phát hành mới.}"
API="https://api.github.com/repos/${GH_REPO}"
TOKEN="${GITHUB_TOKEN:-$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')}"
[ -n "$TOKEN" ] || { echo "Không có token GitHub (export GITHUB_TOKEN=... hoặc lưu git credential)"; exit 1; }
gh_api() { curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

VER=$(python3 -I -c 'import plistlib;print(plistlib.load(open("Info.plist","rb"))["CFBundleShortVersionString"])')
TAG="v${VER}"
[ -z "$(git status --porcelain -- . ':!repo.json')" ] || { echo "Còn thay đổi chưa commit:"; git status --short; exit 1; }
[ "$(gh_api -o /dev/null -w '%{http_code}' "$API/releases/tags/$TAG")" != 200 ] || {
  echo "Release $TAG đã có. Tăng CFBundleShortVersionString (và CFBundleVersion) trong Info.plist trước."; exit 1; }
git push -q origin "HEAD:${BRANCH}"

echo "Chạy workflow build cho $TAG ..."
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CODE=$(jq -n --arg ref "$BRANCH" --arg tag "$TAG" '{ref: $ref, inputs: {tag: $tag}}' \
  | gh_api -o /dev/null -w '%{http_code}' -X POST "$API/actions/workflows/build-ipa-macos.yml/dispatches" -d @-)
[ "$CODE" = 204 ] || { echo "Không chạy được workflow (HTTP $CODE)"; exit 1; }

RUN=""
for _ in $(seq 1 30); do
  sleep 5
  RUN=$(gh_api "$API/actions/workflows/build-ipa-macos.yml/runs?event=workflow_dispatch&per_page=5" \
        | jq -r --arg s "$START" '[.workflow_runs[] | select(.created_at >= $s)][0].id // empty')
  [ -n "$RUN" ] && break
done
[ -n "$RUN" ] || { echo "Không thấy run mới"; exit 1; }
echo "Run: https://github.com/${GH_REPO}/actions/runs/$RUN"
for _ in $(seq 1 120); do
  S=$(gh_api "$API/actions/runs/$RUN" | jq -r '"\(.status) \(.conclusion)"')
  [[ $S == completed* ]] && break
  sleep 10
done
echo "Kết quả: $S"
[ "$S" = "completed success" ] || { gh_api "$API/actions/runs/$RUN/jobs" | jq -r '.jobs[0].steps[] | "\(.conclusion // .status)\t\(.name)"'; exit 1; }

mkdir -p dist
curl -fsSL -o "dist/${IPA_ASSET_NAME}" "https://github.com/${GH_REPO}/releases/download/${TAG}/${IPA_ASSET_NAME}"
python3 -I scripts/ipa_info.py "dist/${IPA_ASSET_NAME}"
./scripts/update-source.sh "dist/${IPA_ASSET_NAME}" "$NOTES"
./scripts/verify-source.sh
git pull -q --ff-only origin "$BRANCH" || true
git add repo.json
git commit -qm "source: ${APP_NAME} ${VER}"
git push -q origin "HEAD:${BRANCH}"
echo
./scripts/verify-source.sh --online || echo "(raw.githubusercontent có thể cache ~5 phút, chạy lại sau)"
echo
echo "KSign source: https://raw.githubusercontent.com/${GH_REPO}/${BRANCH}/repo.json  → kéo xuống để refresh"

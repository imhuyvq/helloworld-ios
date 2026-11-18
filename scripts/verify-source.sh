#!/usr/bin/env bash
# Kiểm tra repo.json trước khi push / sau khi release.
#   ./scripts/verify-source.sh            # kiểm tra offline (schema, thứ tự version, bundle ID)
#   ./scripts/verify-source.sh --online   # + tải thử từng downloadURL (HTTP 200, size khớp)
#                                         #   + đọc repo.json qua raw.githubusercontent.com
set -euo pipefail
cd "$(dirname "$0")/.."
source ./release.conf
ERR=0
bad() { echo "FAIL: $*"; ERR=1; }
ok()  { echo "ok:   $*"; }

jq empty repo.json 2>/dev/null || { echo "FAIL: repo.json không phải JSON hợp lệ"; exit 1; }
ok "JSON hợp lệ"

for k in name identifier apps; do
  jq -e --arg k "$k" 'has($k) and (.[$k] != null) and (.[$k] != "")' repo.json >/dev/null && ok "source.$k" || bad "thiếu source.$k"
done
jq -e '.apps | type == "array" and length > 0' repo.json >/dev/null || bad "apps rỗng (KSign báo 'This source does not contain any apps')"

N=$(jq '.apps | length' repo.json)
for ((i = 0; i < N; i++)); do
  A=".apps[$i]"
  BID=$(jq -r "$A.bundleIdentifier // empty" repo.json)
  for k in name bundleIdentifier developerName localizedDescription iconURL versions; do
    jq -e "$A | has(\"$k\") and (.$k != null) and (.$k != \"\")" repo.json >/dev/null || bad "app[$i] thiếu $k"
  done
  jq -e "$A | has(\"marketplaceID\") | not" repo.json >/dev/null || bad "app[$i] có marketplaceID (KSign từ chối source PAL)"
  NV=$(jq "$A.versions | length" repo.json)
  [ "$NV" -gt 0 ] || bad "app[$i] versions rỗng"
  for ((j = 0; j < NV; j++)); do
    V="$A.versions[$j]"
    for k in version date downloadURL size; do
      jq -e "$V | has(\"$k\")" repo.json >/dev/null || bad "app[$i].versions[$j] thiếu $k"
    done
    jq -e "$V.size | type == \"number\" and . > 0" repo.json >/dev/null || bad "app[$i].versions[$j].size phải là số byte > 0 (đã chạy update-source.sh chưa?)"
    jq -e "$V.downloadURL | test(\"YOUR_GITHUB_USER\") | not" repo.json >/dev/null || bad "app[$i].versions[$j].downloadURL còn placeholder YOUR_GITHUB_USER"
  done
  # versions[0] phải là bản mới nhất (KSign/Feather lấy versions.first)
  FIRST=$(jq -r "$A.versions[0].version" repo.json)
  NEWEST=$(jq -r "$A.versions[].version" repo.json | sort -V | tail -1)
  [ "$FIRST" = "$NEWEST" ] && ok "app[$i] versions[0]=$FIRST là bản mới nhất" || bad "versions[0]=$FIRST nhưng bản mới nhất là $NEWEST — đưa bản mới lên đầu"
  DUP=$(jq -r "$A.versions[].version" repo.json | sort | uniq -d)
  [ -z "$DUP" ] || bad "app[$i] trùng version: $DUP"
done

# Bundle ID trong xtool.yml phải có trong repo.json
YML_BID=$(sed -n 's/^bundleID:[[:space:]]*//p' xtool.yml | tr -d '"'"'"' ')
jq -e --arg b "$YML_BID" '.apps | any(.bundleIdentifier == $b)' repo.json >/dev/null \
  && ok "bundleID xtool.yml ($YML_BID) khớp repo.json" || bad "bundleID xtool.yml ($YML_BID) không có trong repo.json"
grep -q YOUR_GITHUB_USER repo.json release.conf && bad "còn placeholder YOUR_GITHUB_USER (sửa release.conf rồi chạy update-source.sh)" || true

if [ "${1:-}" = "--online" ]; then
  while IFS=$'\t' read -r url size; do
    read -r code len < <(curl -sIL -o /dev/null -w '%{http_code} %header{content-length}\n' "$url" | tail -1) || true
    # GitHub redirect sang objects.githubusercontent.com; content-length cuối cùng là size thật
    if [ "$code" = "200" ] && [ "$len" = "$size" ]; then ok "tải được $url ($len bytes)";
    else bad "$url → HTTP $code, content-length=$len (repo.json ghi $size)"; fi
  done < <(jq -r '.apps[].versions[] | [.downloadURL, (.size|tostring)] | @tsv' repo.json)
  for u in $(jq -r '[.iconURL] + [.apps[].iconURL] | unique | .[] | select(. != null)' repo.json); do
    c=$(curl -sL -o /dev/null -w '%{http_code}' "$u"); [ "$c" = 200 ] && ok "icon $u" || bad "icon $u → HTTP $c (đã push Resources/AppIcon.png chưa?)"
  done
  RAWURL="https://raw.githubusercontent.com/${GH_REPO}/${BRANCH}/repo.json"
  REMOTE=$(curl -sfL "$RAWURL" | jq -c -S . 2>/dev/null || true)
  if [ -z "$REMOTE" ]; then bad "không đọc được $RAWURL (repo private? chưa push?)";
  elif [ "$REMOTE" = "$(jq -c -S . repo.json)" ]; then ok "$RAWURL khớp file local";
  else echo "WARN: $RAWURL khác file local — chưa push, hoặc cache raw.githubusercontent (~5 phút)"; fi
fi

[ "$ERR" = 0 ] && echo "==> repo.json OK" || { echo "==> repo.json CÓ LỖI"; exit 1; }

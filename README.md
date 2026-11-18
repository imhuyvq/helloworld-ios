# HelloWorld (xtool → GitHub Releases → AltStore Source → KSign)

App SwiftUI tối giản để chạy thử pipeline. Hướng dẫn đầy đủ: `../HUONG-DAN.md`.

Source cho KSign: `https://raw.githubusercontent.com/imhuyvq/helloworld-ios/main/repo.json`

## Ra bản mới (không cần Xcode trên máy)

```bash
# 1. sửa code trong Sources/HelloWorld/, tăng version trong Info.plist
#    (CFBundleShortVersionString 1.0.0 → 1.0.1, CFBundleVersion 1 → 2)
git commit -am "HelloWorld 1.0.1"
# 2. build trên macOS runner của GitHub → Release → cập nhật repo.json → push
./scripts/release-ci.sh "Ghi chú bản này"
```

Build ngay trên Linux (cần Darwin SDK từ Xcode.xip): `./scripts/build.sh && ./scripts/release.sh "Ghi chú"`.

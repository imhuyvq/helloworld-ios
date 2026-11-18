# HelloWorld (xtool → GitHub Releases → AltStore Source → KSign)

App SwiftUI tối giản để chạy thử pipeline. Hướng dẫn đầy đủ: `../HUONG-DAN.md`.

```bash
./scripts/build.sh                     # xtool dev build --ipa -c release → xtool/HelloWorld.ipa
./scripts/release.sh "Ghi chú bản này" # GitHub Release + cập nhật repo.json + push
./scripts/verify-source.sh --online    # kiểm tra repo.json và link tải
```

Source URL cho KSign: `https://raw.githubusercontent.com/<USER>/<REPO>/main/repo.json`

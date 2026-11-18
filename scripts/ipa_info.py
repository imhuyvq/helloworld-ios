#!/usr/bin/env python3
"""Đọc Info.plist bên trong một .ipa và kiểm tra cấu trúc tối thiểu.

Dùng:  python3 -I scripts/ipa_info.py xtool/HelloWorld.ipa
In ra JSON: bundleIdentifier, version, build, minOSVersion, executable, size...
Exit code 1 nếu IPA sai cấu trúc (không có Payload/*.app, thiếu executable, thiếu key bắt buộc).
"""
import json
import os
import plistlib
import sys
import zipfile


def fail(msg: str) -> None:
    print(f"IPA INVALID: {msg}", file=sys.stderr)
    sys.exit(1)


def main(path: str) -> None:
    if not zipfile.is_zipfile(path):
        fail(f"{path} không phải file zip")
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        plists = [n for n in names if n.count("/") == 2 and n.startswith("Payload/")
                  and n.split("/")[1].endswith(".app") and n.endswith("/Info.plist")]
        if len(plists) != 1:
            fail(f"cần đúng 1 Payload/<App>.app/Info.plist, thấy {plists}")
        app_dir = plists[0].rsplit("/", 1)[0]
        info = plistlib.loads(z.read(plists[0]))
        for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
                    "CFBundleExecutable", "MinimumOSVersion"):
            if not info.get(key):
                fail(f"Info.plist thiếu {key}")
        exe = f"{app_dir}/{info['CFBundleExecutable']}"
        if exe not in names:
            fail(f"thiếu executable {exe}")
        icon = info.get("CFBundleIconFile")
        icon_present = bool(icon) and any(n.startswith(f"{app_dir}/{icon}") for n in names)
        signed = f"{app_dir}/_CodeSignature/CodeResources" in names
    print(json.dumps({
        "file": path,
        "size": os.path.getsize(path),
        "app": app_dir,
        "bundleIdentifier": info["CFBundleIdentifier"],
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "minOSVersion": info["MinimumOSVersion"],
        "displayName": info.get("CFBundleDisplayName"),
        "executable": exe,
        "iconFile": icon,
        "iconPresent": icon_present,
        "signed": signed,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1])

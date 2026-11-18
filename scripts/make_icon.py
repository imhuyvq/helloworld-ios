#!/usr/bin/env python3
"""Sinh icon placeholder 1024x1024 (PNG RGB, KHÔNG alpha) chỉ bằng thư viện chuẩn.

Dùng:  python3 -I scripts/make_icon.py Resources/AppIcon.png
Muốn icon thật: thay file PNG 1024x1024 bất kỳ (không trong suốt) vào cùng đường dẫn.
"""
import struct
import sys
import zlib

SIZE = 1024
TOP = (52, 199, 89)      # xanh lá  #34C759
BOTTOM = (10, 132, 255)  # xanh dương #0A84FF
WHITE = (255, 255, 255)


def pixel(x: int, y: int) -> tuple:
    # Vòng tròn trắng ở giữa + chữ "H" bằng 3 khối chữ nhật màu nền
    t = y / (SIZE - 1)
    bg = tuple(round(TOP[i] * (1 - t) + BOTTOM[i] * t) for i in range(3))
    cx = cy = SIZE / 2
    if (x - cx) ** 2 + (y - cy) ** 2 <= 330 ** 2:
        in_h = (
            (330 <= x < 420 and 300 <= y < 724)
            or (604 <= x < 694 and 300 <= y < 724)
            or (420 <= x < 604 and 467 <= y < 557)
        )
        return bg if in_h else WHITE
    return bg


def main(out_path: str) -> None:
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # filter type: None
        for x in range(SIZE):
            raw.extend(pixel(x, y))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit, color type 2 = RGB
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(out_path, "wb") as f:
        f.write(png)
    print(f"Wrote {out_path} ({len(png)} bytes, {SIZE}x{SIZE} RGB)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Resources/AppIcon.png")

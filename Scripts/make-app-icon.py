#!/usr/bin/env python3
"""生成 Cap 的 App 图标（1024px 主图 + iconset -> icns）。无第三方依赖。"""
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Cap" / "Resources"
OUT.mkdir(parents=True, exist_ok=True)

W = H = 1024
PART = 2  # 超采样倍数


def lerp(a, b, t):
    return a + (b - a) * t


def rounded_rect_sdf(x, y, cx, cy, hw, hh, r):
    dx = abs(x - cx) - (hw - r)
    dy = abs(y - cy) - (hh - r)
    outside = math.hypot(max(dx, 0), max(dy, 0))
    inside = min(max(dx, dy), 0)
    return outside + inside - r


def cover_alpha(d):
    return min(max(0.5 - d / PART, 0.0), 1.0)


def pixel(x, y):
    # 背景圆角方块（蓝色渐变 -> 紫色）
    bg_d = rounded_rect_sdf(x, y, W / 2, H / 2, 440, 440, 190)
    bg_a = cover_alpha(bg_d)
    if bg_a <= 0:
        return (0, 0, 0, 0)
    t = (y + x * 0.3) / (H * 1.3)
    r = int(lerp(38, 118, t))
    g = int(lerp(108, 60, t))
    b = int(lerp(232, 200, t))

    # 白色取景框：四个角
    white = (250, 250, 252)
    corner_len = 105
    thickness = 62
    inset = 250
    frame = 0.0
    for cy in (inset, H - inset):
        for cx in (inset, W - inset):
            # 水平条
            hx = cx - (corner_len / 2 if cx == inset else -corner_len / 2)
            h_d = rounded_rect_sdf(x, y, hx, cy, corner_len / 2, thickness / 2, 12)
            frame = max(frame, cover_alpha(h_d))
            # 垂直条
            vy = cy - (corner_len / 2 if cy == inset else -corner_len / 2)
            v_d = rounded_rect_sdf(x, y, cx, vy, thickness / 2, corner_len / 2, 12)
            frame = max(frame, cover_alpha(v_d))

    # 红色快门点
    flash_d = math.hypot(x - 700, y - 300) - 74
    flash_a = cover_alpha(flash_d)

    r = int(lerp(r, white[0], frame))
    g = int(lerp(g, white[1], frame))
    b = int(lerp(b, white[2], frame))
    r = int(lerp(r, 255, flash_a))
    g = int(lerp(g, 74, flash_a))
    b = int(lerp(b, 74, flash_a))

    a = int(255 * bg_a)
    return (r, g, b, a)


def write_png(path, width, height, rows):
    import zlib

    def chunk(tag, data):
        payload = tag + data
        return (
            struct.pack(">I", len(data))
            + payload
            + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)
        )

    raw = b"".join(
        b"\x00" + bytes(bytearray(row)) for row in rows
    )
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main():
    # 1024 主图
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            r = g = b = a = 0
            for sy in range(PART):
                for sx in range(PART):
                    pr, pg, pb, pa = pixel(x + (sx + 0.5) / PART, y + (sy + 0.5) / PART)
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            n = PART * PART
            if a > 0:
                row += [r // a, g // a, b // a, a // n]
            else:
                row += [0, 0, 0, 0]
        rows.append(row)
    write_png(OUT / "AppIcon-1024.png", W, H, rows)
    print("wrote", OUT / "AppIcon-1024.png")


if __name__ == "__main__":
    main()

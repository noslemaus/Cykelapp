"""Draw the hieroglyph pattern for the temple walls (a tiling greyscale PNG, no dependencies).

    python3 assets/texturer/egypten/hieroglyfer.py <out.png>

Eight columns of carved signs separated by thin incised lines: sun discs, eyes, birds, ankhs, water
lines, reeds, loaves, snakes, seated figures and arms, picked at random per cell. White is the
stone; the signs are mid-grey, so assets/texturer/textur_mala.py can multiply the pattern over the
sandstone (recipe "hieroglyf") and they read as cut into it. The tile is 1024 px, eight 128 px
cells across and down; on a temple facade one tile covers about 6 m.
"""
import math
import random
import struct
import sys
import zlib

W = H = 1024
CELL = 128
INK = 120          # the carved signs
LINE = 170         # the column dividers
img = [bytearray([255]) * W for _ in range(H)]


def put(x, y, v):
    x, y = int(x) % W, int(y) % H
    if v < img[y][x]:
        img[y][x] = v


def disk(cx, cy, r, v=INK):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                put(x, y, v)


def ring(cx, cy, r, w, v=INK):
    for y in range(int(cy - r - w), int(cy + r + w) + 1):
        for x in range(int(cx - r - w), int(cx + r + w) + 1):
            if abs(math.hypot(x - cx, y - cy) - r) <= w / 2:
                put(x, y, v)


def ellipse(cx, cy, rx, ry, v=INK):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(x, y, v)


def rect(x0, y0, x1, y1, v=INK):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            put(x, y, v)


def line(x0, y0, x1, y1, w=5, v=INK):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for k in range(n + 1):
        t = k / n
        disk(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, w / 2, v)


def sign(kind, cx, cy, s):
    """One sign centred at (cx, cy), about s pixels tall."""
    h = s / 2
    if kind == "sol":
        disk(cx, cy, h * 0.55)
    elif kind == "oga":
        ellipse(cx, cy, h * 0.8, h * 0.32)
        disk(cx, cy, h * 0.18, 255)
        disk(cx, cy, h * 0.1)
        line(cx - h * 0.2, cy + h * 0.3, cx - h * 0.45, cy + h * 0.75, 5)
    elif kind == "fagel":
        ellipse(cx, cy + h * 0.1, h * 0.55, h * 0.3)
        disk(cx + h * 0.5, cy - h * 0.3, h * 0.2)
        line(cx + h * 0.65, cy - h * 0.3, cx + h * 0.9, cy - h * 0.15, 4)
        line(cx - h * 0.5, cy + h * 0.1, cx - h * 0.85, cy + h * 0.35, 6)
        for dx in (-0.1, 0.15):
            line(cx + h * dx, cy + h * 0.35, cx + h * dx, cy + h * 0.85, 4)
    elif kind == "ankh":
        ring(cx, cy - h * 0.45, h * 0.28, 6)
        line(cx, cy - h * 0.17, cx, cy + h * 0.85, 7)
        line(cx - h * 0.5, cy, cx + h * 0.5, cy, 7)
    elif kind == "vatten":
        pts = [(cx - h * 0.85 + k * h * 0.2125, cy + (h * 0.18 if k % 2 else -h * 0.18)) for k in range(9)]
        for a, b in zip(pts, pts[1:]):
            line(a[0], a[1], b[0], b[1], 5)
    elif kind == "vass":
        line(cx, cy - h * 0.85, cx, cy + h * 0.85, 6)
        line(cx, cy - h * 0.5, cx + h * 0.4, cy - h * 0.85, 5)
        line(cx, cy - h * 0.2, cx - h * 0.35, cy - h * 0.55, 5)
    elif kind == "brod":
        for y in range(int(cy - h * 0.35), int(cy + h * 0.15)):
            for x in range(int(cx - h * 0.7), int(cx + h * 0.7)):
                if ((x - cx) / (h * 0.7)) ** 2 + ((y - cy - h * 0.15) / (h * 0.5)) ** 2 <= 1.0:
                    put(x, y, INK)
    elif kind == "orm":
        pts = [(cx - h * 0.85 + k * h * 0.17, cy + math.sin(k * 0.9) * h * 0.25) for k in range(11)]
        for a, b in zip(pts, pts[1:]):
            line(a[0], a[1], b[0], b[1], 6)
        disk(pts[-1][0], pts[-1][1], h * 0.12)
    elif kind == "man":
        disk(cx + h * 0.1, cy - h * 0.6, h * 0.2)
        rect(cx - h * 0.15, cy - h * 0.4, cx + h * 0.3, cy + h * 0.25)
        rect(cx - h * 0.15, cy + h * 0.15, cx + h * 0.65, cy + h * 0.45)
        rect(cx - h * 0.45, cy + h * 0.45, cx + h * 0.65, cy + h * 0.55)
    elif kind == "arm":
        rect(cx - h * 0.85, cy - h * 0.1, cx + h * 0.55, cy + h * 0.12)
        ellipse(cx + h * 0.65, cy, h * 0.22, h * 0.18)
        line(cx + h * 0.6, cy - h * 0.1, cx + h * 0.75, cy - h * 0.4, 5)
    elif kind == "kartusch":
        ring(cx, cy, h * 0.7, 5)
        disk(cx, cy, h * 0.18)


random.seed(11)
KINDS = ["sol", "oga", "fagel", "ankh", "vatten", "vass", "brod", "orm", "man", "arm", "fagel", "ankh", "kartusch"]
for col in range(W // CELL):
    x0 = col * CELL
    for y in range(H):
        for dx in range(3):
            put(x0 + dx, y, LINE)
    for row in range(H // CELL):
        cy = row * CELL + CELL / 2
        cx = x0 + CELL / 2 + 2
        kind = random.choice(KINDS)
        if kind in ("vatten", "brod", "arm") and random.random() < 0.6:
            # two small signs stacked in one cell
            sign(kind, cx, cy - CELL * 0.22, CELL * 0.42)
            sign(random.choice(["sol", "vatten", "brod", "orm"]), cx, cy + CELL * 0.22, CELL * 0.42)
        else:
            sign(kind, cx, cy, CELL * 0.72)

rows = b"".join(b"\x00" + bytes(r) for r in img)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 0, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
print("ritade", sys.argv[1])

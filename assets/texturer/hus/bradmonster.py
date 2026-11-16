"""Draw the board pattern for the falu red walls (a tiling greyscale PNG, no dependencies).

    python3 assets/texturer/hus/bradmonster.py <out.png>

Eight vertical boards per tile: each board a slightly different shade with faint grain along its
length, dark seams between them. assets/texturer/textur_mala.py multiplies it over the wall paint (and
the wood under the chips), so walls get boards with sharp seams where TextureCraft's own Stripes
procedural came out soft; at other scales and strengths it also gives roof tiles and sheet seams.
The tile is 1024 px; with eight 18 cm boards it covers 1.44 m.
"""
import math
import random
import struct
import sys
import zlib

W = H = 1024
BOARDS = 8
SEAM = 13          # px, a dark gap between boards (about 2 cm)
EDGE = 3           # px of soft falloff on each side of the seam
random.seed(7)
tone = [random.uniform(0.80, 1.0) for _ in range(BOARDS)]
# Grain: a few sines along the height, whole periods per tile so it tiles; a different set per board.
grain = [[(random.randint(3, 11), random.uniform(0, 6.28), random.uniform(0.01, 0.025)) for _ in range(3)]
         for _ in range(BOARDS)]
bw = W // BOARDS

rows = []
for y in range(H):
    row = bytearray([0])                       # PNG filter byte: none
    for x in range(W):
        b, xb = divmod(x, bw)
        v = tone[b]
        for n, ph, amp in grain[b]:
            v += amp * math.sin(2 * math.pi * n * y / H + ph + 0.04 * xb)
        d = min(xb, bw - xb)                   # distance to the nearest seam centre
        half = SEAM / 2
        if d < half:
            v *= 0.32
        elif d < half + EDGE:
            t = (d - half) / EDGE
            v *= 0.32 + 0.68 * t
        row.append(max(0, min(255, int(v * 255))))
    rows.append(bytes(row))


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 0, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
print("ritade", sys.argv[1])

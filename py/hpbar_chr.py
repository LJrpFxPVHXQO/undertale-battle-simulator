"""Add the monster HP bar sprite tiles to the damage sprite bank of Undertale.chr.

Tiles live in 1 KB CHR unit 2 (DMG_SPRITE_BNK) as 8x16 sprite pairs (top tile
empty, bottom tile holds the bar so the sprite ends above the main box). Colour 1 = green, colour 2 = red.
"""
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "Undertale.chr"
data = bytearray(open(path, "rb").read())
base = 2 * 1024

# tile index -> number of green pixels (from the left)
tiles = {0x36: 8, 0x38: 0, 0x3A: 2, 0x3C: 4, 0x3E: 6}
for tile, green in tiles.items():
    p0 = (0xFF << (8 - green)) & 0xFF if green else 0
    p1 = 0xFF ^ p0
    rows0 = [p0 if 1 <= r <= 6 else 0 for r in range(8)]
    rows1 = [p1 if 1 <= r <= 6 else 0 for r in range(8)]
    off = base + tile * 16
    data[off:off + 16] = bytes(16)
    data[off + 16:off + 32] = bytes(rows0 + rows1)

open(path, "wb").write(data)
print("patched", len(tiles), "tiles")

#!/usr/bin/env python3
"""
Draws the ring textures for the AFK Gains widget (no extra libraries).

    python3 -I tools/rings.py Media/Rings

For each ring: <ring>_track.tga (the dark empty ring) and <ring>_1..12.tga
(the filled arc, 1/12 to 12/12, from 12 o'clock clockwise, with the
colour gradient baked in and round ends). 128x128, 32-bit, anti-aliased.
"""
import math
import os
import struct
import sys

SIZE = 128
WIDGET = 84  # the widget's size in the game; radii below are in its pixels
# the addicted palette (same as Bulwark's ns.BRAND): ember, tide, arcane
RINGS = {
    "move": (37, ((0.96, 0.77, 0.19), (1.00, 0.22, 0.15))),
    "fuel": (28, ((0.15, 0.45, 1.00), (0.35, 0.90, 1.00))),
    "mind": (19, ((0.55, 0.30, 1.00), (0.95, 0.45, 0.95))),
}
THICK = 7
STEPS = 12
SS = 4  # supersampling per axis

scale = SIZE / WIDGET
c = SIZE / 2


def coverage(radius, half, frac, x, y):
    """Share of pixel (x, y) inside the arc, and the arc position 0..1 there."""
    inside, pos_sum = 0, 0.0
    for sy in range(SS):
        for sx in range(SS):
            px = x + (sx + 0.5) / SS - c
            py = c - (y + (sy + 0.5) / SS)  # up is positive
            d = math.hypot(px, py)
            # angle clockwise from 12 o'clock, 0..1
            a = (math.atan2(px, py) / (2 * math.pi)) % 1.0
            on_ring = abs(d - radius) <= half
            ok = False
            if on_ring and a <= frac:
                ok = True
            elif frac < 1:
                # round caps at both ends
                for end in (0.0, frac):
                    ex = math.sin(end * 2 * math.pi) * radius
                    ey = math.cos(end * 2 * math.pi) * radius
                    if math.hypot(px - ex, py - ey) <= half:
                        ok = True
                        a = min(a, frac) if end else 0.0
                        break
            if ok:
                inside += 1
                pos_sum += a
    n = SS * SS
    return inside / n, (pos_sum / inside if inside else 0.0)


def write_tga(path, pixels):
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8 | 0x20)
    with open(path, "wb") as f:
        f.write(hdr + bytes(pixels))


def draw(radius, colors, frac, track):
    r = radius * scale
    half = THICK * scale / 2
    out = bytearray()
    lo, hi = colors
    for y in range(SIZE):
        for x in range(SIZE):
            cov, pos = coverage(r, half, 1.0 if track else frac, x, y)
            if track:
                cr, cg, cb = lo[0] * 0.25, lo[1] * 0.25, lo[2] * 0.25
                alpha = cov * 0.85
            else:
                t = pos / frac if frac > 0 else 0
                cr = lo[0] + (hi[0] - lo[0]) * t
                cg = lo[1] + (hi[1] - lo[1]) * t
                cb = lo[2] + (hi[2] - lo[2]) * t
                alpha = cov
            out += bytes((int(cb * 255), int(cg * 255), int(cr * 255), int(alpha * 255)))
    return out


def main(dest):
    os.makedirs(dest, exist_ok=True)
    for name, (radius, colors) in RINGS.items():
        write_tga(os.path.join(dest, f"{name}_track.tga"), draw(radius, colors, 1.0, True))
        for k in range(1, STEPS + 1):
            write_tga(os.path.join(dest, f"{name}_{k}.tga"), draw(radius, colors, k / STEPS, False))
        print(name, "done")


if __name__ == "__main__":
    main(sys.argv[1])

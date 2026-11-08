#!/usr/bin/env python3
"""Install the Hind-D facings. Scales the fuselage, not the rotor span."""

import os
import sys

import paint_look as paint

IMG = paint.IMG
# Facing index matches the game camera. Nose direction on screen:
# 0 upper right, 1 up, 2 upper left, 3 left, 4 lower left,
# 5 down, 6 lower right, 7 right.
# Drawn from art/master-reference.jpeg. Roof toward the camera, wheels
# along the lower edge. 1 shares 2, and 5 shares 4: a straight-up or
# straight-down heading collapsed into a plan view.
FACES = {
    0: "54.jpg",
    2: "57.jpg",
    3: "58.jpg",
    4: "52.jpg",
    6: "62.jpg",
    7: "56.jpg",
}
COPY = {1: 2, 5: 4}
BODY = 200
# The whole bird has to sit on the map. The rotor makes the picture tall.
# Cap how far the art rises above the wheels, and how wide it is.
MAX_UP = 88
MAX_WIDE = 130


def body_box(rgba, w, h):
    """Box of the thick fuselage. Rotor blades are too thin to survive."""
    rad = 36
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(rad, h - rad, 2):
        for x in range(rad, w - rad, 2):
            if rgba[(y * w + x) * 4 + 3] == 0:
                continue
            solid = True
            for dy in (-rad, 0, rad):
                for dx in (-rad, 0, rad):
                    if rgba[((y + dy) * w + (x + dx)) * 4 + 3] == 0:
                        solid = False
                        break
                if not solid:
                    break
            if not solid:
                continue
            if x < minx:
                minx = x
            if y < miny:
                miny = y
            if x > maxx:
                maxx = x
            if y > maxy:
                maxy = y
    if maxx < 0:
        return paint.bbox(rgba, w, h)
    return minx, miny, maxx + 1, maxy + 1


def is_plate(r, g, b):
    # The paintings use magenta. JPEG keeps the red and crushes the blue.
    if g > 90 or r < 170 or b < 90:
        return False
    if r < g + 70 or b < g + 40:
        return False
    return True


def key_plate(rgba, w, h):
    out = bytearray(rgba)
    for i in range(0, len(out), 4):
        if is_plate(out[i], out[i + 1], out[i + 2]):
            out[i:i + 4] = b"\x00\x00\x00\x00"
    for _ in range(2):
        nxt = bytearray(out)
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if out[i + 3] == 0:
                    continue
                r, g, b = out[i], out[i + 1], out[i + 2]
                pink = r > g + 25 and b > g + 15 and b > 70 and r > 140
                if not pink:
                    continue
                empty = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        xx, yy = x + dx, y + dy
                        if xx < 0 or yy < 0 or xx >= w or yy >= h or out[(yy * w + xx) * 4 + 3] == 0:
                            empty += 1
                if empty >= 3:
                    nxt[i:i + 4] = b"\x00\x00\x00\x00"
        out = nxt
    return out


def prepare(path, long_side):
    w, h, rgba = paint.load_rgba(path)
    rgba = key_plate(rgba, w, h)
    bx0, by0, bx1, by1 = body_box(rgba, w, h)
    bw, bh = max(1, bx1 - bx0), max(1, by1 - by0)
    scale = long_side / max(bw, bh)
    tw = max(1, int(round(w * scale)))
    th = max(1, int(round(h * scale)))
    rgba = paint.area_resize(rgba, w, h, tw, th)
    px, py = paint.pivot_point(rgba, tw, th, "body")
    n, _, centered, cx, cy = paint.center_on(rgba, tw, th, px, py)
    x0, y0, x1, y1 = paint.bbox(centered, n, n)
    up = max(1, cy - y0)
    wide = max(1, x1 - x0)
    fit = min(1.0, MAX_UP / up, MAX_WIDE / wide)
    if fit < 0.98:
        fw = max(1, int(round(n * fit)))
        fh = max(1, int(round(n * fit)))
        centered = paint.area_resize(centered, n, n, fw, fh)
        px, py = paint.pivot_point(centered, fw, fh, "body")
        n, _, centered, cx, cy = paint.center_on(centered, fw, fh, px, py)
    centered = warm(centered, n, n)
    return n, n, centered, cx, cy, (bw, bh, tw, th)


def warm(rgba, w, h):
    """Pull a blue-gray belly back to olive and tan. Leave glass and gray blades."""
    out = bytearray(rgba)
    for i in range(0, len(out), 4):
        if out[i + 3] == 0:
            continue
        r, g, b = out[i], out[i + 1], out[i + 2]
        # Dark canopy glass stays. Gray rotor blades stay.
        if r < 48 and g < 58 and b > r:
            continue
        if abs(r - g) < 12 and abs(g - b) < 12:
            continue
        if b <= r + 4 and b <= g + 8:
            continue
        excess = b - min(r, g)
        if excess < 6:
            continue
        out[i] = min(255, r + excess // 2)
        out[i + 1] = min(255, g + excess // 3)
        out[i + 2] = max(0, b - excess)
    return out


def main():
    made = {}
    for face, name in sorted(FACES.items()):
        path = os.path.join(IMG, name)
        image = prepare(path, BODY)
        made[face] = image
        paint.save("hind_%d.png" % face, image[:3])
        print("  source %s body %dx%d scaled canvas from %dx%d" % (name, image[5][0], image[5][1], image[5][2], image[5][3]))
    for face, src in sorted(COPY.items()):
        if face in made:
            continue
        paint.save("hind_%d.png" % face, made[src][:3])
        print("  hind_%d copies hind_%d" % (face, src))


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Turn the painted sprite sources into the engine PNGs.

The Hind, vehicles, buildings, and tree come from keyed paintings.
The rotor is a soft disc. The ground is sand with roads that have edges.
Pixels stay hard. The canvas center is the ground contact.
"""

import math
import os
import struct
import subprocess
import zlib

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "sprites")
IMG = (
    "/home/hierophant/.grok/sessions/"
    "%2Fhome%2Fhierophant/01a1af89-c4dc-7f71-8954-3c5faab1dcac/images"
)
PREVIEW = "/tmp/hind-preview"

# Same camera as bake_sprites.py. Screen y grows downward.
X = (0.707107, 0.0, -0.707107)
Y = (-0.352835, 0.866611, -0.352835)
TRAVEL = (0.495196, -0.820071, -0.286817)

# Old Hind sources. The live aircraft is install_hind_d.py. Do not rebuild
# hind_*.png from this map.
HIND = {0: "3.jpg", 1: "19.jpg", 2: "9.jpg", 3: "6.jpg", 4: "5.jpg", 6: "7.jpg", 7: "10.jpg"}
HIND_COPY = {5: 4}
JEEP = {0: "2.jpg", 4: "15.jpg"}
# Face 2 is the horizontal mirror of face 0. Face 6 is the mirror of face 4.
# A copy without the mirror points the nose the wrong way, and the car looks like it slides.
JEEP_COPY = {1: 0, 3: 4, 5: 4, 7: 0}
JEEP_MIRROR = {2: 0, 6: 4}
TECH = {0: "13.jpg", 6: "16.jpg"}
TECH_COPY = {1: 0, 5: 6, 7: 0}
TECH_MIRROR = {2: 0, 4: 6}
TECH_AFTER = {3: 4}
TRUCK = {0: "18.jpg"}
TRUCK_COPY = {i: 0 for i in range(1, 8)}


def write_png(path, w, h, rgba, level=9):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), level))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def load_rgba(path):
    probe = subprocess.run(
        [
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=width,height", "-of", "csv=p=0", path,
        ],
        check=True, capture_output=True, text=True,
    )
    w, h = [int(part) for part in probe.stdout.strip().split(",")]
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
        check=True, capture_output=True,
    )
    rgba = bytearray(raw.stdout)
    if len(rgba) != w * h * 4:
        raise RuntimeError("%s decoded %d, expected %d" % (path, len(rgba), w * h * 4))
    return w, h, rgba


def is_bg(r, g, b):
    if r > 165 and b > 135 and g < 115 and r > g + 45 and b > g + 25:
        return True
    return False


def key_magenta(rgba, w, h):
    out = bytearray(rgba)
    for i in range(0, len(out), 4):
        if is_bg(out[i], out[i + 1], out[i + 2]):
            out[i:i + 4] = b"\x00\x00\x00\x00"
    # Drop pink pixels that only survived because a neighbor is paint.
    for _ in range(2):
        nxt = bytearray(out)
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if out[i + 3] == 0:
                    continue
                r, g, b = out[i], out[i + 1], out[i + 2]
                pink = r > g + 25 and b > g + 15 and b > 90 and r > 120
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


def bbox(rgba, w, h):
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        row = y * w * 4
        for x in range(w):
            if rgba[row + x * 4 + 3]:
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return 0, 0, 1, 1
    return minx, miny, maxx + 1, maxy + 1


def crop(rgba, w, h, box):
    x0, y0, x1, y1 = box
    cw, ch = x1 - x0, y1 - y0
    out = bytearray(cw * ch * 4)
    for y in range(ch):
        src = ((y0 + y) * w + x0) * 4
        dst = y * cw * 4
        out[dst:dst + cw * 4] = rgba[src:src + cw * 4]
    return cw, ch, out


def area_resize(rgba, w, h, tw, th):
    out = bytearray(tw * th * 4)
    for y in range(th):
        sy0 = y * h / th
        sy1 = (y + 1) * h / th
        for x in range(tw):
            sx0 = x * w / tw
            sx1 = (x + 1) * w / tw
            ar = ag = ab = aa = 0.0
            for iy in range(int(sy0), min(h, int(math.ceil(sy1)))):
                yf = min(sy1, iy + 1) - max(sy0, iy)
                if yf <= 0:
                    continue
                row = iy * w
                for ix in range(int(sx0), min(w, int(math.ceil(sx1)))):
                    xf = min(sx1, ix + 1) - max(sx0, ix)
                    if xf <= 0:
                        continue
                    o = (row + ix) * 4
                    a = rgba[o + 3] / 255.0
                    weight = xf * yf * a
                    ar += rgba[o] * weight
                    ag += rgba[o + 1] * weight
                    ab += rgba[o + 2] * weight
                    aa += xf * yf * a
            cover = aa / max(1e-6, (sx1 - sx0) * (sy1 - sy0))
            o = (y * tw + x) * 4
            if cover < 0.45 or aa < 1e-4:
                continue
            out[o] = int(ar / aa + 0.5)
            out[o + 1] = int(ag / aa + 0.5)
            out[o + 2] = int(ab / aa + 0.5)
            out[o + 3] = 255
    return out


def scale_long(rgba, w, h, long_side):
    x0, y0, x1, y1 = bbox(rgba, w, h)
    cw, ch, cropped = crop(rgba, w, h, (x0, y0, x1, y1))
    scale = long_side / max(cw, ch)
    tw = max(1, int(round(cw * scale)))
    th = max(1, int(round(ch * scale)))
    return tw, th, area_resize(cropped, cw, ch, tw, th)


def flip_x(rgba, w, h):
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            s = (y * w + x) * 4
            d = (y * w + (w - 1 - x)) * 4
            out[d:d + 4] = rgba[s:s + 4]
    return out


def pivot_point(rgba, w, h, mode):
    x0, y0, x1, y1 = bbox(rgba, w, h)
    if mode == "roof":
        # Roof center keeps the building over its footprint. Bottom sits on the ground.
        count = 0
        sx = 0
        limit = y0 + max(2, (y1 - y0) // 3)
        for y in range(y0, limit):
            for x in range(x0, x1):
                if rgba[(y * w + x) * 4 + 3]:
                    sx += x
                    count += 1
        px = sx // count if count else (x0 + x1) // 2
        return px, y1 - 1
    if mode == "trunk":
        band = max(2, (y1 - y0) // 5)
        count = 0
        sx = 0
        for y in range(y1 - band, y1):
            for x in range(w):
                if rgba[(y * w + x) * 4 + 3]:
                    sx += x
                    count += 1
        px = sx // count if count else (x0 + x1) // 2
        return px, y1 - 1
    if mode == "body":
        # The contact under the fuselage, not the tail wheel at the bottom corner.
        mid0 = y0 + (y1 - y0) // 3
        mid1 = y0 + 2 * (y1 - y0) // 3
        count = 0
        sx = 0
        for y in range(mid0, mid1):
            for x in range(x0, x1):
                if rgba[(y * w + x) * 4 + 3]:
                    sx += x
                    count += 1
        cx = sx // count if count else (x0 + x1) // 2
        span = max(6, (x1 - x0) // 7)
        for y in range(y1 - 1, y0 - 1, -1):
            hit = []
            for x in range(cx - span, cx + span + 1):
                if 0 <= x < w and rgba[(y * w + x) * 4 + 3]:
                    hit.append(x)
            if len(hit) >= 2:
                return sum(hit) // len(hit), y
        return cx, y1 - 1
    # Wheels: the contact cluster along the bottom.
    band = max(2, (y1 - y0) // 6)
    count = 0
    sx = 0
    for y in range(y1 - band, y1):
        for x in range(w):
            if rgba[(y * w + x) * 4 + 3]:
                sx += x
                count += 1
    px = sx // count if count else (x0 + x1) // 2
    return px, y1 - 1


def center_on(rgba, w, h, px, py):
    left, right = px, w - 1 - px
    up, down = py, h - 1 - py
    half = max(left, right, up, down, 1)
    n = half * 2 + 1
    out = bytearray(n * n * 4)
    ox = half - px
    oy = half - py
    for y in range(h):
        yy = y + oy
        if yy < 0 or yy >= n:
            continue
        for x in range(w):
            xx = x + ox
            if xx < 0 or xx >= n:
                continue
            s = (y * w + x) * 4
            if rgba[s + 3] == 0:
                continue
            d = (yy * n + xx) * 4
            out[d:d + 4] = rgba[s:s + 4]
    return n, n, out, half, half


def find_hub(rgba, w, h, cx, cy):
    # The mast sits over the middle of the body. The tail fin is higher and farther out.
    count = 0
    sx = 0
    sy = 0
    for y in range(h):
        for x in range(w):
            if rgba[(y * w + x) * 4 + 3]:
                sx += x
                sy += y
                count += 1
    mx = sx / count if count else cx
    my = sy / count if count else cy
    best = None
    best_dist = 1e9
    for y in range(h):
        for x in range(w):
            if rgba[(y * w + x) * 4 + 3] == 0:
                continue
            if y > my:
                continue
            above = y == 0 or rgba[((y - 1) * w + x) * 4 + 3] == 0
            if not above:
                continue
            dx = abs(x - mx)
            if dx > w * 0.16:
                continue
            dist = dx + (my - y) * 0.15
            if dist < best_dist:
                best_dist = dist
                best = (x, y)
    if best is None:
        return 0, int(cy - my) if my < cy else -8
    return best[0] - cx, best[1] - cy


def prepare(path, long_side, mode, mirror=False):
    w, h, rgba = load_rgba(path)
    rgba = key_magenta(rgba, w, h)
    if mirror:
        rgba = flip_x(rgba, w, h)
    w, h, rgba = scale_long(rgba, w, h, long_side)
    px, py = pivot_point(rgba, w, h, mode)
    n, _, centered, cx, cy = center_on(rgba, w, h, px, py)
    return n, n, centered, cx, cy


def save(name, image):
    w, h, rgba = image
    write_png(os.path.join(OUT, name), w, h, rgba)
    opaque = sum(1 for i in range(3, len(rgba), 4) if rgba[i])
    print("%s %dx%d opaque %d" % (name, w, h, opaque))
    return image


def shift_canopy(image, dx):
    w, h, rgba = image
    out = bytearray(w * h * 4)
    cut = int(h * 0.62)
    for y in range(h):
        slide = dx if y < cut else 0
        for x in range(w):
            s = (y * w + x) * 4
            if rgba[s + 3] == 0:
                continue
            xx = x + slide
            if xx < 0 or xx >= w:
                continue
            d = (y * w + xx) * 4
            out[d:d + 4] = rgba[s:s + 4]
    return w, h, out


def rotate_image(image, degrees):
    w, h, rgba = image
    rad = math.radians(degrees)
    c, s = math.cos(rad), math.sin(rad)
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    # Bounds of the rotated corners.
    corners = []
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        dx, dy = x - cx, y - cy
        corners.append((dx * c - dy * s, dx * s + dy * c))
    minx = min(p[0] for p in corners)
    miny = min(p[1] for p in corners)
    maxx = max(p[0] for p in corners)
    maxy = max(p[1] for p in corners)
    nw = int(math.ceil(maxx - minx)) + 1
    nh = int(math.ceil(maxy - miny)) + 1
    out = bytearray(nw * nh * 4)
    ocx = -minx
    ocy = -miny
    for y in range(nh):
        for x in range(nw):
            dx, dy = x - ocx, y - ocy
            sx = dx * c + dy * s + cx
            sy = -dx * s + dy * c + cy
            ix, iy = int(round(sx)), int(round(sy))
            if ix < 0 or iy < 0 or ix >= w or iy >= h:
                continue
            s_i = (iy * w + ix) * 4
            if rgba[s_i + 3] == 0:
                continue
            d = (y * nw + x) * 4
            out[d:d + 4] = rgba[s_i:s_i + 4]
    return nw, nh, out


def wreck_from(image):
    w, h, rgba = rotate_image(image, 18)
    out = bytearray(rgba)
    for i in range(0, len(out), 4):
        if out[i + 3] == 0:
            continue
        out[i] = (out[i] * 2 + 36) // 5
        out[i + 1] = (out[i + 1] * 2 + 28) // 5
        out[i + 2] = (out[i + 2] * 2 + 22) // 5
    # A few fire pixels near the middle, so a wreck reads as burned.
    cx, cy = w // 2, h // 2
    fire = ((255, 214, 96), (220, 96, 32), (120, 48, 24))
    for k, (dx, dy) in enumerate(((-2, 0), (0, -1), (2, 1), (1, 2), (-1, 2), (3, -1))):
        x, y = cx + dx, cy + dy
        if 0 <= x < w and 0 <= y < h:
            o = (y * w + x) * 4
            col = fire[k % 3]
            out[o:o + 4] = bytes((col[0], col[1], col[2], 255))
    px, py = pivot_point(out, w, h, "wheels")
    n, _, centered, _, _ = center_on(out, w, h, px, py)
    return n, n, centered


def tip_from(image):
    w, h, rgba = rotate_image(image, 68)
    px, py = pivot_point(rgba, w, h, "wheels")
    n, _, centered, _, _ = center_on(rgba, w, h, px, py)
    return n, n, centered


def bush_from(tree):
    w, h, rgba = tree
    # The canopy is the wide top. Take that and shrink it.
    cut = int(h * 0.55)
    cw, ch, cropped = crop(rgba, w, h, (0, 0, w, cut))
    tw, th = max(8, cw // 2), max(8, ch // 2)
    small = area_resize(cropped, cw, ch, tw, th)
    px, py = pivot_point(small, tw, th, "trunk")
    n, _, centered, _, _ = center_on(small, tw, th, px, py)
    return n, n, centered


def flag_image(frame):
    w, h = 28, 40
    rgba = bytearray(w * h * 4)
    pole = (48, 40, 32)
    for y in range(6, 38):
        o = (y * w + 6) * 4
        rgba[o:o + 4] = bytes((pole[0], pole[1], pole[2], 255))
    cloth = ((168, 48, 36), (214, 196, 150), (92, 112, 56))
    for row in range(8):
        wave = int(round(math.sin(row * 0.7 + frame * 1.3) * 2))
        y = 8 + row
        color = cloth[row % 3]
        for x in range(8, 22):
            xx = x + wave
            if 0 <= xx < w:
                o = (y * w + xx) * 4
                rgba[o:o + 4] = bytes((color[0], color[1], color[2], 255))
    px, py = 6, 37
    n, _, centered, _, _ = center_on(rgba, w, h, px, py)
    return n, n, centered


def disc(w, h, rgba, cx, cy, rx, ry, color):
    for y in range(h):
        for x in range(w):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                o = (y * w + x) * 4
                rgba[o:o + 4] = bytes((color[0], color[1], color[2], 255))


def rotor_image(frame):
    rx, ry = 108, 64
    w, h = rx * 2 + 5, ry * 2 + 5
    rgba = bytearray(w * h * 4)
    cx, cy = w // 2, h // 2
    spin = frame * (math.tau / 3.0)
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            e = nx * nx + ny * ny
            if e > 1.0:
                continue
            ang = math.atan2(ny, nx)
            lobe = abs(math.sin(1.5 * (ang - spin)))
            # Soft oval. The edge fades out so it does not read as a hard wedge.
            fade = max(0.0, 1.0 - e)
            alpha = int(18 + 52 * (fade ** 0.65))
            if lobe > 0.72 and 0.08 < e < 0.9:
                alpha += int((lobe - 0.72) * 180)
            if alpha > 120:
                alpha = 120
            if e < 0.02:
                alpha = min(alpha, 30)
            if alpha < 8:
                continue
            o = (y * w + x) * 4
            rgba[o] = 210
            rgba[o + 1] = 204
            rgba[o + 2] = 184
            rgba[o + 3] = alpha
    return w, h, rgba


def dust_image(frame):
    w = h = 97
    rgba = bytearray(w * h * 4)
    cx = cy = 48
    colors = ((232, 208, 156), (196, 160, 104), (168, 132, 84))
    for i in range(14):
        ang = math.tau * i / 14.0 + frame * 0.55
        rad = 28 + (i % 4) * 4
        x = int(cx + math.cos(ang) * rad)
        y = int(cy + math.sin(ang) * rad * 0.55)
        blob = 3 + (i + frame) % 3
        disc(w, h, rgba, x, y, blob + 1, max(2, blob - 1), colors[i % 3])
    # Knock a few holes so the puffs are not coins.
    for y in range(h):
        for x in range(w):
            if ((x * 13 + y * 7 + frame) % 11) == 0:
                rgba[(y * w + x) * 4 + 3] = 0
    return w, h, rgba


def shadow_image():
    w, h = 97, 49
    rgba = bytearray(w * h * 4)
    cx, cy = 48, 24
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 40.0
            dy = (y - cy) / 16.0
            e = dx * dx + dy * dy
            if e > 1.0:
                continue
            if e > 0.72 and ((x + y) & 1):
                continue
            o = (y * w + x) * 4
            rgba[o:o + 4] = bytes((54, 40, 28, 255))
    return w, h, rgba


def bullet_image():
    w = h = 9
    rgba = bytearray(w * h * 4)
    disc(w, h, rgba, 4, 4, 3, 3, (240, 164, 48))
    disc(w, h, rgba, 4, 4, 1.3, 1.3, (255, 236, 190))
    return w, h, rgba


def tracer_image():
    w, h = 7, 29
    rgba = bytearray(w * h * 4)
    for y in range(h):
        span = 1 if y < 4 or y > h - 5 else 2
        for x in range(3 - span, 4 + span):
            o = (y * w + x) * 4
            col = (255, 236, 190) if 8 < y < 20 else (230, 150, 48)
            rgba[o:o + 4] = bytes((col[0], col[1], col[2], 255))
    return w, h, rgba


def boom_image(frame):
    w = h = 49
    rgba = bytearray(w * h * 4)
    cx = cy = 24
    if frame == 0:
        disc(w, h, rgba, cx, cy, 5, 4, (240, 150, 40))
        disc(w, h, rgba, cx, cy, 2, 2, (255, 236, 180))
    elif frame == 1:
        disc(w, h, rgba, cx, cy, 11, 9, (168, 56, 24))
        disc(w, h, rgba, cx, cy, 6, 5, (240, 150, 40))
        disc(w, h, rgba, cx, cy - 1, 3, 2, (255, 236, 180))
    elif frame == 2:
        disc(w, h, rgba, cx, cy, 16, 13, (96, 36, 20))
        disc(w, h, rgba, cx + 2, cy - 3, 6, 5, (210, 96, 28))
        disc(w, h, rgba, cx - 5, cy + 3, 3, 3, (48, 40, 32))
    else:
        disc(w, h, rgba, cx, cy, 18, 14, (62, 48, 36))
        disc(w, h, rgba, cx + 4, cy - 2, 6, 4, (96, 36, 20))
        disc(w, h, rgba, cx - 4, cy + 2, 2, 2, (240, 150, 40))
    return w, h, rgba


def hash2(ix, iy):
    n = (ix * 374761393 + iy * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 255) / 255.0


def value_noise(x, y):
    x0 = math.floor(x)
    y0 = math.floor(y)
    tx = x - x0
    ty = y - y0
    sx = tx * tx * (3 - 2 * tx)
    sy = ty * ty * (3 - 2 * ty)
    ix, iy = int(x0), int(y0)
    a = hash2(ix, iy)
    b = hash2(ix + 1, iy)
    c = hash2(ix, iy + 1)
    d = hash2(ix + 1, iy + 1)
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy


def dist_seg(px, py, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    den = abx * abx + aby * aby
    if den < 1e-6:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * abx + (py - ay) * aby) / den
    if t < 0.0:
        t = 0.0
    if t > 1.0:
        t = 1.0
    return math.hypot(px - (ax + abx * t), py - (ay + aby * t))


def paint_road(col, dist, half):
    berm = (214, 186, 128)
    bed = (138, 106, 64)
    rut = (86, 62, 36)
    if dist > half:
        return col
    if dist > half - 0.28:
        return berm
    lane = abs(dist - half * 0.42)
    if lane < 0.16:
        return rut
    return bed


def ground_image(sand_path):
    w = h = 1200
    sw, sh, sand = load_rgba(sand_path)
    rgba = bytearray(w * h * 4)
    for y in range(h):
        sy = min(sh - 1, int(y * sh / h))
        for x in range(w):
            sx = min(sw - 1, int(x * sw / w))
            s = (sy * sw + sx) * 4
            n = value_noise(x / 86.0, y / 86.0)
            gain = 0.88 + n * 0.22
            r = int(min(255, sand[s] * gain))
            g = int(min(255, sand[s + 1] * gain))
            b = int(min(255, sand[s + 2] * gain))
            o = (y * w + x) * 4
            rgba[o] = r
            rgba[o + 1] = g
            rgba[o + 2] = b
            rgba[o + 3] = 255
    # Roads in world meters. Width is the full width.
    roads = (
        ((2.0, 26.0), (2.0, -26.0), 2.8),
        ((-24.0, -6.0), (26.0, -6.0), 2.6),
        ((2.0, -6.0), (-2.0, 12.0), 2.0),
        ((2.0, -6.0), (14.0, -18.0), 2.0),
        ((2.0, 14.0), (-12.0, 8.0), 1.7),
    )
    pads = ((-16.0, -16.0, 5.4, 4.2), (14.0, -18.0, 4.6, 5.4), (-2.0, 12.0, 4.2, 4.2))
    pad_col = (176, 142, 96)
    pad_edge = (120, 90, 58)
    for y in range(h):
        wz = ((1.0 - (y + 0.5) / h) - 0.5) * 100.0
        row = y * w
        for x in range(w):
            wx = ((x + 0.5) / w - 0.5) * 100.0
            best = 1e9
            half = 1.0
            for a, b, width in roads:
                dist = dist_seg(wx, wz, a[0], a[1], b[0], b[1])
                if dist < best:
                    best = dist
                    half = width * 0.5
            o = (row + x) * 4
            if best <= half:
                col = paint_road((rgba[o], rgba[o + 1], rgba[o + 2]), best, half)
                rgba[o] = col[0]
                rgba[o + 1] = col[1]
                rgba[o + 2] = col[2]
            for mx, mz, rx, rz in pads:
                ex = (wx - mx) / rx
                ez = (wz - mz) / rz
                e = ex * ex + ez * ez
                if e <= 1.0:
                    col = pad_edge if e > 0.82 else pad_col
                    rgba[o] = col[0]
                    rgba[o + 1] = col[1]
                    rgba[o + 2] = col[2]
    # Scrub stamps. Fixed spots, not a lattice.
    stamps = (
        (-8, 18), (7, 16), (-18, 8), (12, 9), (-5, 0), (9, -14),
        (-20, -12), (22, -8), (16, 18), (-12, -20), (1, 8), (24, 6),
        (-22, 20), (11, -22), (-7, 24), (19, -18), (-15, -2), (5, 5),
        (-3, -10), (15, 2), (-24, -20), (8, 22), (-18, 14), (20, 12),
    )
    greens = ((72, 92, 38), (52, 74, 30), (88, 78, 40), (44, 60, 26), (104, 96, 52))
    road_cols = ((214, 186, 128), (138, 106, 64), (86, 62, 36), (176, 142, 96), (120, 90, 58))
    for index, (mx, mz) in enumerate(stamps):
        u = mx / 100.0 + 0.5
        v = mz / 100.0 + 0.5
        cx = int(u * w)
        cy = int((1.0 - v) * h)
        rad = 11 + (index % 4) * 4
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                jitter = hash2(dx + index * 5, dy - index * 3)
                limit = rad * rad * (0.45 + jitter * 0.55)
                if dx * dx + dy * dy * 1.35 > limit:
                    continue
                x, y = cx + dx, cy + dy
                if x < 0 or y < 0 or x >= w or y >= h:
                    continue
                o = (y * w + x) * 4
                cur = (rgba[o], rgba[o + 1], rgba[o + 2])
                skip = False
                for road in road_cols:
                    if abs(cur[0] - road[0]) < 18 and abs(cur[1] - road[1]) < 18 and abs(cur[2] - road[2]) < 18:
                        skip = True
                        break
                if skip:
                    continue
                col = greens[int(jitter * 5) % 5]
                rgba[o] = col[0]
                rgba[o + 1] = col[1]
                rgba[o + 2] = col[2]
    return w, h, rgba


def blit(dst, dw, dh, image, px, py):
    w, h, rgba = image
    acx, acy = w // 2, h // 2
    for y in range(h):
        yy = py + (y - acy)
        if yy < 0 or yy >= dh:
            continue
        for x in range(w):
            xx = px + (x - acx)
            if xx < 0 or xx >= dw:
                continue
            s = (y * w + x) * 4
            if rgba[s + 3] == 0:
                continue
            d = (yy * dw + xx) * 4
            dst[d:d + 4] = rgba[s:s + 4]


def mark(image, dx, dy, color):
    w, h, rgba = image
    x = w // 2 + dx
    y = h // 2 + dy
    out = bytearray(rgba)
    for oy in range(-1, 2):
        for ox in range(-1, 2):
            xx, yy = x + ox, y + oy
            if 0 <= xx < w and 0 <= yy < h:
                o = (yy * w + xx) * 4
                out[o:o + 4] = bytes(color)
    return w, h, out


def upscale(image, n):
    w, h, rgba = image
    ow, oh = w * n, h * n
    out = bytearray(ow * oh * 4)
    for y in range(h):
        for x in range(w):
            pix = rgba[(y * w + x) * 4:(y * w + x) * 4 + 4]
            if pix[3] == 0:
                pix = bytes((90, 40, 120, 255))
            for dy in range(n):
                for dx in range(n):
                    d = ((y * n + dy) * ow + (x * n + dx)) * 4
                    out[d:d + 4] = pix
    return ow, oh, out


def faces_from(table, copies, long_side, mode, prefix, mirrors=None, after=None):
    made = {}
    hubs = {}
    for index, name in table.items():
        w, h, rgba, cx, cy = prepare(os.path.join(IMG, name), long_side, mode)
        made[index] = (w, h, rgba)
        if prefix == "hind":
            hubs[index] = find_hub(rgba, w, h, cx, cy)
        save("%s_%d.png" % (prefix, index), made[index])
    for index, source in copies.items():
        made[index] = made[source]
        if prefix == "hind":
            hubs[index] = hubs[source]
        save("%s_%d.png" % (prefix, index), made[index])
    if mirrors:
        for index, source in mirrors.items():
            w, h, rgba = made[source]
            made[index] = (w, h, flip_x(rgba, w, h))
            save("%s_%d.png" % (prefix, index), made[index])
    if after:
        for index, source in after.items():
            made[index] = made[source]
            save("%s_%d.png" % (prefix, index), made[index])
    return made, hubs


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    hind, hubs = faces_from(HIND, HIND_COPY, 188, "body", "hind")
    jeep, _ = faces_from(JEEP, JEEP_COPY, 78, "wheels", "jeep", JEEP_MIRROR)
    tech, _ = faces_from(TECH, TECH_COPY, 96, "wheels", "technical", TECH_MIRROR, TECH_AFTER)
    truck, _ = faces_from(TRUCK, TRUCK_COPY, 124, "wheels", "truck")
    save("jeep_tip.png", tip_from(jeep[0]))
    save("jeep_wreck.png", wreck_from(jeep[0]))
    save("technical_tip.png", tip_from(tech[0]))
    save("technical_wreck.png", wreck_from(tech[0]))

    b0 = prepare(os.path.join(IMG, "17.jpg"), 168, "roof")
    b1 = prepare(os.path.join(IMG, "4.jpg"), 156, "roof", mirror=True)
    b2 = prepare(os.path.join(IMG, "4.jpg"), 142, "roof")
    save("building_0.png", b0[:3])
    save("building_1.png", b1[:3])
    save("building_2.png", b2[:3])

    tree = prepare(os.path.join(IMG, "14.jpg"), 86, "trunk")
    tree_img = tree[:3]
    save("tree_0.png", tree_img)
    save("tree_1.png", shift_canopy(tree_img, -3))
    save("tree_2.png", shift_canopy(tree_img, 3))
    save("bush.png", bush_from(tree_img))
    for i in range(3):
        save("flag_%d.png" % i, flag_image(i))
        save("rotor_%d.png" % i, rotor_image(i))
        save("dust_%d.png" % i, dust_image(i))
        save("boom_%d.png" % i, boom_image(i))
    save("boom_3.png", boom_image(3))
    save("shadow.png", shadow_image())
    save("bullet.png", bullet_image())
    save("tracer.png", tracer_image())

    hub_rows = []
    for i in range(8):
        dx, dy = hubs[i]
        hub_rows.append("    [%d, %d]" % (dx, dy))
        marked = mark(hind[i], dx, dy, (255, 40, 40, 255))
        sheet = upscale(marked, 2)
        write_png(os.path.join(PREVIEW, "hub-%d.png" % i), sheet[0], sheet[1], sheet[2], 1)
    layout = (
        '{\n  "ppm": 12,\n  "pixel_size": 0.0833333333333,\n'
        '  "mast": [0.0000, 3.2000, 0.0000],\n'
        '  "travel": [%.6f, %.6f, %.6f],\n'
        '  "hubs": [\n%s\n  ]\n}\n'
    ) % (TRAVEL[0], TRAVEL[1], TRAVEL[2], ",\n".join(hub_rows))
    with open(os.path.join(OUT, "layout.json"), "w", encoding="utf-8") as handle:
        handle.write(layout)
    print("ground")
    gw, gh, gr = ground_image(os.path.join(IMG, "1.jpg"))
    write_png(os.path.join(OUT, "ground.png"), gw, gh, gr, 1)
    print("ground %dx%d" % (gw, gh))
    # A crop of the sand the Hind sits on, so the road edges can be judged.
    crop_w, crop_h = 220, 160
    cx = int((0.0 / 100.0 + 0.5) * gw)
    cy = int((1.0 - (22.0 / 100.0 + 0.5)) * gh)
    crop = bytearray(crop_w * crop_h * 4)
    for y in range(crop_h):
        sy = cy - crop_h // 2 + y
        for x in range(crop_w):
            sx = cx - crop_w // 2 + x
            if 0 <= sx < gw and 0 <= sy < gh:
                crop[(y * crop_w + x) * 4:(y * crop_w + x) * 4 + 4] = gr[(sy * gw + sx) * 4:(sy * gw + sx) * 4 + 4]
    big = upscale((crop_w, crop_h, crop), 2)
    write_png(os.path.join(PREVIEW, "ground-crop.png"), big[0], big[1], big[2], 1)
    one = upscale(hind[0], 2)
    write_png(os.path.join(PREVIEW, "hind-0.png"), one[0], one[1], one[2], 1)
    jeep_big = upscale(jeep[0], 3)
    write_png(os.path.join(PREVIEW, "jeep-0.png"), jeep_big[0], jeep_big[1], jeep_big[2], 1)
    bld = upscale(b2[:3], 2)
    write_png(os.path.join(PREVIEW, "building.png"), bld[0], bld[1], bld[2], 1)
    print("hubs", [hubs[i] for i in range(8)])


if __name__ == "__main__":
    main()

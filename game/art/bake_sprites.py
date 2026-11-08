#!/usr/bin/env python3
"""Paint Gunship Ace sprites for the fixed orthographic camera.

The camera matches Godot look_at from hind+(14,12,14) to hind+(0,0.6,0).
Pixels are 12 per meter. Run from anywhere. Writes game/art/sprites/.
"""

import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "sprites")
PPM = 12

# Godot Camera3D basis. +Z points from the Hind toward the camera.
X = (0.707107, 0.0, -0.707107)
Y = (-0.352835, 0.866611, -0.352835)
Z = (0.612787, 0.498984, 0.612787)

# Light sits up and to the left of the screen.
_LX = -0.55 * X[0] + 0.78 * Y[0] + 0.28 * Z[0]
_LY = -0.55 * X[1] + 0.78 * Y[1] + 0.28 * Z[1]
_LZ = -0.55 * X[2] + 0.78 * Y[2] + 0.28 * Z[2]
_LL = math.sqrt(_LX * _LX + _LY * _LY + _LZ * _LZ)
L = (_LX / _LL, _LY / _LL, _LZ / _LL)
TRAVEL = (-L[0], -L[1], -L[2])

# Mast top in Hind local meters. The rotor sprite is centered here.
MAST = (0.0, 2.55, 0.02)

BAYER = (
    (0, 8, 2, 10),
    (12, 4, 14, 6),
    (3, 11, 1, 9),
    (15, 7, 13, 5),
)

# Material ramps, light to dark. Shared earth palette.
BODY = 1
SAND = 2
GLASS = 3
METAL = 4
RUBBER = 5
RED = 6
RUST = 7
TRUCK = 8
ADOBE = 9
ROOF = 10
LEAF = 11
LEAF2 = 12
TRUNK = 13
LINE = 14
TIRE = 15
HUB = 16
DUST = 17
FIRE = 18
SCORCH = 19

RAMPS = {
    BODY: ((138, 142, 72), (86, 96, 44), (48, 58, 26)),
    SAND: ((214, 182, 122), (168, 132, 78), (112, 84, 48)),
    GLASS: ((214, 236, 226), (96, 176, 174), (28, 86, 96)),
    METAL: ((176, 170, 152), (108, 104, 94), (58, 56, 50)),
    RUBBER: ((72, 66, 56), (36, 32, 28), (16, 14, 12)),
    RED: ((204, 64, 44), (140, 32, 26), (78, 18, 14)),
    RUST: ((186, 124, 68), (136, 84, 44), (84, 50, 28)),
    TRUCK: ((156, 162, 144), (100, 108, 96), (58, 64, 56)),
    ADOBE: ((204, 164, 112), (156, 116, 74), (102, 72, 46)),
    ROOF: ((132, 78, 48), (92, 52, 32), (54, 30, 20)),
    LEAF: ((136, 150, 64), (78, 104, 38), (40, 62, 24)),
    LEAF2: ((104, 122, 48), (58, 82, 30), (30, 46, 18)),
    TRUNK: ((148, 100, 58), (96, 62, 36), (58, 36, 22)),
    LINE: ((32, 26, 16),),
    TIRE: ((48, 44, 38), (24, 22, 18), (12, 10, 8)),
    HUB: ((168, 164, 148), (90, 86, 76), (40, 38, 34)),
    DUST: ((236, 214, 160), (196, 160, 96)),
    FIRE: ((255, 244, 200), (240, 164, 48), (176, 64, 24)),
    SCORCH: ((72, 60, 46), (40, 34, 28), (20, 16, 14)),
}
GAP = {DUST}
INK = (18, 12, 8, 255)


def rot_x(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def rot_y(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def rot_z(p, a):
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def norm(a):
    n = math.sqrt(dot(a, a))
    if n < 1e-8:
        return (0.0, 1.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)


def quad(mesh, a, b, c, d, mat, outward):
    n = cross(sub(b, a), sub(c, a))
    if dot(n, outward) < 0.0:
        b, d = d, b
    mesh.append((a, b, c, mat))
    mesh.append((a, c, d, mat))


def add_box(mesh, center, size, mat, rx=0.0, ry=0.0, rz=0.0):
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5

    def tp(x, y, z):
        p = rot_x((x, y, z), rx)
        p = rot_z(p, rz)
        p = rot_y(p, ry)
        return (p[0] + center[0], p[1] + center[1], p[2] + center[2])

    def td(x, y, z):
        p = rot_x((x, y, z), rx)
        p = rot_z(p, rz)
        return rot_y(p, ry)

    c = [[[None, None], [None, None]], [[None, None], [None, None]]]
    for xi in (0, 1):
        for yi in (0, 1):
            for zi in (0, 1):
                c[xi][yi][zi] = tp((xi * 2 - 1) * hx, (yi * 2 - 1) * hy, (zi * 2 - 1) * hz)
    quad(mesh, c[1][0][0], c[1][0][1], c[1][1][1], c[1][1][0], mat, td(1, 0, 0))
    quad(mesh, c[0][0][1], c[0][0][0], c[0][1][0], c[0][1][1], mat, td(-1, 0, 0))
    quad(mesh, c[0][1][1], c[1][1][1], c[1][1][0], c[0][1][0], mat, td(0, 1, 0))
    quad(mesh, c[0][0][0], c[1][0][0], c[1][0][1], c[0][0][1], mat, td(0, -1, 0))
    quad(mesh, c[0][0][1], c[1][0][1], c[1][1][1], c[0][1][1], mat, td(0, 0, 1))
    quad(mesh, c[1][0][0], c[0][0][0], c[0][1][0], c[1][1][0], mat, td(0, 0, -1))


def add_ellipsoid(mesh, center, rx, ry, rz, mat, nu=14, nv=8):
    rows = []
    for i in range(nv + 1):
        theta = math.pi * i / nv
        st, ct = math.sin(theta), math.cos(theta)
        row = []
        for j in range(nu):
            phi = math.tau * j / nu
            row.append((
                center[0] + rx * st * math.cos(phi),
                center[1] + ry * ct,
                center[2] + rz * st * math.sin(phi),
            ))
        rows.append(row)
    for i in range(nv):
        for j in range(nu):
            j2 = (j + 1) % nu
            a, b = rows[i][j], rows[i][j2]
            c, d = rows[i + 1][j2], rows[i + 1][j]
            mid = mul(add(add(a, b), add(c, d)), 0.25)
            quad(mesh, a, b, c, d, mat, sub(mid, center))


def add_cyl_y(mesh, base, height, radius, mat, segs=10):
    top_y = base[1] + height
    ring = []
    for i in range(segs):
        a = math.tau * i / segs
        ring.append((math.cos(a) * radius, math.sin(a) * radius))
    for i in range(segs):
        j = (i + 1) % segs
        x0, z0 = ring[i]
        x1, z1 = ring[j]
        a = (base[0] + x0, base[1], base[2] + z0)
        b = (base[0] + x1, base[1], base[2] + z1)
        c = (base[0] + x1, top_y, base[2] + z1)
        d = (base[0] + x0, top_y, base[2] + z0)
        quad(mesh, a, b, c, d, mat, ((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5))
        quad(mesh, a, b, (base[0], base[1], base[2]), a, mat, (0.0, -1.0, 0.0))
        quad(mesh, d, c, (base[0], top_y, base[2]), d, mat, (0.0, 1.0, 0.0))


def add_wheel(mesh, center, radius, width):
    segs = 10
    hw = width * 0.5
    ring = []
    for i in range(segs):
        a = math.tau * i / segs
        ring.append((math.cos(a) * radius, math.sin(a) * radius))
    for i in range(segs):
        j = (i + 1) % segs
        y0, z0 = ring[i]
        y1, z1 = ring[j]
        a = (center[0] - hw, center[1] + y0, center[2] + z0)
        b = (center[0] - hw, center[1] + y1, center[2] + z1)
        c = (center[0] + hw, center[1] + y1, center[2] + z1)
        d = (center[0] + hw, center[1] + y0, center[2] + z0)
        quad(mesh, a, b, c, d, TIRE, (0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
    for side in (-1.0, 1.0):
        face = (side, 0.0, 0.0)
        cx = center[0] + side * hw
        hub_r = radius * 0.45
        for i in range(segs):
            j = (i + 1) % segs
            y0, z0 = ring[i]
            y1, z1 = ring[j]
            a = (cx, center[1] + y0, center[2] + z0)
            b = (cx, center[1] + y1, center[2] + z1)
            m = (cx, center[1], center[2])
            outward = face if side > 0 else (-1.0, 0.0, 0.0)
            # Tire sidewall.
            quad(mesh, a, b, m, a, TIRE, outward)
            ia = (cx, center[1] + y0 * 0.42, center[2] + z0 * 0.42)
            ib = (cx, center[1] + y1 * 0.42, center[2] + z1 * 0.42)
            quad(mesh, ia, ib, m, ia, HUB, outward)
        del hub_r


def map_tris(tris, fn, mat_fn=None):
    out = []
    for a, b, c, mat in tris:
        m = mat if mat_fn is None else mat_fn(mat)
        out.append((fn(a), fn(b), fn(c), m))
    return out


def drop_to_ground(tris):
    low = min(p[1] for tri in tris for p in tri[:3])

    def fn(p):
        return (p[0], p[1] - low, p[2])

    return map_tris(tris, fn)


def project(p, yaw):
    p = rot_y(p, yaw)
    return (dot(p, X) * PPM, -dot(p, Y) * PPM, dot(p, Z))


def raster(tris, yaw, ink=True, gaps=False):
    packed = []
    minx = miny = 1e9
    maxx = maxy = -1e9
    for a, b, c, mat in tris:
        n = cross(sub(b, a), sub(c, a))
        n = norm(rot_y(n, yaw))
        facing = dot(n, Z)
        if facing <= 0.05:
            continue
        lit = dot(n, L)
        shade = lit * 0.78 + facing * 0.22
        if shade < 0.0:
            shade = 0.0
        if shade > 1.0:
            shade = 1.0
        use = mat
        if use == BODY and n[1] < -0.32:
            use = SAND
        pa, pb, pc = project(a, yaw), project(b, yaw), project(c, yaw)
        for p in (pa, pb, pc):
            if p[0] < minx:
                minx = p[0]
            if p[1] < miny:
                miny = p[1]
            if p[0] > maxx:
                maxx = p[0]
            if p[1] > maxy:
                maxy = p[1]
        packed.append((pa, pb, pc, use, int(shade * 255 + 0.5)))
    if not packed:
        return blank()
    pad = 4
    ax = int(math.ceil(-minx)) + pad
    ay = int(math.ceil(-miny)) + pad
    fw = ax + int(math.ceil(maxx)) + pad + 1
    fh = ay + int(math.ceil(maxy)) + pad + 1
    if fw > 420 or fh > 420:
        raise RuntimeError("sprite %dx%d is too big" % (fw, fh))
    zbuf = array_fill(fw * fh, -1.0e30)
    mbuf = bytearray(fw * fh)
    sbuf = bytearray(fw * fh)
    for pa, pb, pc, mat, shade in packed:
        fill_tri(
            pa[0] + ax, pa[1] + ay, pa[2],
            pb[0] + ax, pb[1] + ay, pb[2],
            pc[0] + ax, pc[1] + ay, pc[2],
            mat, shade, zbuf, mbuf, sbuf, fw, fh,
        )
    rgba = bytearray(fw * fh * 4)
    for y in range(fh):
        for x in range(fw):
            i = y * fw + x
            mat = mbuf[i]
            o = i * 4
            if mat == 0:
                continue
            if gaps and mat in GAP:
                if BAYER[y & 3][x & 3] > 12:
                    continue
            r, g, b = color_of(mat, sbuf[i], x, y)
            rgba[o] = r
            rgba[o + 1] = g
            rgba[o + 2] = b
            rgba[o + 3] = 255
    if ink:
        rgba = outline(rgba, fw, fh)
        fw, fh = fw, fh
    return center_on(rgba, fw, fh, ax, ay)


def array_fill(n, value):
    import array
    return array.array("f", [value]) * n


def color_of(mat, shade, x, y):
    ramp = RAMPS[mat]
    if len(ramp) == 1:
        return ramp[0]
    # One flat band per face. The pixels stay solid, like a painted sprite.
    v = (shade / 255.0) * (len(ramp) - 1)
    i = int(v + 0.5)
    if i < 0:
        i = 0
    if i >= len(ramp):
        i = len(ramp) - 1
    return ramp[i]


def fill_tri(x0, y0, z0, x1, y1, z1, x2, y2, z2, mat, shade, zbuf, mbuf, sbuf, w, h):
    minx = int(min(x0, x1, x2))
    maxx = int(max(x0, x1, x2)) + 1
    miny = int(min(y0, y1, y2))
    maxy = int(max(y0, y1, y2)) + 1
    if minx < 0:
        minx = 0
    if miny < 0:
        miny = 0
    if maxx > w:
        maxx = w
    if maxy > h:
        maxy = h
    area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
    if abs(area) < 0.01:
        return
    inv = 1.0 / area
    for y in range(miny, maxy):
        py = y + 0.5
        row = y * w
        for x in range(minx, maxx):
            px = x + 0.5
            w0 = (x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)
            w1 = (x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)
            w2 = (x0 - px) * (y1 - py) - (x1 - px) * (y0 - py)
            if area > 0.0:
                if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
                    continue
            elif w0 > 0.0 or w1 > 0.0 or w2 > 0.0:
                continue
            depth = (w0 * z0 + w1 * z1 + w2 * z2) * inv
            i = row + x
            if depth >= zbuf[i]:
                zbuf[i] = depth
                mbuf[i] = mat
                sbuf[i] = shade


def outline(src, w, h):
    dst = bytearray(src)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            if src[i + 3] != 0:
                continue
            hit = False
            for dy in (-1, 0, 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    xx = x + dx
                    if xx < 0 or xx >= w:
                        continue
                    if src[(yy * w + xx) * 4 + 3] != 0:
                        hit = True
                        break
                if hit:
                    break
            if hit:
                dst[i] = INK[0]
                dst[i + 1] = INK[1]
                dst[i + 2] = INK[2]
                dst[i + 3] = 255
    return dst


def center_on(src, w, h, ax, ay):
    left = ax
    right = w - 1 - ax
    up = ay
    down = h - 1 - ay
    half = max(left, right, up, down)
    if half < 1:
        half = 1
    n = half * 2 + 1
    dst = bytearray(n * n * 4)
    ox = half - ax
    oy = half - ay
    for y in range(h):
        yy = y + oy
        if yy < 0 or yy >= n:
            continue
        for x in range(w):
            xx = x + ox
            if xx < 0 or xx >= n:
                continue
            s = (y * w + x) * 4
            d = (yy * n + xx) * 4
            dst[d:d + 4] = src[s:s + 4]
    return n, n, dst


def blank():
    n = 3
    return n, n, bytearray(n * n * 4)


def write_png(path, w, h, rgba, level=9):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), level))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def save(name, image):
    w, h, rgba = image
    path = os.path.join(OUT, name)
    write_png(path, w, h, rgba)
    opaque = sum(1 for i in range(3, len(rgba), 4) if rgba[i])
    print("%s %dx%d opaque %d" % (name, w, h, opaque))
    return image


def hind_mesh():
    m = []
    add_ellipsoid(m, (0.0, 1.08, -0.15), 0.78, 0.62, 2.25, BODY, 16, 9)
    add_ellipsoid(m, (0.0, 0.98, -2.25), 0.42, 0.36, 0.85, BODY, 12, 7)
    add_ellipsoid(m, (0.0, 1.52, -1.35), 0.46, 0.34, 0.62, GLASS, 12, 7)
    add_ellipsoid(m, (0.0, 1.86, -0.22), 0.50, 0.38, 0.55, GLASS, 12, 7)
    add_box(m, (0.0, 1.66, -0.78), (0.72, 0.16, 0.18), BODY)
    add_box(m, (0.38, 1.62, 0.35), (0.46, 0.36, 1.15), BODY)
    add_box(m, (-0.38, 1.62, 0.35), (0.46, 0.36, 1.15), BODY)
    add_box(m, (0.55, 1.42, 1.05), (0.22, 0.16, 0.28), RUBBER)
    add_box(m, (-0.55, 1.42, 1.05), (0.28, 0.2, 0.36), RUBBER)
    add_box(m, (0.0, 1.16, 1.85), (0.55, 0.46, 1.35), BODY)
    add_box(m, (0.0, 1.22, 2.85), (0.36, 0.32, 0.85), BODY)
    add_box(m, (0.0, 1.28, 3.5), (0.24, 0.24, 0.55), BODY)
    add_box(m, (0.0, 1.95, 3.85), (0.12, 1.15, 0.62), BODY)
    add_box(m, (0.0, 1.32, 3.55), (1.65, 0.1, 0.36), BODY)
    add_box(m, (0.0, 0.58, -2.7), (0.26, 0.2, 0.48), METAL)
    add_box(m, (0.08, 0.54, -3.05), (0.07, 0.07, 0.55), RUBBER)
    add_box(m, (-0.08, 0.54, -3.05), (0.07, 0.07, 0.55), RUBBER)
    add_box(m, (1.5, 1.02, 0.22), (2.05, 0.2, 0.78), BODY, rz=-0.42)
    add_box(m, (-1.5, 1.02, 0.22), (2.05, 0.2, 0.78), BODY, rz=0.42)
    add_box(m, (2.15, 0.62, 0.22), (0.38, 0.34, 1.35), METAL)
    add_box(m, (-2.15, 0.62, 0.22), (0.38, 0.34, 1.35), METAL)
    for side in (1.0, -1.0):
        for z in (-0.2, 0.15, 0.5):
            add_box(m, (side * 2.15, 0.38, z), (0.1, 0.1, 0.22), RUBBER)
        add_box(m, (side * 1.15, 0.82, 0.22), (0.12, 0.36, 0.16), BODY)
    add_box(m, (0.82, 1.1, 0.15), (0.06, 0.36, 0.36), RED)
    add_box(m, (0.0, 2.05, 0.02), (0.16, 1.0, 0.16), RUBBER)
    for z, x in ((0.55, 0.62), (-0.45, 0.62), (-1.7, 0.0)):
        add_wheel(m, (x, 0.30, z), 0.30, 0.16)
        if x != 0.0:
            add_wheel(m, (-x, 0.30, z), 0.30, 0.16)
            add_box(m, (x, 0.48, z), (0.08, 0.36, 0.08), RUBBER)
            add_box(m, (-x, 0.48, z), (0.08, 0.36, 0.08), RUBBER)
    add_box(m, (0.0, 0.5, -1.7), (0.08, 0.4, 0.08), RUBBER)
    for i in range(3):
        add_box(m, (-0.16, 1.95, 3.85), (0.08, 0.72, 0.12), RUBBER, rx=i * 1.047)
    add_box(m, (0.0, 1.55, 2.2), (0.04, 0.28, 0.04), RUBBER)
    return m


def rotor_image(frame):
    """Open ellipse and five blade lines. The middle stays clear so the Hind shows."""
    radius = 4.2
    pts = [project((0.0, 0.0, 0.0), 0.0)]
    for i in range(64):
        ang = math.tau * i / 64.0
        pts.append(project((math.cos(ang) * radius, 0.0, math.sin(ang) * radius), 0.0))
    minx = min(p[0] for p in pts) - 2
    miny = min(p[1] for p in pts) - 2
    maxx = max(p[0] for p in pts) + 2
    maxy = max(p[1] for p in pts) + 2
    pad = 3
    ax = int(math.ceil(-minx)) + pad
    ay = int(math.ceil(-miny)) + pad
    fw = ax + int(math.ceil(maxx)) + pad + 1
    fh = ay + int(math.ceil(maxy)) + pad + 1
    rgba = bytearray(fw * fh * 4)
    ink = (12, 10, 8)
    blur = (48, 44, 36)

    def plot(x, y, col):
        if x < 0 or y < 0 or x >= fw or y >= fh:
            return
        o = (y * fw + x) * 4
        rgba[o] = col[0]
        rgba[o + 1] = col[1]
        rgba[o + 2] = col[2]
        rgba[o + 3] = 255

    def line(x0, y0, x1, y1, col):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            plot(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = err * 2
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def art_px(p):
        return p[0] + ax, p[1] + ay

    ring = []
    for i in range(180):
        ang = math.tau * i / 180.0
        ring.append(art_px(project((math.cos(ang) * radius, 0.0, math.sin(ang) * radius), 0.0)))
    for i, p in enumerate(ring):
        q = ring[(i + 1) % len(ring)]
        line(p[0], p[1], q[0], q[1], blur)
    base = frame * (math.tau / 15.0)
    for i in range(5):
        ang = base + i * math.tau / 5.0
        inner = art_px(project((math.cos(ang) * radius * 0.18, 0.0, math.sin(ang) * radius * 0.18), 0.0))
        outer = art_px(project((math.cos(ang) * radius, 0.0, math.sin(ang) * radius), 0.0))
        line(inner[0], inner[1], outer[0], outer[1], ink)
        line(inner[0] + 1, inner[1], outer[0] + 1, outer[1], ink)
    hub = art_px(project((0.0, 0.0, 0.0), 0.0))
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            plot(int(hub[0]) + dx, int(hub[1]) + dy, (176, 170, 152))
    return center_on(rgba, fw, fh, ax, ay)


def jeep_mesh():
    m = []
    add_box(m, (0.0, 0.58, 0.05), (1.28, 0.36, 2.15), SAND)
    add_box(m, (0.0, 0.78, -0.55), (1.18, 0.22, 0.85), SAND)
    add_box(m, (0.0, 0.95, 0.35), (1.2, 0.48, 0.9), BODY)
    add_box(m, (0.0, 1.05, -0.12), (1.16, 0.36, 0.08), GLASS)
    add_box(m, (0.0, 1.28, 0.55), (1.15, 0.08, 0.08), RUBBER)
    add_box(m, (0.52, 1.05, 0.55), (0.08, 0.42, 0.08), RUBBER)
    add_box(m, (-0.52, 1.05, 0.55), (0.08, 0.42, 0.08), RUBBER)
    add_box(m, (0.0, 1.15, 0.15), (0.08, 0.08, 0.55), RUBBER)
    add_box(m, (0.0, 0.72, 1.15), (0.7, 0.28, 0.12), BODY)
    add_box(m, (0.0, 0.42, -1.2), (1.2, 0.12, 0.12), METAL)
    add_box(m, (0.42, 0.7, -1.05), (0.14, 0.1, 0.08), SAND)
    add_box(m, (-0.42, 0.7, -1.05), (0.14, 0.1, 0.08), SAND)
    for z in (-0.72, 0.72):
        for x in (-0.62, 0.62):
            add_wheel(m, (x, 0.32, z), 0.32, 0.18)
    return m


def technical_mesh():
    m = []
    add_box(m, (0.0, 0.62, 0.15), (1.4, 0.4, 2.7), RUST)
    add_box(m, (0.0, 1.05, -0.85), (1.28, 0.62, 0.95), SAND)
    add_box(m, (0.0, 1.12, -1.35), (1.22, 0.42, 0.08), GLASS)
    add_box(m, (0.0, 0.95, 0.7), (1.3, 0.4, 1.15), BODY)
    add_box(m, (0.0, 1.28, 0.55), (0.7, 0.28, 0.7), BODY)
    add_box(m, (0.0, 1.42, 0.15), (0.1, 0.1, 1.15), RUBBER)
    add_box(m, (0.0, 0.48, -1.55), (1.35, 0.14, 0.16), METAL)
    for z in (-0.95, 0.95):
        for x in (-0.68, 0.68):
            add_wheel(m, (x, 0.34, z), 0.34, 0.18)
    return m


def truck_mesh():
    m = []
    add_box(m, (0.0, 0.95, -1.35), (1.6, 0.95, 1.45), TRUCK)
    add_box(m, (0.0, 1.15, -2.1), (1.45, 0.5, 0.1), GLASS)
    add_box(m, (0.0, 1.15, 0.85), (1.7, 1.15, 2.55), SAND)
    add_box(m, (0.0, 1.78, 0.85), (1.55, 0.12, 2.4), BODY)
    add_box(m, (0.0, 0.4, -2.15), (1.6, 0.16, 0.2), METAL)
    for z in (-1.55, 0.35, 1.45):
        for x in (-0.85, 0.85):
            add_wheel(m, (x, 0.38, z), 0.38, 0.2)
    return m


def roll_mesh(tris):
    def fn(p):
        return rot_z(p, 1.15)

    return drop_to_ground(map_tris(tris, fn))


def wreck_mesh(tris):
    def fn(p):
        return (p[0] * 1.04, p[1] * 0.32 + 0.02, p[2] * 1.02)

    def mats(mat):
        if mat in (GLASS, RED):
            return RUBBER
        if mat in (TIRE, HUB):
            return TIRE
        return SCORCH

    m = drop_to_ground(map_tris(tris, fn, mats))
    add_ellipsoid(m, (0.2, 0.45, 0.1), 0.55, 0.35, 0.7, FIRE, 8, 5)
    return m


def building_mesh(sx, sz, h):
    m = []
    add_box(m, (0.0, h * 0.5, 0.0), (sx, h, sz), ADOBE)
    add_box(m, (0.0, h + 0.16, 0.0), (sx + 0.7, 0.28, sz + 0.7), ROOF)
    add_box(m, (0.0, h + 0.34, 0.0), (sx + 0.15, 0.12, sz + 0.15), ADOBE)
    for i in range(4):
        y = 0.35 + i * (h / 4.0)
        add_box(m, (0.0, y, sz * 0.5 + 0.04), (sx * 0.92, 0.08, 0.08), LINE)
        add_box(m, (sx * 0.5 + 0.04, y, 0.0), (0.08, 0.08, sz * 0.92), LINE)
    add_box(m, (0.0, 0.2, 0.0), (sx + 0.2, 0.28, sz + 0.2), LINE)
    # Door and windows on the two faces the camera sees (+Z and +X).
    add_box(m, (0.0, 0.95, sz * 0.5 + 0.05), (0.9, 1.7, 0.1), LINE)
    add_box(m, (0.0, 0.9, sz * 0.5 + 0.1), (0.62, 1.45, 0.08), ROOF)
    add_box(m, (sx * 0.5 + 0.05, 0.95, 0.0), (0.1, 1.7, 0.9), LINE)
    add_box(m, (sx * 0.5 + 0.1, 0.9, 0.0), (0.08, 1.45, 0.62), ROOF)
    for x in (-sx * 0.28, sx * 0.28):
        add_box(m, (x, h * 0.62, sz * 0.5 + 0.05), (0.78, 0.7, 0.1), SAND)
        add_box(m, (x, h * 0.62, sz * 0.5 + 0.1), (0.5, 0.42, 0.08), GLASS)
        add_box(m, (x, h * 0.62, sz * 0.5 + 0.12), (0.08, 0.42, 0.06), LINE)
    for z in (-sz * 0.22, sz * 0.22):
        add_box(m, (sx * 0.5 + 0.05, h * 0.62, z), (0.1, 0.7, 0.7), SAND)
        add_box(m, (sx * 0.5 + 0.1, h * 0.62, z), (0.08, 0.42, 0.46), GLASS)
    add_box(m, (0.0, 0.12, sz * 0.5 + 0.35), (1.3, 0.12, 0.4), ADOBE)
    add_box(m, (0.2, h + 0.48, -0.2), (0.5, 0.28, 0.5), ROOF)
    return m


def tree_mesh(frame):
    m = []
    shift = (frame - 1) * 0.28
    add_cyl_y(m, (0.0, 0.0, 0.0), 1.7, 0.16, TRUNK, 8)
    add_ellipsoid(m, (shift, 2.55, 0.05), 1.15, 0.85, 1.05, LEAF, 10, 6)
    add_ellipsoid(m, (0.45 + shift, 2.25, 0.25), 0.7, 0.55, 0.65, LEAF2, 8, 5)
    add_ellipsoid(m, (-0.4 + shift, 2.85, -0.2), 0.6, 0.5, 0.55, LEAF, 8, 5)
    return m


def bush_mesh():
    m = []
    add_ellipsoid(m, (0.0, 0.32, 0.0), 0.72, 0.32, 0.62, LEAF2, 10, 6)
    add_ellipsoid(m, (0.2, 0.4, 0.1), 0.4, 0.22, 0.35, LEAF, 8, 5)
    return m


def flag_mesh(frame):
    m = []
    add_cyl_y(m, (0.0, 0.0, 0.0), 2.5, 0.045, RUBBER, 6)
    for i in range(4):
        t = (i + 0.5) / 4.0
        wave = math.sin(t * 3.2 + frame * 1.4) * 0.22
        add_box(
            m,
            (0.22 + t * 0.7, 2.22 - t * 0.18, wave),
            (0.26, 0.46, 0.06),
            RED,
            ry=wave * 0.6,
        )
    return m


def dust_mesh(frame):
    m = []
    for i in range(8):
        ang = math.tau * i / 8.0 + frame * 0.45
        x = math.sin(ang) * 3.05
        z = math.cos(ang) * 3.05
        rad = 0.85 + (i % 3) * 0.15
        add_ellipsoid(m, (x, 0.45, z), rad, 0.38, rad * 0.9, DUST, 8, 4)
    return m


def disk(rgba, w, h, cx, cy, r, color):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        if y < 0 or y >= h:
            continue
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if x < 0 or x >= w:
                continue
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                o = (y * w + x) * 4
                rgba[o:o + 4] = bytes((color[0], color[1], color[2], 255))


def boom_image(frame):
    w = h = 49
    rgba = bytearray(w * h * 4)
    cx = cy = 24
    if frame == 0:
        disk(rgba, w, h, cx, cy, 4, (240, 164, 48))
        disk(rgba, w, h, cx, cy, 2, (255, 244, 200))
    elif frame == 1:
        disk(rgba, w, h, cx, cy, 10, (176, 64, 24))
        disk(rgba, w, h, cx, cy, 6, (240, 164, 48))
        disk(rgba, w, h, cx, cy, 3, (255, 244, 200))
        for ang in range(0, 360, 45):
            a = math.radians(ang)
            disk(rgba, w, h, cx + math.cos(a) * 12, cy + math.sin(a) * 12, 2, (240, 164, 48))
    elif frame == 2:
        disk(rgba, w, h, cx, cy, 16, (92, 32, 18))
        disk(rgba, w, h, cx, cy, 10, (176, 64, 24))
        disk(rgba, w, h, cx + 2, cy - 3, 5, (240, 164, 48))
        disk(rgba, w, h, cx - 6, cy + 4, 3, (58, 56, 50))
    else:
        disk(rgba, w, h, cx, cy, 18, (58, 48, 38))
        disk(rgba, w, h, cx + 4, cy - 2, 7, (92, 32, 18))
        disk(rgba, w, h, cx - 5, cy + 3, 3, (240, 164, 48))
        for y in range(h):
            for x in range(w):
                o = (y * w + x) * 4
                if rgba[o + 3] and BAYER[y & 3][x & 3] > 10:
                    rgba[o:o + 4] = b"\x00\x00\x00\x00"
    rgba = outline(rgba, w, h)
    return center_on(rgba, w, h, cx, cy)


def shadow_image():
    w, h = 73, 49
    rgba = bytearray(w * h * 4)
    cx, cy = 36, 24
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 30.0
            dy = (y - cy) / 16.0
            if dx * dx + dy * dy <= 1.0 and BAYER[y & 3][x & 3] < 9:
                o = (y * w + x) * 4
                rgba[o:o + 4] = bytes((28, 22, 16, 255))
    return w, h, rgba


def bullet_image():
    w = h = 9
    rgba = bytearray(w * h * 4)
    disk(rgba, w, h, 4, 4, 3, (240, 164, 48))
    disk(rgba, w, h, 4, 4, 1.4, (255, 244, 200))
    return w, h, rgba


def tracer_image():
    w, h = 7, 29
    rgba = bytearray(w * h * 4)
    for y in range(h):
        for x in range(1, w - 1):
            if y < 4 or y > h - 5:
                if abs(x - 3) > 1:
                    continue
            o = (y * w + x) * 4
            col = (255, 244, 200) if 8 < y < 20 else (240, 164, 48)
            rgba[o:o + 4] = bytes((col[0], col[1], col[2], 255))
    return w, h, rgba


def px_to_world(px, py, w, h):
    u = (px + 0.5) / w
    v = 1.0 - (py + 0.5) / h
    return (u - 0.5) * 100.0, (v - 0.5) * 100.0


def ground_image():
    w = h = 1200
    rgba = bytearray(w * h * 4)
    hi, mid, lo = (198, 162, 108), (154, 118, 72), (112, 84, 50)
    rut = (78, 56, 34)
    scrub = (58, 82, 30)
    for py in range(h):
        for px in range(w):
            wx, wz = px_to_world(px, py, w, h)
            b = BAYER[py & 3][px & 3]
            if b < 5:
                col = hi
            elif b < 11:
                col = mid
            else:
                col = lo
            cell = ((px // 24) * 13 + (py // 24) * 7) & 15
            if cell > 12 and b > 8:
                col = lo
            dx = abs(wx - 2.0)
            dz = abs(wz + 6.0)
            track = None
            if dx < 1.2:
                track = dx
            if dz < 1.2 and (track is None or dz < track):
                track = dz
            if track is not None and abs(track - 0.46) < 0.14:
                col = rut
            elif ((px // 6) * 3 + (py // 6) * 5) % 37 == 0 and b < 6:
                col = scrub
            o = (py * w + px) * 4
            rgba[o] = col[0]
            rgba[o + 1] = col[1]
            rgba[o + 2] = col[2]
            rgba[o + 3] = 255
    # Contact marks under buildings and trees, in world meters.
    marks = (
        (-16.0, -16.0, 5.2, 4.0),
        (14.0, -18.0, 4.6, 5.2),
        (-2.0, 12.0, 4.0, 4.0),
    )
    trees = (
        (-10.0, -22.0), (20.0, -8.0), (-24.0, 2.0), (-14.0, 20.0),
        (-22.0, 16.0), (22.0, 14.0), (-6.0, 2.0), (16.0, 6.0),
    )
    for py in range(h):
        for px in range(w):
            wx, wz = px_to_world(px, py, w, h)
            hit = False
            for mx, mz, rx, rz in marks:
                if ((wx - mx) / rx) ** 2 + ((wz - mz) / rz) ** 2 <= 1.0:
                    hit = True
                    break
            if not hit:
                for mx, mz in trees:
                    if (wx - mx) ** 2 + (wz - mz) ** 2 < 1.6:
                        hit = True
                        break
            if hit and BAYER[py & 3][px & 3] < 8:
                o = (py * w + px) * 4
                rgba[o] = max(0, rgba[o] - 36)
                rgba[o + 1] = max(0, rgba[o + 1] - 30)
                rgba[o + 2] = max(0, rgba[o + 2] - 22)
    return w, h, rgba


def upscale(image, n, bg):
    w, h, rgba = image
    ow, oh = w * n, h * n
    out = bytearray(ow * oh * 4)
    for y in range(h):
        for x in range(w):
            s = (y * w + x) * 4
            if rgba[s + 3] == 0:
                pix = bg
            else:
                pix = rgba[s:s + 4]
            for dy in range(n):
                for dx in range(n):
                    d = ((y * n + dy) * ow + (x * n + dx)) * 4
                    out[d:d + 4] = pix
    return ow, oh, out


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


def world_screen(wx, wy, wz, cx, cy):
    sx = (wx * X[0] + wy * X[1] + wz * X[2]) * PPM
    sy = -(wx * Y[0] + wy * Y[1] + wz * Y[2]) * PPM
    return int(round(cx + sx)), int(round(cy + sy))


def compose_preview(sprites):
    """One camera frame of the painted parts, at 4 screen pixels per art pixel."""
    aw, ah = 200, 150
    scale = 4
    dw, dh = aw * scale, ah * scale
    bg = (168, 132, 82, 255)
    small = bytearray(aw * ah * 4)
    for i in range(aw * ah):
        small[i * 4:i * 4 + 4] = bytes(bg)
    cx, cy = 78, 88
    items = [
        (sprites["building_2.png"], -4.0, 0.0, -3.0),
        (sprites["tree_0.png"], 5.5, 0.0, -2.0),
        (sprites["flag_1.png"], -2.2, 0.0, 2.4),
        (sprites["bush.png"], 2.2, 0.0, 3.6),
        (sprites["jeep_0.png"], 3.4, 0.0, 1.6),
        (sprites["shadow.png"], 0.7, 0.0, -0.5),
        (sprites["hind_0.png"], 0.0, 0.0, 0.0),
        (sprites["rotor_0.png"], MAST[0], MAST[1], MAST[2]),
        (sprites["dust_0.png"], 0.0, 0.0, 0.0),
    ]
    items.sort(key=lambda it: it[1] * Z[0] + it[2] * Z[1] + it[3] * Z[2])
    for image, wx, wy, wz in items:
        px, py = world_screen(wx, wy, wz, cx, cy)
        blit(small, aw, ah, image, px, py)
    return upscale((aw, ah, small), scale, bg)


def facing_strip(images):
    pad = 4
    h = max(im[1] for im in images)
    w = sum(im[0] + pad for im in images) + pad
    rgba = bytearray(w * h * 4)
    bg = (168, 132, 82, 255)
    for i in range(w * h):
        rgba[i * 4:i * 4 + 4] = bytes(bg)
    x = pad
    for im in images:
        blit(rgba, w, h, im, x + im[0] // 2, h // 2)
        x += im[0] + pad
    return upscale((w, h, rgba), 3, bg)


def main():
    os.makedirs(OUT, exist_ok=True)
    kept = {}
    for i in range(8):
        yaw = math.radians(i * 45.0)
        kept["hind_%d.png" % i] = save("hind_%d.png" % i, raster(hind_mesh(), yaw))
        kept["jeep_%d.png" % i] = save("jeep_%d.png" % i, raster(jeep_mesh(), yaw))
        kept["technical_%d.png" % i] = save("technical_%d.png" % i, raster(technical_mesh(), yaw))
        kept["truck_%d.png" % i] = save("truck_%d.png" % i, raster(truck_mesh(), yaw))
    save("jeep_tip.png", raster(roll_mesh(jeep_mesh()), 0.0))
    save("jeep_wreck.png", raster(wreck_mesh(jeep_mesh()), 0.0))
    save("technical_tip.png", raster(roll_mesh(technical_mesh()), 0.0))
    save("technical_wreck.png", raster(wreck_mesh(technical_mesh()), 0.0))
    for i in range(3):
        kept["rotor_%d.png" % i] = save("rotor_%d.png" % i, rotor_image(i))
        save("tree_%d.png" % i, raster(tree_mesh(i), 0.0))
        save("flag_%d.png" % i, raster(flag_mesh(i), 0.0))
        save("dust_%d.png" % i, raster(dust_mesh(i), 0.0, ink=False, gaps=True))
        save("boom_%d.png" % i, boom_image(i))
    save("boom_3.png", boom_image(3))
    buildings = ((8.0, 6.0, 4.2), (7.0, 8.0, 5.0), (6.0, 6.0, 3.6))
    for i, (sx, sz, h) in enumerate(buildings):
        image = raster(building_mesh(sx, sz, h), 0.0)
        save("building_%d.png" % i, image)
        if i == 2:
            kept["building_2.png"] = image
    kept["tree_0.png"] = raster(tree_mesh(0), 0.0)
    save("tree_0.png", kept["tree_0.png"])
    kept["bush.png"] = save("bush.png", raster(bush_mesh(), 0.0))
    kept["flag_1.png"] = raster(flag_mesh(1), 0.0)
    save("flag_1.png", kept["flag_1.png"])
    kept["dust_0.png"] = raster(dust_mesh(0), 0.0, ink=False, gaps=True)
    save("dust_0.png", kept["dust_0.png"])
    kept["shadow.png"] = save("shadow.png", shadow_image())
    save("bullet.png", bullet_image())
    save("tracer.png", tracer_image())
    print("ground")
    gw, gh, gr = ground_image()
    write_png(os.path.join(OUT, "ground.png"), gw, gh, gr, 1)
    print("ground %dx%d" % (gw, gh))
    layout = (
        '{\n  "ppm": 12,\n  "pixel_size": 0.0833333333333,\n'
        '  "mast": [%.4f, %.4f, %.4f],\n'
        '  "travel": [%.6f, %.6f, %.6f]\n}\n'
    ) % (MAST[0], MAST[1], MAST[2], TRAVEL[0], TRAVEL[1], TRAVEL[2])
    with open(os.path.join(OUT, "layout.json"), "w", encoding="utf-8") as f:
        f.write(layout)
    preview = os.path.join("/tmp", "hind-preview")
    os.makedirs(preview, exist_ok=True)
    scene = compose_preview(kept)
    write_png(os.path.join(preview, "scene.png"), scene[0], scene[1], scene[2], 1)
    strip = facing_strip([kept["hind_%d.png" % i] for i in range(8)])
    write_png(os.path.join(preview, "hind-faces.png"), strip[0], strip[1], strip[2], 1)
    jeep = facing_strip([kept["jeep_%d.png" % i] for i in range(8)])
    write_png(os.path.join(preview, "jeep-faces.png"), jeep[0], jeep[1], jeep[2], 1)
    one = upscale(kept["hind_0.png"], 4, (168, 132, 82, 255))
    write_png(os.path.join(preview, "hind-0.png"), one[0], one[1], one[2], 1)
    bld = upscale(kept["building_2.png"], 3, (168, 132, 82, 255))
    write_png(os.path.join(preview, "building.png"), bld[0], bld[1], bld[2], 1)
    truck = facing_strip([raster(truck_mesh(), math.radians(i * 45.0)) for i in (0, 2, 4)])
    write_png(os.path.join(preview, "truck-faces.png"), truck[0], truck[1], truck[2], 1)
    crop_w, crop_h = 180, 140
    crop = bytearray(crop_w * crop_h * 4)
    ox = gw // 2 - crop_w // 2
    oy = gh // 2 - crop_h // 2
    for y in range(crop_h):
        src = ((oy + y) * gw + ox) * 4
        dst = y * crop_w * 4
        crop[dst:dst + crop_w * 4] = gr[src:src + crop_w * 4]
    ground_view = upscale((crop_w, crop_h, crop), 3, (0, 0, 0, 255))
    write_png(os.path.join(preview, "ground.png"), ground_view[0], ground_view[1], ground_view[2], 1)
    print("preview", preview)


if __name__ == "__main__":
    main()

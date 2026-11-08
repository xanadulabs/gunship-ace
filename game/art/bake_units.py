#!/usr/bin/env python3
"""Paint the campaign units, pickups and effects with the bake_sprites camera.

Run from anywhere: python3 game/art/bake_units.py
Writes game/art/sprites/. Does not touch the Hind or the original slice art.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake_sprites as B  # noqa: E402
from bake_sprites import (  # noqa: E402
    add_box, add_ellipsoid, add_cyl_y, add_wheel, raster, save, disk, outline, center_on,
    BODY, SAND, GLASS, METAL, RUBBER, RED, RUST, TRUCK, ADOBE, ROOF, LEAF, LEAF2,
    LINE, TIRE, HUB, DUST, FIRE, SCORCH,
)

# The painted slice art sits at about 22 px per meter, not the 12 the old bake used.
B.PPM = 22

# Extra ramps for the campaign.
CLOTH = 30
SKIN = 31
WHITE = 32
ORANGE = 33
CONCRETE = 34
B.RAMPS[CLOTH] = ((132, 128, 84), (92, 90, 56), (56, 54, 34))
B.RAMPS[SKIN] = ((208, 158, 112), (160, 112, 76), (104, 70, 46))
B.RAMPS[WHITE] = ((240, 234, 214), (196, 188, 166), (138, 130, 112))
B.RAMPS[ORANGE] = ((252, 156, 52), (214, 104, 30), (140, 60, 20))
B.RAMPS[CONCRETE] = ((186, 178, 158), (136, 128, 112), (88, 82, 72))


def grain(image, amount=7):
    """Break the flat bands with a fixed hash so the art sits next to the painted slice."""
    w, h, rgba = image
    out = bytearray(rgba)
    for y in range(h):
        for x in range(w):
            o = (y * w + x) * 4
            if out[o + 3] == 0:
                continue
            r, g, b = out[o], out[o + 1], out[o + 2]
            if r < 30 and g < 26 and b < 20:
                continue  # Keep the ink line.
            n = ((x * 73856093) ^ (y * 19349663)) & 15
            d = (n - 7) * amount // 8
            out[o] = max(0, min(255, r + d))
            out[o + 1] = max(0, min(255, g + d))
            out[o + 2] = max(0, min(255, b + d))
    return w, h, out


def put(name, tris, yaw=0.0, ink=True, gaps=False):
    return save(name, grain(raster(tris, yaw, ink, gaps)))


def faces(stem, mesh_fn):
    for i in range(8):
        put("%s_%d.png" % (stem, i), mesh_fn(), math.radians(i * 45.0))


def tracks(m, length, gauge, height=0.55, width=0.5):
    for side in (-1.0, 1.0):
        add_box(m, (side * gauge, height * 0.5, 0.0), (width, height, length), RUBBER)
        for k in range(5):
            z = -length * 0.4 + k * length * 0.2
            add_box(m, (side * (gauge + width * 0.5 + 0.01), height * 0.45, z), (0.04, 0.3, 0.3), HUB)


def tank_mesh():
    m = []
    tracks(m, 5.6, 1.25)
    add_box(m, (0.0, 0.8, 0.1), (2.3, 0.55, 5.2), TRUCK)
    add_box(m, (0.0, 0.62, -2.6), (2.1, 0.3, 0.3), TRUCK, rx=0.5)
    add_ellipsoid(m, (0.0, 1.35, 0.4), 1.15, 0.45, 1.25, TRUCK, 12, 6)
    add_box(m, (0.0, 1.42, -2.0), (0.2, 0.2, 3.0), METAL)
    add_box(m, (0.0, 1.42, -3.45), (0.3, 0.3, 0.3), METAL)
    add_cyl_y(m, (0.45, 1.7, 0.7), 0.18, 0.28, TRUCK, 8)
    add_box(m, (0.0, 1.15, 2.55), (1.8, 0.3, 0.3), RUST)
    return m


def zsu_mesh():
    m = []
    tracks(m, 5.0, 1.15)
    add_box(m, (0.0, 0.85, 0.0), (2.1, 0.6, 4.8), BODY)
    add_box(m, (0.0, 1.5, 0.3), (1.9, 0.75, 2.0), BODY)
    for x in (-0.45, -0.15, 0.15, 0.45):
        add_box(m, (x, 1.65, -1.6), (0.1, 0.1, 2.0), METAL)
    add_box(m, (0.0, 2.15, 1.0), (0.9, 0.5, 0.1), METAL, rx=-0.4)
    add_box(m, (0.0, 1.95, 1.05), (0.12, 0.3, 0.12), RUBBER)
    return m


def aaa_mesh():
    m = []
    for k in range(10):
        a = math.tau * k / 10.0
        add_ellipsoid(m, (math.sin(a) * 2.0, 0.3, math.cos(a) * 2.0), 0.6, 0.32, 0.45, SAND, 8, 4)
        add_ellipsoid(m, (math.sin(a + 0.3) * 2.0, 0.72, math.cos(a + 0.3) * 2.0), 0.55, 0.28, 0.42, SAND, 8, 4)
    add_box(m, (0.0, 0.5, 0.0), (1.4, 0.4, 1.6), BODY)
    add_box(m, (0.0, 0.95, 0.1), (0.9, 0.5, 0.9), BODY)
    for x in (-0.22, 0.22):
        add_box(m, (x, 1.25, -1.1), (0.1, 0.1, 2.2), METAL, rx=-0.35)
    add_box(m, (0.6, 1.05, 0.5), (0.3, 0.3, 0.4), RUBBER)
    return m


def sam_mesh():
    m = []
    add_box(m, (0.0, 0.3, 0.0), (3.0, 0.6, 3.0), CONCRETE)
    add_cyl_y(m, (0.0, 0.6, 0.0), 0.6, 0.6, TRUCK, 10)
    add_box(m, (0.0, 1.4, 0.0), (1.3, 0.3, 0.8), TRUCK)
    for x in (-0.45, 0.45):
        add_box(m, (x, 1.95, -0.3), (0.28, 0.28, 3.2), WHITE, rx=0.55)
        add_box(m, (x, 2.85, -1.75), (0.22, 0.22, 0.4), RED, rx=0.55)
    return m


def radar_mesh(frame):
    m = []
    add_box(m, (0.0, 0.9, 0.0), (3.4, 1.8, 3.0), CONCRETE)
    add_box(m, (0.0, 1.85, 0.0), (3.6, 0.12, 3.2), LINE)
    add_box(m, (0.0, 0.8, 1.52), (0.8, 1.4, 0.06), LINE)
    add_cyl_y(m, (0.0, 1.8, 0.0), 1.6, 0.14, METAL, 8)
    a = frame * math.pi / 4.0
    # Dish: a tilted frame of slats, spun about the mast.
    for k in range(5):
        off = (k - 2) * 0.5
        cx, cz = math.cos(a) * off, -math.sin(a) * off
        add_box(m, (cx, 3.7, cz), (0.48, 1.3, 0.08), WHITE, rx=0.35, ry=a)
    add_box(m, (math.sin(a) * 0.4, 3.4, math.cos(a) * 0.4), (0.1, 0.1, 0.8), METAL, ry=a)
    return m


def depot_mesh():
    m = []
    add_box(m, (0.0, 0.15, 0.0), (6.4, 0.3, 4.2), CONCRETE)
    for x in (-1.6, 1.6):
        add_cyl_y(m, (x, 0.3, 0.0), 2.4, 1.35, WHITE, 14)
        add_cyl_y(m, (x, 2.7, 0.0), 0.12, 1.1, METAL, 14)
        add_box(m, (x, 1.4, 1.38), (1.2, 0.3, 0.05), RED)
    add_box(m, (0.0, 2.3, 0.0), (1.4, 0.18, 0.18), METAL)
    return m


def bunker_mesh():
    m = []
    add_box(m, (0.0, 0.9, 0.0), (6.0, 1.8, 5.0), CONCRETE)
    add_box(m, (0.0, 1.85, 0.0), (6.4, 0.15, 5.4), LINE)
    add_box(m, (0.0, 2.05, 0.0), (5.6, 0.3, 4.6), CONCRETE)
    add_box(m, (0.0, 1.15, 2.52), (3.0, 0.32, 0.06), LINE)
    add_box(m, (2.0, 0.8, 2.52), (0.9, 1.5, 0.08), RUST)
    for k in range(6):
        x = -2.6 + k * 1.04
        add_ellipsoid(m, (x, 0.3, 3.1), 0.55, 0.3, 0.32, SAND, 8, 4)
    add_cyl_y(m, (-2.0, 2.2, -1.5), 3.0, 0.05, RUBBER, 5)
    add_box(m, (-1.55, 4.8, -1.5), (0.9, 0.5, 0.05), RED)
    return m


def soldier_mesh(frame, pose="rifle"):
    m = []
    swing = 0.18 if frame == 1 else -0.18
    for side in (-1.0, 1.0):
        add_box(m, (side * 0.11, 0.42, side * swing), (0.14, 0.84, 0.16), CLOTH)
        add_box(m, (side * 0.11, 0.04, side * swing - 0.04), (0.15, 0.08, 0.26), RUBBER)
    add_box(m, (0.0, 1.15, 0.0), (0.46, 0.66, 0.28), CLOTH)
    add_ellipsoid(m, (0.0, 1.62, 0.0), 0.14, 0.16, 0.14, SKIN, 6, 4)
    add_ellipsoid(m, (0.0, 1.72, 0.0), 0.16, 0.08, 0.16, BODY, 6, 3)
    if pose == "rifle":
        add_box(m, (0.2, 1.2, -0.35), (0.06, 0.08, 0.9), RUBBER)
        add_box(m, (0.25, 1.15, -0.12), (0.1, 0.36, 0.1), CLOTH, rx=0.8)
    return m


def pilot_mesh(frame):
    m = []
    for side in (-1.0, 1.0):
        add_box(m, (side * 0.11, 0.42, 0.0), (0.14, 0.84, 0.16), ORANGE)
    add_box(m, (0.0, 1.15, 0.0), (0.46, 0.66, 0.28), ORANGE)
    add_ellipsoid(m, (0.0, 1.64, 0.0), 0.16, 0.18, 0.16, WHITE, 6, 4)
    lift = 0.9 if frame == 0 else 0.5
    for side in (-1.0, 1.0):
        add_box(m, (side * 0.36, 1.35 + lift * 0.4, 0.0), (0.1, 0.7, 0.1), ORANGE, rz=-side * lift)
    return m


def drums_mesh():
    m = []
    for x, z in ((-0.35, -0.3), (0.35, -0.3), (0.0, 0.32)):
        add_cyl_y(m, (x, 0.0, z), 0.95, 0.32, RED, 10)
        add_cyl_y(m, (x, 0.32, z), 0.06, 0.33, LINE, 10)
        add_cyl_y(m, (x, 0.95, z), 0.03, 0.2, METAL, 6)
    return m


def crate_mesh(kind):
    m = []
    body = BODY if kind == "ammo" else WHITE
    add_box(m, (0.0, 0.35, 0.0), (1.3, 0.7, 0.9), body)
    add_box(m, (0.0, 0.35, 0.0), (1.34, 0.12, 0.94), LINE)
    if kind == "ammo":
        for x in (-0.3, 0.0, 0.3):
            add_box(m, (x, 0.75, 0.0), (0.12, 0.12, 0.6), HUB)
    else:
        add_box(m, (0.0, 0.71, 0.0), (0.7, 0.04, 0.2), RED)
        add_box(m, (0.0, 0.71, 0.0), (0.2, 0.04, 0.7), RED)
        add_box(m, (0.0, 0.45, 0.46), (0.5, 0.15, 0.04), RED)
    return m


def wreck(tris, fire=True):
    m = B.wreck_mesh(tris)
    if not fire:
        m = [t for t in m if t[3] != FIRE]
    return m


def rubble_mesh(sx, sz):
    m = []
    for k in range(14):
        a = k * 2.399
        r = (k % 5) / 5.0
        x = math.cos(a) * r * sx * 0.45
        z = math.sin(a) * r * sz * 0.45
        add_box(m, (x, 0.2, z), (0.9 - r * 0.3, 0.4 + (k % 3) * 0.15, 0.7), CONCRETE if k % 2 else SCORCH, ry=a)
    return m


def flat_image(w, h, painter):
    rgba = bytearray(w * h * 4)
    painter(rgba, w, h)
    return w, h, rgba


def lz_image():
    def paint(rgba, w, h):
        cx, cy = w // 2, h // 2
        for y in range(h):
            for x in range(w):
                d = math.hypot(x - cx, y - cy)
                o = (y * w + x) * 4
                col = None
                if d < cx - 1:
                    col = (150, 120, 80) if B.BAYER[y & 3][x & 3] < 12 else (132, 104, 68)
                if cx - 7 < d < cx - 1:
                    col = (236, 226, 196)
                hx, hy = abs(x - cx), abs(y - cy)
                if hy < 20 and 10 < hx < 17:
                    col = (236, 226, 196)
                if hx < 13 and hy < 3:
                    col = (236, 226, 196)
                if col:
                    rgba[o:o + 4] = bytes((col[0], col[1], col[2], 255))
    return flat_image(97, 97, paint)


def puff_image(frame, color, size):
    w = h = size
    rgba = bytearray(w * h * 4)
    c = size // 2
    r = c * (0.45 + frame * 0.18)
    disk(rgba, w, h, c, c, r, color)
    disk(rgba, w, h, c - r * 0.3, c - r * 0.3, r * 0.55, tuple(min(255, v + 26) for v in color))
    for y in range(h):
        for x in range(w):
            o = (y * w + x) * 4
            if rgba[o + 3] and B.BAYER[y & 3][x & 3] < frame * 4:
                rgba[o:o + 4] = b"\x00\x00\x00\x00"
    return w, h, rgba


def streak_image(length, core, edge):
    w, h = 5, length
    rgba = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            if (y < 2 or y > h - 3) and x != 2:
                continue
            o = (y * w + x) * 4
            col = core if 1 <= x <= 3 and y > h // 3 else edge
            rgba[o:o + 4] = bytes((col[0], col[1], col[2], 255))
    return w, h, rgba


def flash_image():
    w = h = 15
    rgba = bytearray(w * h * 4)
    disk(rgba, w, h, 7, 7, 6, (240, 164, 48))
    disk(rgba, w, h, 7, 7, 3.2, (255, 244, 200))
    return w, h, rgba


def main():
    os.makedirs(B.OUT, exist_ok=True)
    faces("tank", tank_mesh)
    faces("zsu", zsu_mesh)
    faces("aaa", aaa_mesh)
    faces("sam", sam_mesh)
    for i in range(8):
        put("soldier_%d_0.png" % i, soldier_mesh(0), math.radians(i * 45.0))
        put("soldier_%d_1.png" % i, soldier_mesh(1), math.radians(i * 45.0))
    put("soldier_down.png", B.drop_to_ground(B.map_tris(soldier_mesh(0), lambda p: B.rot_x(p, -1.45))))
    for i in range(2):
        put("pilot_%d.png" % i, pilot_mesh(i), math.radians(30.0))
    for i in range(4):
        put("radar_%d.png" % i, radar_mesh(i))
    put("depot.png", depot_mesh())
    put("bunker.png", bunker_mesh())
    put("drums.png", drums_mesh())
    put("crate_ammo.png", crate_mesh("ammo"))
    put("crate_armor.png", crate_mesh("armor"))
    put("tank_wreck.png", wreck(tank_mesh()))
    put("zsu_wreck.png", wreck(zsu_mesh()))
    put("aaa_wreck.png", wreck(aaa_mesh()))
    put("sam_wreck.png", wreck(sam_mesh()))
    put("truck_wreck.png", wreck(B.truck_mesh()))
    put("truck_tip.png", B.roll_mesh(B.truck_mesh()))
    put("radar_wreck.png", rubble_mesh(3.4, 3.0))
    put("depot_wreck.png", rubble_mesh(6.4, 4.2))
    put("bunker_wreck.png", rubble_mesh(6.0, 5.0))
    put("building_wreck.png", rubble_mesh(7.0, 6.0))
    save("lz.png", lz_image())
    for f in range(3):
        save("smoke_%d.png" % f, puff_image(f, (96, 88, 78), 25))
        save("puff_%d.png" % f, puff_image(f, (226, 206, 160), 17))
    save("rocket.png", streak_image(13, (255, 244, 200), (240, 120, 40)))
    save("missile.png", streak_image(17, (255, 255, 255), (200, 60, 40)))
    save("flash.png", flash_image())
    save("round.png", streak_image(9, (255, 250, 210), (250, 200, 80)))


if __name__ == "__main__":
    main()

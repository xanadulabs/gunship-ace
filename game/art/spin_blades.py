#!/usr/bin/env python3
"""Bake twelve rotor frames for each Hind sprite.

Five equal main-rotor blades turn about the mast. Three tail-rotor blades
turn about the boom tip. The tail is bent up so it clears the wheels.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_look import load_rgba, write_png
import spin_rays

OUT = "/tmp/hind-spin-debug"
SPRITES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sprites")


def mask_of(rgba, w, h, cutoff):
    mask = bytearray(w * h)
    for i in range(w * h):
        mask[i] = 1 if rgba[i * 4 + 3] > cutoff else 0
    return mask


def erode(mask, w, h, radius):
    r2 = radius * radius
    out = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if not mask[y * w + x]:
                continue
            keep = True
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    keep = False
                    break
                row = yy * w
                for dx in range(-radius, radius + 1):
                    if dx * dx + dy * dy > r2:
                        continue
                    xx = x + dx
                    if xx < 0 or xx >= w or not mask[row + xx]:
                        keep = False
                        break
                if not keep:
                    break
            if keep:
                out[y * w + x] = 1
    return out


def dilate(mask, w, h, radius):
    r2 = radius * radius
    out = bytearray(mask)
    for y in range(h):
        row = y * w
        for x in range(w):
            if not mask[row + x]:
                continue
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                for dx in range(-radius, radius + 1):
                    if dx * dx + dy * dy > r2:
                        continue
                    xx = x + dx
                    if 0 <= xx < w:
                        out[yy * w + xx] = 1
    return out


def components(mask, w, h):
    seen = bytearray(w * h)
    groups = []
    for start, on in enumerate(mask):
        if not on or seen[start]:
            continue
        stack = [start]
        seen[start] = 1
        group = []
        while stack:
            i = stack.pop()
            group.append(i)
            y, x = divmod(i, w)
            for ny in (y - 1, y, y + 1):
                if ny < 0 or ny >= h:
                    continue
                base = ny * w
                for nx in (x - 1, x, x + 1):
                    if nx < 0 or nx >= w:
                        continue
                    j = base + nx
                    if mask[j] and not seen[j]:
                        seen[j] = 1
                        stack.append(j)
        groups.append(group)
    return groups


def stats(group, w):
    xs = [i % w for i in group]
    ys = [i // w for i in group]
    n = float(len(group))
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs) / n
    syy = sum((y - my) ** 2 for y in ys) / n
    sxy = sum((xs[k] - mx) * (ys[k] - my) for k in range(len(group))) / n
    ang = 0.5 * math.atan2(2.0 * sxy, sxx - syy)
    return {
        "mx": mx,
        "my": my,
        "dx": math.cos(ang),
        "dy": math.sin(ang),
        "span": max(max(xs) - min(xs), max(ys) - min(ys)),
        "group": group,
    }


def body_center(mask, w):
    sx = sy = n = 0
    for i, on in enumerate(mask):
        if on:
            y, x = divmod(i, w)
            sx += x
            sy += y
            n += 1
    if not n:
        return 0.0, 0.0
    return sx / n, sy / n


def line_hub(cands):
    a00 = a01 = a11 = b0 = b1 = 0.0
    for c in cands:
        weight = float(c["span"]) ** 2
        nx, ny = -c["dy"], c["dx"]
        k = c["mx"] * nx + c["my"] * ny
        a00 += weight * nx * nx
        a01 += weight * nx * ny
        a11 += weight * ny * ny
        b0 += weight * nx * k
        b1 += weight * ny * k
    det = a00 * a11 - a01 * a01
    if abs(det) < 1e-4:
        return None
    return (b0 * a11 - a01 * b1) / det, (a00 * b1 - a01 * b0) / det


def line_gap(c, hx, hy):
    return abs((hx - c["mx"]) * c["dy"] - (hy - c["my"]) * c["dx"])


def nearest(group, w, hx, hy):
    best = 1e9
    for i in group:
        y, x = divmod(i, w)
        best = min(best, (x - hx) ** 2 + (y - hy) ** 2)
    return math.sqrt(best)


def separate(rgba, w, h):
    # Opening removes arms thinner than the fuselage. Those arms are the blades
    # that stand out against the sky. Paint that lies on the roof stays put.
    solid = mask_of(rgba, w, h, 80)
    core = erode(solid, w, h, 4)
    opened = dilate(core, w, h, 4)
    thin = bytearray(1 if solid[i] and not opened[i] else 0 for i in range(w * h))
    groups = components(thin, w, h)
    ray_hub = spin_rays.find_hub(solid, w, h)
    _bx, bcy = body_center(core, w)
    cands = []
    for group in groups:
        if len(group) < 30:
            continue
        st = stats(group, w)
        if st["span"] < 11:
            continue
        cands.append(st)
    voters = [c for c in cands if c["span"] >= 18 and c["my"] < bcy - 4]
    line = line_hub(voters[:4]) if len(voters) >= 3 else None
    tight = 0
    if line is not None:
        for c in voters:
            if line_gap(c, line[0], line[1]) < 4.0:
                tight += 1
    # Three arms that cross one point are the mast. The ray search is the
    # fallback when those arms do not agree, and the only answer when it
    # cannot see four arms.
    if line is not None and tight >= 3 and (ray_hub is None or math.hypot(line[0] - ray_hub[0], line[1] - ray_hub[1]) < 28.0):
        hub = line
    else:
        hub = ray_hub if ray_hub is not None else line
    blade = bytearray(w * h)
    kept = 0
    if hub is None:
        return blade, hub, 0, 0.0
    hx, hy = hub
    for c in cands:
        if c["my"] > hy + 36:
            continue
        if c["my"] < hy - 48:
            continue
        gap = line_gap(c, hx, hy)
        if gap > 10.0:
            continue
        # A wing does not aim at the mast. A blade does, even when the roof
        # covers the inner half and the nearest sky pixel is far out.
        if nearest(c["group"], w, hx, hy) > 62.0:
            continue
        kept += 1
        for i in c["group"]:
            blade[i] = 1
    soft = mask_of(rgba, w, h, 12)
    fringe = dilate(blade, w, h, 1)
    for i in range(w * h):
        if fringe[i] and soft[i] and not opened[i]:
            blade[i] = 1
    # One stray pixel must not stretch the disc and fling a blade off the mast.
    dists = []
    for i, on in enumerate(blade):
        if not on:
            continue
        y, x = divmod(i, w)
        dists.append(((x - hx) ** 2 + (y - hy) ** 2, i))
    if len(dists) > 20:
        dists.sort()
        limit = dists[int(len(dists) * 0.94)][0] * 1.08
        for dist, i in dists:
            if dist > limit:
                blade[i] = 0
    return blade, hub, kept, hy


def extents(blade, w, hub):
    hx, hy = hub
    rx = ry = 0.0
    for i, on in enumerate(blade):
        if not on:
            continue
        y, x = divmod(i, w)
        rx = max(rx, abs(x - hx))
        ry = max(ry, abs(y - hy))
    return max(8.0, rx + 3.0), max(6.0, ry + 3.0)


# Image y grows downward. The tail is the end opposite the nose on that facing.
TAIL_DIR = (
    (-0.7071, 0.7071),
    (0.0, 1.0),
    (0.7071, 0.7071),
    (1.0, 0.0),
    (0.7071, -0.7071),
    (0.0, -1.0),
    (-0.7071, -0.7071),
    (-1.0, 0.0),
)


def _facing(stem):
    return int(stem.split("_")[1])


def raise_tail(rgba, w, h, blade, facing):
    # The pivot is the wheel contact. Pixels below that line go through the
    # sand because the card faces a camera that looks down. Bend the tail up
    # around the fuselage so the boom and the tail rotor clear the wheels.
    dx, dy = TAIL_DIR[facing]
    body = []
    for i in range(w * h):
        if rgba[i * 4 + 3] > 80 and not blade[i]:
            y, x = divmod(i, w)
            body.append((x, y))
    if len(body) < 30:
        return bytearray(rgba), 0.0, (0.0, 0.0)
    cx = sum(p[0] for p in body) / len(body)
    cy = sum(p[1] for p in body) / len(body)
    scored = [((x - cx) * dx + (y - cy) * dy, x, y) for x, y in body]
    t_max = max(item[0] for item in scored)
    joint = t_max * 0.42
    wheel_y = 0
    for t, _x, y in scored:
        if t < joint and y > wheel_y:
            wheel_y = y
    if wheel_y == 0:
        wheel_y = int(h * 0.5)
    target = min(wheel_y - 8, h * 0.5 - 6)
    span = max(1.0, t_max - joint)
    lift = 0.0
    for t, _x, y in scored:
        if t <= joint:
            continue
        frac = (t - joint) / span
        if frac > 0.08 and y > target:
            lift = max(lift, (y - target) / frac)
    lift = min(lift, 42.0)
    if lift < 1.0:
        return bytearray(rgba), 0.0, (cx, cy)
    out = bytearray(w * h * 4)
    for y in range(h):
        row = y * w
        for x in range(w):
            i = row + x
            if blade[i]:
                out[i * 4:i * 4 + 4] = rgba[i * 4:i * 4 + 4]
                continue
            t = (x - cx) * dx + (y - cy) * dy
            if t <= joint:
                out[i * 4:i * 4 + 4] = rgba[i * 4:i * 4 + 4]
                continue
            frac = max(0.0, min(1.0, (t - joint) / span))
            iy = int(round(y + frac * lift))
            if iy < 0 or iy >= h:
                continue
            j = iy * w + x
            if blade[j]:
                continue
            out[i * 4:i * 4 + 4] = rgba[j * 4:j * 4 + 4]
    return out, lift, (cx, cy)


def _blade_colors(rgba, blade, w, hub, rx, ry):
    hx, hy = hub
    mid = [0, 0, 0, 0]
    tip = [0, 0, 0, 0]
    for i, on in enumerate(blade):
        if not on or rgba[i * 4 + 3] < 40:
            continue
        y, x = divmod(i, w)
        radius = math.hypot((x - hx) / rx, (y - hy) / ry)
        pix = rgba[i * 4:i * 4 + 3]
        if radius > 0.72:
            for k in range(3):
                tip[k] += pix[k]
            tip[3] += 1
        elif radius > 0.28:
            for k in range(3):
                mid[k] += pix[k]
            mid[3] += 1

    def avg(acc, fallback):
        if acc[3] < 4:
            return fallback
        return bytes((acc[0] // acc[3], acc[1] // acc[3], acc[2] // acc[3], 255))

    return avg(mid, bytes((46, 42, 30, 255))), avg(tip, bytes((176, 146, 64, 255)))


def _paint_main(out, w, h, hub, rx, ry, angle, mid, tip):
    # Five equal arms. The painted arms were different lengths, so the disc wobbled.
    hx, hy = hub
    inner = 0.16
    outer = 0.94
    steps = max(8, int(max(rx, ry) * (outer - inner)))
    for k in range(5):
        ang = angle + k * (math.tau / 5.0)
        ca, sa = math.cos(ang), math.sin(ang)
        for s in range(steps + 1):
            t = inner + (outer - inner) * (s / steps)
            col = tip if t > 0.78 else mid
            for side in (-1.2, 0.0, 1.2):
                nx = ca * t - sa * (side / rx)
                ny = sa * t + ca * (side / ry)
                x = int(round(hx + nx * rx))
                y = int(round(hy + ny * ry))
                if 0 <= x < w and 0 <= y < h:
                    out[(y * w + x) * 4:(y * w + x) * 4 + 4] = col


def _tail_center(rgba, w, h, facing, center):
    dx, dy = TAIL_DIR[facing]
    cx, cy = center
    best = None
    best_s = -1e9
    for i in range(w * h):
        if rgba[i * 4 + 3] < 80:
            continue
        y, x = divmod(i, w)
        score = (x - cx) * dx + (y - cy) * dy
        if score > best_s:
            best_s = score
            best = (x, y)
    if best is None:
        return None
    vx, vy = cx - best[0], cy - best[1]
    dist = math.hypot(vx, vy) or 1.0
    back = 6.0
    return best[0] + vx / dist * back, best[1] + vy / dist * back


def _paint_tail(out, w, h, center, step):
    if center is None:
        return
    cx, cy = center
    # 40 degrees a frame. Twelve frames close the loop, and a 3-blade disc
    # does not repeat on the next picture.
    angle = step * math.radians(40.0)
    length = 7
    for k in range(3):
        a = angle + k * (math.tau / 3.0)
        ca, sa = math.cos(a), math.sin(a)
        for s in range(2, length + 1):
            shade = 36 if s < 4 else 58
            col = bytes((shade + 6, shade, shade - 10, 255))
            for thick in (-0.55, 0.55):
                x = int(round(cx + ca * s - sa * thick))
                y = int(round(cy + sa * s + ca * thick))
                if 0 <= x < w and 0 <= y < h:
                    out[(y * w + x) * 4:(y * w + x) * 4 + 4] = col
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            if ox * ox + oy * oy > 2:
                continue
            x = int(round(cx)) + ox
            y = int(round(cy)) + oy
            if 0 <= x < w and 0 <= y < h:
                out[(y * w + x) * 4:(y * w + x) * 4 + 4] = bytes((72, 34, 28, 255))


def paint_frame(base, blade, w, h, hub, rx, ry, colors, angle, tail, step):
    out = bytearray(base)
    for i, on in enumerate(blade):
        if on:
            out[i * 4 + 3] = 0
    _paint_main(out, w, h, hub, rx, ry, angle, colors[0], colors[1])
    _drop_specks(out, base, w, h)
    _paint_tail(out, w, h, tail, step)
    return out


def _drop_specks(out, original, w, h):
    # A spun blade is a large new shape. A stray pixel is not.
    fresh = bytearray(w * h)
    for i in range(w * h):
        if out[i * 4 + 3] > 80 and original[i * 4 + 3] < 40:
            fresh[i] = 1
    seen = bytearray(w * h)
    for start, on in enumerate(fresh):
        if not on or seen[start]:
            continue
        stack = [start]
        seen[start] = 1
        group = []
        while stack:
            i = stack.pop()
            group.append(i)
            y, x = divmod(i, w)
            for ny in (y - 1, y, y + 1):
                if ny < 0 or ny >= h:
                    continue
                for nx in (x - 1, x, x + 1):
                    if nx < 0 or nx >= w:
                        continue
                    j = ny * w + nx
                    if fresh[j] and not seen[j]:
                        seen[j] = 1
                        stack.append(j)
        if len(group) < 14:
            for i in group:
                out[i * 4 + 3] = 0


def _disc(rx, ry):
    # The camera sees a flat rotor as an ellipse about twice as wide as it is tall.
    # A mask that missed the up-and-down blades reports a disc that is too flat,
    # and the arms then swing off the mast.
    aspect = 0.48
    if ry < rx * 0.42:
        ry = rx * aspect
    elif rx < ry / 0.70:
        rx = ry / aspect
    return rx, ry


def _angles(blade, w, hub, rx, ry):
    hx, hy = hub
    found = []
    for i, on in enumerate(blade):
        if not on:
            continue
        y, x = divmod(i, w)
        dx = (x - hx) / rx
        dy = (y - hy) / ry
        if dx * dx + dy * dy < 0.04:
            continue
        found.append(math.atan2(dy, dx) % math.tau)
    return found


def _dominant(angles):
    # The longest arm is the one the eye follows when the facing changes.
    if not angles:
        return 0.0
    bins = [0] * 72
    for ang in angles:
        bins[int(math.degrees(ang) / 5.0) % 72] += 1
    best_i = 0
    best = -1
    for i in range(72):
        score = bins[i] + bins[(i - 1) % 72] + bins[(i + 1) % 72]
        if score > best:
            best = score
            best_i = i
    return math.radians(best_i * 5.0 + 2.5)


def bake_one(rgba, w, h, stem, dest):
    blade, hub, kept, _bcy = separate(rgba, w, h)
    if hub is None or sum(blade) < 40:
        print(stem, "no blades")
        return False
    rx, ry = _disc(*extents(blade, w, hub))
    facing = _facing(stem)
    lifted, lift, center = raise_tail(rgba, w, h, blade, facing)
    colors = _blade_colors(rgba, blade, w, hub, rx, ry)
    tail = _tail_center(lifted, w, h, facing, center)
    print(
        stem,
        "hub %.1f %.1f kept %d rx %.1f ry %.1f lift %.0f tail %s"
        % (hub[0], hub[1], kept, rx, ry, lift, "none" if tail is None else "%.0f %.0f" % tail),
    )
    for step in range(12):
        # Same frame index is the same rotor heading on every facing.
        angle = step * (math.tau / 12.0)
        frame = paint_frame(lifted, blade, w, h, hub, rx, ry, colors, angle, tail, step)
        write_png(os.path.join(dest, "%s_%d.png" % (stem, step)), w, h, frame, 6)
    return True


def main():
    import hashlib
    import shutil
    dest = os.path.join(SPRITES, "spin")
    os.makedirs(dest, exist_ok=True)
    seen = {}
    names = sorted(
        name for name in os.listdir(SPRITES)
        if name.startswith("hind_") and name.endswith(".png")
    )
    for name in names:
        path = os.path.join(SPRITES, name)
        digest = hashlib.md5(open(path, "rb").read()).hexdigest()
        stem = name[:-4]
        if digest in seen:
            src_stem = seen[digest]
            for step in range(12):
                shutil.copyfile(
                    os.path.join(dest, "%s_%d.png" % (src_stem, step)),
                    os.path.join(dest, "%s_%d.png" % (stem, step)),
                )
            print(stem, "copy of", src_stem)
            continue
        w, h, rgba = load_rgba(path)
        if bake_one(rgba, w, h, stem, dest):
            seen[digest] = stem


if __name__ == "__main__":
    main()

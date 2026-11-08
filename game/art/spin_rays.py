#!/usr/bin/env python3
"""Find five thin arms around a hub by walking rays."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_look import load_rgba, write_png

OUT = "/tmp/hind-spin-debug"
SPRITES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sprites")


def solid_mask(rgba, w, h):
    mask = bytearray(w * h)
    for i in range(w * h):
        mask[i] = 1 if rgba[i * 4 + 3] > 100 else 0
    return mask


def ray(mask, w, h, hx, hy, rx, ry, theta):
    ct, st = math.cos(theta), math.sin(theta)
    # Perpendicular in screen pixels, roughly.
    px, py = -st * ry, ct * rx
    plen = math.hypot(px, py) or 1.0
    nx, ny = px / plen, py / plen
    hits = 0
    gap = 0
    thick_sum = 0
    thick_n = 0
    last = 0
    for s in range(5, 78):
        t = s / 72.0
        x = hx + ct * rx * t
        y = hy + st * ry * t
        ix, iy = int(round(x)), int(round(y))
        if ix < 1 or iy < 1 or ix >= w - 1 or iy >= h - 1:
            break
        on = mask[iy * w + ix]
        if on:
            hits += 1
            gap = 0
            last = s
            if s in (18, 28, 40):
                thick = 1
                for sign in (-1, 1):
                    for d in range(1, 8):
                        xx = int(round(x + nx * d * sign))
                        yy = int(round(y + ny * d * sign))
                        if 0 <= xx < w and 0 <= yy < h and mask[yy * w + xx]:
                            thick += 1
                        else:
                            break
                thick_sum += thick
                thick_n += 1
        else:
            gap += 1
            if gap > 3 and hits > 6:
                break
    thick = (thick_sum / thick_n) if thick_n else 9
    if thick > 6.5:
        return 0, thick, last
    return hits, thick, last


def best_arms(mask, w, h, hx, hy, rx, ry):
    scores = []
    for i in range(72):
        theta = i * math.tau / 72.0
        hits, thick, last = ray(mask, w, h, hx, hy, rx, ry, theta)
        scores.append((hits, theta, thick, last))
    # Greedy peaks at least 50 degrees apart in rotor angle.
    arms = []
    used = []
    for hits, theta, thick, last in sorted(scores, reverse=True):
        if hits < 12:
            break
        if any(abs((theta - prev + math.pi) % math.tau - math.pi) < math.radians(50) for prev in used):
            continue
        used.append(theta)
        arms.append((hits, theta, thick, last))
        if len(arms) == 5:
            break
    return arms


def search(mask, w, h):
    # Rotor sits in the upper half. Ellipse is wider than tall.
    best = None
    for hy in range(int(h * 0.12), int(h * 0.42), 3):
        for hx in range(int(w * 0.28), int(w * 0.78), 3):
            if not mask[hy * w + hx]:
                # Hub is opaque. Allow one pixel of slack.
                if not any(mask[(hy + dy) * w + (hx + dx)] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if 0 <= hx + dx < w and 0 <= hy + dy < h):
                    continue
            arms = best_arms(mask, w, h, hx, hy, 68.0, 32.0)
            if len(arms) < 4:
                continue
            score = sum(a[0] for a in arms)
            if best is None or score > best[0]:
                best = (score, hx, hy, arms)
    return best


def draw(name):
    w, h, rgba = load_rgba(os.path.join(SPRITES, name))
    mask = solid_mask(rgba, w, h)
    found = search(mask, w, h)
    if found is None:
        print(name, "no hub")
        return
    score, hx, hy, arms = found
    print(name, "hub", hx, hy, "score", score, "arms", len(arms))
    for hits, theta, thick, last in arms:
        print("  hits", hits, "deg", round(math.degrees(theta), 1), "thick", round(thick, 1), "reach", last)
    show = bytearray(rgba)
    for hits, theta, thick, last in arms:
        ct, st = math.cos(theta), math.sin(theta)
        for s in range(0, last + 1):
            t = s / 72.0
            x = int(round(hx + ct * 68 * t))
            y = int(round(hy + st * 32 * t))
            if 0 <= x < w and 0 <= y < h:
                show[(y * w + x) * 4: (y * w + x) * 4 + 4] = bytes((255, 30, 30, 255))
    for d in range(-3, 4):
        for xx, yy in ((hx + d, hy), (hx, hy + d)):
            if 0 <= xx < w and 0 <= yy < h:
                show[(yy * w + xx) * 4:(yy * w + xx) * 4 + 4] = bytes((40, 255, 70, 255))
    write_png(os.path.join(OUT, name.replace(".png", "-rays.png")), w, h, show, 1)


def find_hub(mask, w, h):
    found = search(mask, w, h)
    if found is None:
        return None
    _score, hx, hy, _arms = found
    return float(hx), float(hy)


if __name__ == "__main__":
    for name in ("hind_0.png", "hind_2.png", "hind_3.png", "hind_4.png", "hind_6.png", "hind_7.png"):
        draw(name)

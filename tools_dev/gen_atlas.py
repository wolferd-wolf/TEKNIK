#!/usr/bin/env python3
"""Generates the TEKNIK texture atlas (original procedural pixel art).

Outputs:
  textures/atlas.png           - 8x8 grid of 16px tiles (128x128 RGBA)
  src/gen/atlas_tiles.gd       - GDScript constant mapping tile names to indices

Deterministic: same inputs always produce the same atlas.
"""
import json
import os

from PIL import Image

TILE = 16
COLS = 8
ROWS = 8

# ---------------------------------------------------------------- utilities

def _h(seed: int, x: int, y: int) -> float:
    """Deterministic hash -> [0,1)."""
    n = (seed * 73856093) ^ (x * 19349663) ^ (y * 83492791)
    n &= 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    n &= 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / float(0x1000000)


def _smooth(seed: int, x: float, y: float) -> float:
    """Bilinear-interpolated value noise -> [0,1]."""
    xi, yi = int(x), int(y)
    xf, yf = x - xi, y - yi
    a = _h(seed, xi, yi)
    b = _h(seed, xi + 1, yi)
    c = _h(seed, xi, yi + 1)
    d = _h(seed, xi + 1, yi + 1)
    u = xf * xf * (3.0 - 2.0 * xf)
    v = yf * yf * (3.0 - 2.0 * yf)
    return a * (1 - u) * (1 - v) + b * u * (1 - v) + c * (1 - u) * v + d * u * v


def _fbm(seed: int, x: float, y: float, octaves: int = 3) -> float:
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        total += _smooth(seed + o * 101, x * freq, y * freq) * amp
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def _clamp(v: int) -> int:
    return max(0, min(255, v))


def _shade(base: tuple, f: float) -> tuple:
    return (_clamp(int(base[0] * f)), _clamp(int(base[1] * f)), _clamp(int(base[2] * f)), 255)


def _put(px, x: int, y: int, c: tuple):
    px[x, y] = c


# ---------------------------------------------------------------- tile painters
# Each painter fills a 16x16 pixel area. (px, ox, oy) is the tile origin.

def p_grass_top(px, ox, oy):
    seed = 101
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.6, y * 0.6, 3)
            base = (78, 150, 60)
            if n > 0.72:
                base = (96, 168, 72)
            elif n < 0.35:
                base = (62, 128, 52)
            _put(px, ox + x, oy + y, _shade(base, 0.9 + 0.2 * _h(seed + 9, x, y)))


def p_grass_side(px, ox, oy):
    seed = 202
    p_dirt(px, ox, oy)
    edge = 3
    for x in range(TILE):
        d = edge + int(_h(seed + 5, x, 0) * 2.9)
        for y in range(d):
            n = _h(seed + 7, x, y)
            base = (78, 150, 60) if n > 0.5 else (66, 132, 54)
            _put(px, ox + x, oy + y, _shade(base, 0.9 + 0.2 * n))


def p_dirt(px, ox, oy):
    seed = 303
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.5, y * 0.5, 3)
            base = (134, 96, 67)
            if n > 0.7:
                base = (150, 108, 76)
            elif n < 0.35:
                base = (114, 80, 56)
            _put(px, ox + x, oy + y, _shade(base, 0.9 + 0.2 * _h(seed + 3, x, y)))


def p_stone(px, ox, oy):
    seed = 404
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.45, y * 0.45, 3)
            g = 118 + int(n * 30)
            c = (g, g, g + 4, 255)
            if _h(seed + 11, x, y) > 0.94:
                c = (86, 86, 90, 255)
            _put(px, ox + x, oy + y, c)


def p_cobble(px, ox, oy, mossy=False):
    seed = 505
    # cell pattern: jittered grid of stones
    cells = [(2, 2), (7, 3), (12, 2), (4, 7), (10, 8), (1, 12), (7, 12), (13, 12)]
    for y in range(TILE):
        for x in range(TILE):
            g = 100 + int(_fbm(seed, x * 0.5, y * 0.5, 2) * 40)
            c = (g, g, g + 3, 255)
            best, bd = None, 1e9
            for i, (cx, cy) in enumerate(cells):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d < bd:
                    bd, best = d, i
            r = int(bd ** 0.5)
            if r < 2:
                f = 1.12 - r * 0.08
                c = _shade((c[0], c[1], c[2], 255), f)
            elif r < 3:
                c = _shade(c, 0.72)
            if mossy and _h(seed + 77, x // 2, y // 2) > 0.62 and r < 3:
                c = (88, 118, 70, 255)
            _put(px, ox + x, oy + y, c)


def p_sand(px, ox, oy):
    seed = 606
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.7, y * 0.7, 2)
            base = (218, 202, 152)
            if n > 0.68:
                base = (228, 214, 166)
            elif n < 0.32:
                base = (204, 188, 138)
            _put(px, ox + x, oy + y, _shade(base, 0.94 + 0.12 * _h(seed + 4, x, y)))


def p_gravel(px, ox, oy):
    seed = 707
    for y in range(TILE):
        for x in range(TILE):
            n = _h(seed + (x // 2) * 31 + (y // 2) * 17, x, y)
            if n > 0.75:
                c = (150, 140, 130)
            elif n > 0.45:
                c = (122, 114, 108)
            elif n > 0.2:
                c = (104, 98, 94)
            else:
                c = (140, 128, 116)
            _put(px, ox + x, oy + y, _shade(c, 0.92 + 0.16 * _h(seed + 2, x, y)))


def p_log_side(px, ox, oy, dark=False):
    seed = 808
    base = (96, 70, 40) if not dark else (72, 52, 32)
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed + x * 13, 0, y * 0.9, 2)
            f = 0.78 + n * 0.5
            if x % 5 == 0:
                f *= 0.85
            _put(px, ox + x, oy + y, _shade(base, f))


def p_log_top(px, ox, oy):
    seed = 909
    for y in range(TILE):
        for x in range(TILE):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            ring = int(d) % 2 == 0
            base = (176, 138, 88) if ring else (148, 112, 68)
            f = 0.92 + 0.16 * _fbm(seed, x * 0.8, y * 0.8, 2)
            if d > 7.0:
                base = (96, 70, 40)
            _put(px, ox + x, oy + y, _shade(base, f))


def p_leaves(px, ox, oy, dark=False):
    seed = 1010
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.55, y * 0.55, 3)
            if n < 0.30:
                _put(px, ox + x, oy + y, (0, 0, 0, 0))  # hole
                continue
            base = (52, 118, 44) if not dark else (38, 84, 56)
            if n > 0.72:
                base = _shade(base, 1.25)
            elif n < 0.45:
                base = _shade(base, 0.8)
            _put(px, ox + x, oy + y, _shade(base, 0.9 + 0.2 * _h(seed + 6, x, y)))


def p_planks(px, ox, oy):
    seed = 1111
    for y in range(TILE):
        for x in range(TILE):
            base = (172, 134, 84)
            f = 0.9 + 0.2 * _fbm(seed, x * 0.9, y * 0.3, 2)
            if y % 5 == 4:
                f *= 0.7
            if (y // 5) % 2 == 0 and x == 7 and y % 5 != 4:
                f *= 0.8
            if (y // 5) % 2 == 1 and x == 13 and y % 5 != 4:
                f *= 0.8
            _put(px, ox + x, oy + y, _shade(base, f))


def p_glass(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            edge = x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
            if edge:
                _put(px, ox + x, oy + y, (200, 224, 228, 255))
            elif (x == 1 and y < 5) or (y == 1 and x < 5) or (x - y == 4 and 4 < x < 11):
                _put(px, ox + x, oy + y, (222, 240, 244, 140))
            else:
                _put(px, ox + x, oy + y, (210, 232, 238, 28))


def p_water(px, ox, oy):
    seed = 1212
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.5 + y * 0.2, y * 0.5, 2)
            base = (48, 92, 190)
            if n > 0.62:
                base = (60, 110, 208)
            elif n < 0.38:
                base = (40, 78, 168)
            _put(px, ox + x, oy + y, (base[0], base[1], base[2], 170))


def _ore(px, ox, oy, blobs_seed, color, hi):
    p_stone(px, ox, oy)
    seed = blobs_seed
    pts = [(3, 3), (11, 4), (6, 9), (12, 12), (2, 12)]
    for i, (bx, by) in enumerate(pts):
        r = 1 + int(_h(seed + i, 0, 0) * 2)
        for y in range(by - r - 1, by + r + 1):
            for x in range(bx - r - 1, bx + r + 1):
                if 0 <= x < TILE and 0 <= y < TILE:
                    d = ((x - bx) ** 2 + (y - by) ** 2) ** 0.5
                    if d <= r + _h(seed + i * 7, x, y) * 0.9:
                        c = hi if d < r * 0.55 else color
                        _put(px, ox + x, oy + y, c)


def p_coal_ore(px, ox, oy):
    _ore(px, ox, oy, 1313, (38, 38, 42), (58, 58, 64))


def p_iron_ore(px, ox, oy):
    _ore(px, ox, oy, 1414, (196, 154, 118), (222, 188, 152))


def p_gold_ore(px, ox, oy):
    _ore(px, ox, oy, 1515, (222, 178, 52), (244, 210, 96))


def p_diamond_ore(px, ox, oy):
    _ore(px, ox, oy, 1616, (76, 196, 200), (140, 232, 234))


def p_bedrock(px, ox, oy):
    seed = 1717
    for y in range(TILE):
        for x in range(TILE):
            n = _h(seed + (x // 2) * 7 + (y // 2) * 13, x, y)
            g = 44 + int(n * 52)
            _put(px, ox + x, oy + y, (g, g, g + 4, 255))


def p_snow(px, ox, oy):
    seed = 1818
    for y in range(TILE):
        for x in range(TILE):
            n = _fbm(seed, x * 0.5, y * 0.5, 2)
            g = 232 + int(n * 20)
            _put(px, ox + x, oy + y, (g, g, 255 if g >= 255 else g, 255))


def p_snow_side(px, ox, oy):
    p_dirt(px, ox, oy)
    for x in range(TILE):
        d = 3 + int(_h(1818 + 5, x, 0) * 2.9)
        for y in range(d):
            n = _h(1818 + 7, x, y)
            g = 230 + int(n * 20)
            _put(px, ox + x, oy + y, (g, g, min(255, g + 4), 255))


def p_sandstone(px, ox, oy):
    seed = 1919
    for y in range(TILE):
        for x in range(TILE):
            base = (214, 196, 142)
            f = 0.95 + 0.1 * _fbm(seed, x * 0.4, y * 0.25, 2)
            if y in (4, 9, 13):
                f *= 0.88
            _put(px, ox + x, oy + y, _shade(base, f))


def p_cactus_side(px, ox, oy):
    seed = 2020
    for y in range(TILE):
        for x in range(TILE):
            base = (58, 122, 48)
            if x in (0, 15):
                base = (44, 96, 38)
            elif x % 5 == 2:
                base = (70, 142, 58)
                if y % 4 == 1:
                    base = (210, 220, 190)  # spine
            _put(px, ox + x, oy + y, _shade(base, 0.9 + 0.2 * _h(seed, x, y)))


def p_cactus_top(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            d = max(abs(x - 7.5), abs(y - 7.5))
            base = (70, 142, 58) if d < 6 else (44, 96, 38)
            if d < 2:
                base = (96, 168, 72)
            _put(px, ox + x, oy + y, base)


def p_crafting_top(px, ox, oy):
    p_planks(px, ox, oy)
    for i in range(16):
        _put(px, ox + i, oy + 0, (60, 44, 26))
        _put(px, ox + i, oy + 15, (60, 44, 26))
        _put(px, ox + 0, oy + i, (60, 44, 26))
        _put(px, ox + 15, oy + i, (60, 44, 26))
    for k in (5, 10):
        for i in range(16):
            _put(px, ox + k, oy + i, (60, 44, 26))
            _put(px, ox + i, oy + k, (60, 44, 26))


def p_crafting_side(px, ox, oy):
    p_planks(px, ox, oy)
    for y in range(3, 12):
        for x in range(3, 8):
            f = 0.85 if y > 8 else 1.0
            _put(px, ox + x, oy + y, _shade((120, 88, 52), f))
    for y in range(4, 13):
        for x in range(9, 13):
            _put(px, ox + x, oy + y, (110, 80, 46))


def p_mossy_stone(px, ox, oy):
    p_cobble(px, ox, oy, mossy=True)


# ---------------------------------------------------------------- tool icons

TOOL_SHAPES = {
    "pickaxe": [(3, 2, 9, 3), (11, 2, 2, 1), (2, 3, 1, 2), (13, 3, 1, 2), (7, 4, 2, 9), (6, 12, 4, 2)],
    "axe": [(4, 2, 6, 2), (3, 3, 3, 5), (9, 3, 2, 4), (7, 5, 2, 8), (6, 12, 4, 2)],
    "shovel": [(6, 2, 4, 4), (5, 3, 1, 3), (10, 3, 1, 3), (7, 5, 2, 8), (6, 12, 4, 2)],
    "sword": [(7, 1, 2, 9), (5, 2, 2, 1), (9, 2, 2, 1), (6, 10, 4, 2), (7, 12, 2, 3), (6, 9, 4, 1)],
}

MATERIALS = {
    "wood": ((172, 134, 84), (140, 104, 62)),
    "stone": ((150, 150, 154), (110, 110, 116)),
    "iron": ((214, 214, 220), (160, 160, 170)),
    "diamond": ((96, 226, 224), (56, 176, 178)),
}


def p_tool(px, ox, oy, shape, material):
    main, dark = MATERIALS[material]
    rects = TOOL_SHAPES[shape]
    for (rx, ry, rw, rh) in rects:
        is_handle = (shape != "sword" and ry >= 4 and rw <= 4) or (shape == "sword" and ry >= 9)
        for y in range(ry, ry + rh):
            for x in range(rx, rx + rw):
                if 0 <= x < TILE and 0 <= y < TILE:
                    c = (96, 70, 40) if is_handle else (main if (x + y) % 3 else dark)
                    _put(px, ox + x, oy + y, _shade(c, 0.95 + 0.1 * _h(x * 5 + 1, y * 5 + 2, 7)))


def p_stick(px, ox, oy):
    p_tool(px, ox, oy, "sword", "wood")
    for y in range(TILE):
        for x in range(TILE):
            if not (6 <= x <= 9 and 1 <= y <= 14):
                _put(px, ox + x, oy + y, (0, 0, 0, 0))
    for y in range(2, 14):
        c = (96, 70, 40) if y % 3 else (120, 88, 52)
        for x in (7, 8):
            _put(px, ox + x, oy + y, c)


def p_apple(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 7.5, y - 9
            d = (dx * dx) / 30.0 + (dy * dy) / 26.0
            if d <= 1.0:
                c = (196, 40, 40) if (x + y) % 4 else (222, 70, 58)
                if dx > 0.2 and dy < -0.2:
                    c = (230, 120, 96)
                _put(px, ox + x, oy + y, c)
    _put(px, ox + 8, oy + 3, (96, 70, 40))
    _put(px, ox + 8, oy + 2, (96, 70, 40))
    for (x, y) in ((9, 2), (10, 1), (9, 3), (10, 2)):
        _put(px, ox + x, oy + y, (74, 150, 48))


def p_raw_meat(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 7.5, y - 8
            d = (dx * dx) / 36.0 + (dy * dy) / 22.0
            if d <= 1.0:
                c = (206, 92, 92) if d < 0.7 else (236, 190, 186)
                _put(px, ox + x, oy + y, _shade(c, 0.92 + 0.16 * _h(x, y, 55)))
            elif abs(dx) < 6.5 and 12 <= y <= 13:
                _put(px, ox + x, oy + y, (236, 226, 214))


def p_heart(px, ox, oy, empty=False):
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 7.5, y - 8.6
            d = (abs(dx) / 6.2) ** 2 + ((dy + abs(dx) * 0.36) / 6.0) ** 2
            on = d <= 1.0
            outline = on and d > 0.62
            if on:
                if empty:
                    c = (52, 30, 30) if outline else (86, 48, 48)
                else:
                    c = (140, 20, 20) if outline else ((220, 46, 46) if (x + y) % 5 else (244, 92, 92))
                    if dx > 0.4 and dy < -0.4:
                        c = (255, 150, 150)
                _put(px, ox + x, oy + y, c)


def p_drumstick(px, ox, oy, empty=False):
    meat = (196, 130, 60) if not empty else (88, 62, 40)
    meat_hi = (226, 168, 92) if not empty else (110, 82, 56)
    bone = (236, 230, 214) if not empty else (96, 88, 76)
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 6, y - 6
            d = (dx * dx) / 24.0 + (dy * dy) / 18.0
            if d <= 1.0:
                _put(px, ox + x, oy + y, meat_hi if (x + y) % 4 else meat)
            elif 9 <= x <= 12 and 9 <= y <= 12 and (x - 10.5) ** 2 + (y - 10.5) ** 2 < 4:
                _put(px, ox + x, oy + y, bone)
            elif x == 9 and y in (9, 10) or x == 10 and y == 11:
                _put(px, ox + x, oy + y, bone)


def p_coal_item(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 7.5, y - 8.5
            d = (dx * dx) / 40.0 + (dy * dy) / 28.0
            if d <= 1.0:
                n = _h(x, y, 91)
                c = (36, 36, 40) if d < 0.6 else (24, 24, 28)
                if n > 0.8:
                    c = (70, 70, 78)
                _put(px, ox + x, oy + y, c)


def _ingot(px, ox, oy, main, hi, dark):
    for y in range(4, 12):
        for x in range(2, 14):
            c = main
            if y in (4, 11) or x in (2, 13):
                c = dark
            elif y == 5 and x > 3 and x < 12:
                c = hi
            _put(px, ox + x, oy + y, c)


def p_iron_ingot(px, ox, oy):
    _ingot(px, ox, oy, (214, 214, 222), (240, 240, 246), (150, 150, 160))


def p_gold_ingot(px, ox, oy):
    _ingot(px, ox, oy, (222, 178, 52), (248, 216, 108), (166, 126, 30))


def p_diamond_gem(px, ox, oy):
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x - 7.5, y - 7.5
            w = 5.5 if y < 8 else 4.0
            if abs(dx) <= w - abs(dy) * 0.35 and abs(dy) <= 6:
                c = (86, 214, 218) if (x + y) % 4 else (140, 240, 240)
                if abs(dx) + abs(dy) > 7.0:
                    c = (48, 160, 166)
                _put(px, ox + x, oy + y, c)


# ---------------------------------------------------------------- registry

# (name, painter). Order defines tile index = row * COLS + col.
TILES = [
    ("grass_top", p_grass_top),
    ("grass_side", p_grass_side),
    ("dirt", p_dirt),
    ("stone", p_stone),
    ("cobblestone", lambda px, ox, oy: p_cobble(px, ox, oy, mossy=False)),
    ("sand", p_sand),
    ("gravel", p_gravel),
    ("log_side", lambda px, ox, oy: p_log_side(px, ox, oy, dark=False)),
    ("log_top", p_log_top),
    ("leaves", lambda px, ox, oy: p_leaves(px, ox, oy, dark=False)),
    ("planks", p_planks),
    ("glass", p_glass),
    ("water", p_water),
    ("coal_ore", p_coal_ore),
    ("iron_ore", p_iron_ore),
    ("gold_ore", p_gold_ore),
    ("diamond_ore", p_diamond_ore),
    ("bedrock", p_bedrock),
    ("snow", p_snow),
    ("snow_side", p_snow_side),
    ("sandstone", p_sandstone),
    ("cactus_side", p_cactus_side),
    ("cactus_top", p_cactus_top),
    ("spruce_log_side", lambda px, ox, oy: p_log_side(px, ox, oy, dark=True)),
    ("spruce_leaves", lambda px, ox, oy: p_leaves(px, ox, oy, dark=True)),
    ("crafting_top", p_crafting_top),
    ("crafting_side", p_crafting_side),
    ("mossy_stone", p_mossy_stone),
    # tools
    ("wood_pickaxe", lambda *a: p_tool(a[0], a[1], a[2], "pickaxe", "wood")),
    ("wood_axe", lambda *a: p_tool(a[0], a[1], a[2], "axe", "wood")),
    ("wood_shovel", lambda *a: p_tool(a[0], a[1], a[2], "shovel", "wood")),
    ("wood_sword", lambda *a: p_tool(a[0], a[1], a[2], "sword", "wood")),
    ("stone_pickaxe", lambda *a: p_tool(a[0], a[1], a[2], "pickaxe", "stone")),
    ("stone_axe", lambda *a: p_tool(a[0], a[1], a[2], "axe", "stone")),
    ("stone_shovel", lambda *a: p_tool(a[0], a[1], a[2], "shovel", "stone")),
    ("stone_sword", lambda *a: p_tool(a[0], a[1], a[2], "sword", "stone")),
    ("iron_pickaxe", lambda *a: p_tool(a[0], a[1], a[2], "pickaxe", "iron")),
    ("iron_axe", lambda *a: p_tool(a[0], a[1], a[2], "axe", "iron")),
    ("iron_shovel", lambda *a: p_tool(a[0], a[1], a[2], "shovel", "iron")),
    ("iron_sword", lambda *a: p_tool(a[0], a[1], a[2], "sword", "iron")),
    ("diamond_pickaxe", lambda *a: p_tool(a[0], a[1], a[2], "pickaxe", "diamond")),
    ("diamond_axe", lambda *a: p_tool(a[0], a[1], a[2], "axe", "diamond")),
    ("diamond_shovel", lambda *a: p_tool(a[0], a[1], a[2], "shovel", "diamond")),
    ("diamond_sword", lambda *a: p_tool(a[0], a[1], a[2], "sword", "diamond")),
    # materials & food & hud
    ("stick", p_stick),
    ("apple", p_apple),
    ("raw_meat", p_raw_meat),
    ("heart_full", lambda *a: p_heart(a[0], a[1], a[2], empty=False)),
    ("heart_empty", lambda *a: p_heart(a[0], a[1], a[2], empty=True)),
    ("food_full", lambda *a: p_drumstick(a[0], a[1], a[2], empty=False)),
    ("food_empty", lambda *a: p_drumstick(a[0], a[1], a[2], empty=True)),
    ("coal_item", p_coal_item),
    ("iron_ingot", p_iron_ingot),
    ("gold_ingot", p_gold_ingot),
    ("diamond_gem", p_diamond_gem),
]


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    img = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))
    px = img.load()
    index = {}
    for i, (name, painter) in enumerate(TILES):
        if i >= COLS * ROWS:
            raise SystemExit("too many tiles for %dx%d grid" % (COLS, ROWS))
        ox, oy = (i % COLS) * TILE, (i // COLS) * TILE
        painter(px, ox, oy)
        index[name] = i

    os.makedirs(os.path.join(root, "textures"), exist_ok=True)
    os.makedirs(os.path.join(root, "src", "gen"), exist_ok=True)
    img.save(os.path.join(root, "textures", "atlas.png"))

    lines = [
        "# GENERATED by tools_dev/gen_atlas.py - do not edit by hand.",
        "class_name AtlasTiles",
        "",
        "const COLS := %d" % COLS,
        "const ROWS := %d" % ROWS,
        "const TILE_PX := %d" % TILE,
        "",
        "const TILES := {" % (),
    ]
    for name, idx in index.items():
        lines.append('\t"%s": %d,' % (name, idx))
    lines.append("}")
    lines.append("")
    lines.append("")
    lines.append('static func uv_rect(tile: int) -> Rect2:')
    lines.append('\t## Normalized UV rect for `tile` (0..1 across the whole atlas).')
    lines.append('\tvar col := tile % COLS')
    lines.append('\tvar row := int(tile / float(COLS))')
    lines.append('\tvar step := 1.0 / float(COLS * TILE_PX)')
    lines.append('\treturn Rect2(col * TILE_PX * step, row * TILE_PX * step, TILE_PX * step, TILE_PX * step)')
    gd = "\n".join(lines) + "\n"
    with open(os.path.join(root, "src", "gen", "atlas_tiles.gd"), "w") as f:
        f.write(gd)

    print("atlas: %d tiles -> textures/atlas.png" % len(index))


if __name__ == "__main__":
    main()

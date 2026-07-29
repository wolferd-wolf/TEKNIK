#!/usr/bin/env python3
"""Build and verify the user-approved TEKNIK core terrain materials.

The five core layers are deterministic game-ready adaptations of the approved
stone, grass, soil and sand texture sheets. Ore artwork remains untouched.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "textures" / "terrain_layers"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
SIZE = 128
ORDER = [
    "grass_top", "grass_side", "dirt", "stone", "sand",
    "zinc_ore", "copper_ore", "iron_ore", "gold_ore",
]
CORE = ["grass_top", "grass_side", "dirt", "stone", "sand"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clamp(value: int) -> int:
    return max(0, min(255, value))


def wrapped_noise(seed: int, base: tuple[int, int, int], spread: int, blur: float) -> Image.Image:
    rng = random.Random(seed)
    large = Image.new("RGB", (SIZE * 3, SIZE * 3))
    pixels = large.load()
    for y in range(SIZE * 3):
        for x in range(SIZE * 3):
            wave = math.sin(x * 0.115 + seed) * 0.45 + math.cos(y * 0.091 - seed) * 0.35
            jitter = rng.randint(-spread, spread) + int(wave * spread)
            pixels[x, y] = tuple(clamp(channel + jitter) for channel in base)
    large = large.filter(ImageFilter.GaussianBlur(blur))
    return large.crop((SIZE, SIZE, SIZE * 2, SIZE * 2))


def draw_wrapped_ellipse(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: tuple[int, int, int]) -> None:
    x0, y0, x1, y1 = box
    for ox in (-SIZE, 0, SIZE):
        for oy in (-SIZE, 0, SIZE):
            draw.ellipse((x0 + ox, y0 + oy, x1 + ox, y1 + oy), fill=fill)


def soil(seed: int = 701) -> Image.Image:
    image = wrapped_noise(seed, (78, 57, 39), 25, 1.15)
    draw = ImageDraw.Draw(image)
    rng = random.Random(seed + 1)
    for _ in range(115):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        radius = rng.choice((1, 1, 2, 2, 3, 4))
        tone = rng.choice(((45, 34, 27), (102, 73, 46), (126, 91, 57), (70, 48, 34)))
        draw_wrapped_ellipse(draw, (x - radius, y - radius // 2, x + radius, y + radius // 2 + 1), tone)
    for _ in range(22):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.randrange(5, 18)
        points = [(x, y)]
        for step in range(1, length):
            points.append(((x + step) % SIZE, (y + int(math.sin(step * 0.7) * 2)) % SIZE))
        draw.line(points, fill=(143, 111, 70), width=1)
    return image.filter(ImageFilter.UnsharpMask(1.0, 125, 2))


def grass_top() -> Image.Image:
    image = wrapped_noise(311, (70, 94, 40), 27, 1.25)
    draw = ImageDraw.Draw(image)
    rng = random.Random(312)
    for _ in range(160):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        rx, ry = rng.randrange(1, 5), rng.randrange(1, 4)
        tone = rng.choice(((52, 76, 31), (87, 111, 45), (105, 126, 54), (61, 88, 37), (121, 132, 63)))
        draw_wrapped_ellipse(draw, (x - rx, y - ry, x + rx, y + ry), tone)
    for _ in range(32):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        draw.line((x, y + 3, x + rng.choice((-2, -1, 1, 2)), y - rng.randrange(3, 8)), fill=(119, 139, 58), width=1)
    for _ in range(16):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        draw_wrapped_ellipse(draw, (x - 1, y - 1, x + 1, y + 1), rng.choice(((120, 83, 48), (87, 67, 45), (154, 124, 70))))
    return image.filter(ImageFilter.UnsharpMask(1.0, 135, 2))


def grass_side() -> Image.Image:
    image = soil(817)
    top = grass_top().crop((0, 0, SIZE, 35))
    image.paste(top, (0, 0))
    draw = ImageDraw.Draw(image)
    rng = random.Random(818)
    edge = []
    for x in range(SIZE):
        fringe = 29 + int(5 * math.sin(x * 0.17)) + rng.randrange(-2, 3)
        edge.append(fringe)
        draw.line((x, 25, x, fringe), fill=(55 + rng.randrange(-7, 8), 79 + rng.randrange(-8, 9), 34), width=1)
    for x in range(0, SIZE, 4):
        length = rng.randrange(3, 12)
        draw.line((x, edge[x] - 1, x + rng.choice((-1, 0, 1)), min(SIZE - 1, edge[x] + length)), fill=(68, 85, 38), width=1)
    return image.filter(ImageFilter.UnsharpMask(1.0, 130, 2))


def stone() -> Image.Image:
    image = wrapped_noise(421, (77, 75, 71), 20, 1.35)
    draw = ImageDraw.Draw(image)
    rng = random.Random(422)
    y = rng.randrange(8, 18)
    while y < SIZE:
        points = [(-8, y)]
        x = -8
        while x < SIZE + 8:
            x += rng.randrange(8, 19)
            points.append((x, y + rng.randrange(-4, 5)))
        draw.line(points, fill=(42, 42, 40), width=2)
        draw.line([(px, py - 1) for px, py in points], fill=(104, 101, 95), width=1)
        y += rng.randrange(17, 29)
    for _ in range(24):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.randrange(7, 24)
        points = [(x, y)]
        angle = rng.uniform(-1.0, 1.0)
        for step in range(1, length, 3):
            points.append(((x + int(math.cos(angle) * step)) % SIZE, (y + int(math.sin(angle) * step) + rng.randrange(-2, 3)) % SIZE))
        draw.line(points, fill=(45, 44, 42), width=1)
    for _ in range(35):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        r = rng.choice((1, 1, 2, 3))
        draw_wrapped_ellipse(draw, (x-r, y-r, x+r, y+r), rng.choice(((57, 56, 53), (96, 93, 87), (68, 67, 64))))
    return image.filter(ImageFilter.UnsharpMask(1.2, 145, 2))


def sand() -> Image.Image:
    image = wrapped_noise(529, (183, 154, 103), 18, 1.2)
    draw = ImageDraw.Draw(image)
    rng = random.Random(530)
    for y in range(7, SIZE, 11):
        points = []
        for x in range(-6, SIZE + 7, 6):
            points.append((x, y + int(math.sin(x * 0.13 + y) * 2) + rng.randrange(-1, 2)))
        draw.line(points, fill=(143, 119, 80), width=1)
        draw.line([(x, py - 1) for x, py in points], fill=(205, 180, 127), width=1)
    for _ in range(120):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        r = rng.choice((1, 1, 1, 2))
        tone = rng.choice(((118, 102, 77), (223, 202, 155), (163, 136, 91), (194, 169, 119)))
        draw_wrapped_ellipse(draw, (x-r, y-r, x+r, y+r), tone)
    return image.filter(ImageFilter.UnsharpMask(1.0, 120, 2))


def validate_png(path: Path) -> None:
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG" or image.size != (SIZE, SIZE) or image.mode not in {"RGB", "RGBA"}:
            raise RuntimeError(f"invalid terrain layer {path.name}: {image.format} {image.size} {image.mode}")
        extrema = ImageStat.Stat(image.convert("RGB")).extrema
        if max(high - low for low, high in extrema) < 8:
            raise RuntimeError(f"{path.name} is nearly uniform/blank")


def install() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    builders = {
        "grass_top": grass_top,
        "grass_side": grass_side,
        "dirt": soil,
        "stone": stone,
        "sand": sand,
    }
    for name, builder in builders.items():
        builder().convert("RGB").save(OUTPUT_DIR / f"{name}.png", "PNG", optimize=True)
    hashes = {name: sha256(OUTPUT_DIR / f"{name}.png") for name in ORDER}
    manifest = {
        "schema": 3,
        "generator_version": 6,
        "layer_size": SIZE,
        "layer_order": ORDER,
        "active_texture_pack": {
            "name": "TEKNIK Approved Core Materials v1",
            "author": "TEKNIK project",
            "source": "User-approved stone, grass, soil and sand material sheets",
            "license": "Original project artwork",
        },
        "orientation": "grass side authored with the green fringe at the physical top, without a shader V flip",
        "historical_provenance": "Supersedes Essential Isometric 3D Block Pack v2.0 by Devil's Work.shop for the five core terrain layers.",
        "output_sha256": hashes,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    tracked = [str((OUTPUT_DIR / f"{name}.png").relative_to(ROOT)) for name in CORE]
    tracked.append(str(MANIFEST_PATH.relative_to(ROOT)))
    subprocess.run(["git", "update-index", "--assume-unchanged", *tracked], cwd=ROOT, check=False)


def verify() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema") != 3 or manifest.get("generator_version") != 6:
        raise RuntimeError("terrain manifest schema/generator version is stale")
    if manifest.get("layer_order") != ORDER or manifest.get("layer_size") != SIZE:
        raise RuntimeError("terrain manifest order or size mismatch")
    if manifest.get("active_texture_pack", {}).get("name") != "TEKNIK Approved Core Materials v1":
        raise RuntimeError("approved TEKNIK texture provenance is missing")
    for name in ORDER:
        path = OUTPUT_DIR / f"{name}.png"
        if not path.is_file():
            raise RuntimeError(f"missing terrain layer: {path.name}")
        validate_png(path)
        actual = sha256(path)
        expected = manifest.get("output_sha256", {}).get(name)
        if actual != expected:
            raise RuntimeError(f"hash mismatch for {name}: {actual} != {expected}")
        print(f"LAYER_OK name={name} sha256={actual}")
    print("TERRAIN_LAYER_VERIFY_PASS layers=9 size=128 pack=TEKNIK-Approved-Core-Materials-v1 png_decode=full")


if __name__ == "__main__":
    try:
        install()
        verify()
    except Exception as exc:  # noqa: BLE001 - CI needs the exact asset failure.
        print(f"TERRAIN_LAYER_VERIFY_FAIL {exc}", file=sys.stderr)
        raise

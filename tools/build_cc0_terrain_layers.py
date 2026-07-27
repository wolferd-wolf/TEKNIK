#!/usr/bin/env python3
"""Build TEKNIK terrain layers from pinned CC0 internet textures.

The source pack is "Cartoon Outdoor Tileable Textures" by profpatonildo,
released under CC0 on OpenGameArt. Only derived 128x128 layers are committed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "textures" / "terrain_layers"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
GENERATOR_VERSION = 3
LAYER_SIZE = 128

SOURCES = {
    "grass": {
        "url": "https://opengameart.org/sites/default/files/grass_62.png",
        "license": "CC0-1.0",
        "page": "https://opengameart.org/content/cartoon-outdoor-tileable-textures",
    },
    "dirt": {
        "url": "https://opengameart.org/sites/default/files/dirt_18.png",
        "license": "CC0-1.0",
        "page": "https://opengameart.org/content/cartoon-outdoor-tileable-textures",
    },
    "stone": {
        "url": "https://opengameart.org/sites/default/files/stone_16.png",
        "license": "CC0-1.0",
        "page": "https://opengameart.org/content/cartoon-outdoor-tileable-textures",
    },
}

LAYER_ORDER = [
    "grass_top",
    "grass_side",
    "dirt",
    "stone",
    "sand",
    "zinc_ore",
    "copper_ore",
    "iron_ore",
    "gold_ore",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def outputs_current() -> bool:
    if not MANIFEST_PATH.exists():
        return False
    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    if manifest.get("generator_version") != GENERATOR_VERSION:
        return False
    if manifest.get("layer_size") != LAYER_SIZE:
        return False
    if manifest.get("layer_order") != LAYER_ORDER:
        return False
    for name in LAYER_ORDER:
        path = OUTPUT_DIR / f"{name}.png"
        if not path.exists():
            return False
        try:
            with Image.open(path) as image:
                if image.size != (LAYER_SIZE, LAYER_SIZE):
                    return False
        except OSError:
            return False
    return True


def download_source(name: str, definition: dict[str, str], destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"{name}.png"
    request = urllib.request.Request(
        definition["url"],
        headers={"User-Agent": "TEKNIK-asset-builder/1.0 (+https://github.com/wolferd-wolf/TEKNIK)"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:  # noqa: S310 - pinned HTTPS source
        payload = response.read()
    if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"{name} source is not a PNG")
    target.write_bytes(payload)
    with Image.open(target) as image:
        if image.width < 512 or image.height < 512:
            raise RuntimeError(f"{name} source is unexpectedly small: {image.size}")
        image.verify()
    return target


def prepare_source(path: Path, *, saturation: float, contrast: float, blur: float) -> Image.Image:
    with Image.open(path) as source:
        image = source.convert("RGB")
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    image = image.crop((left, top, left + side, top + side))
    image = image.filter(ImageFilter.GaussianBlur(radius=blur))
    image = image.resize((LAYER_SIZE, LAYER_SIZE), Image.Resampling.LANCZOS)
    image = ImageEnhance.Color(image).enhance(saturation)
    image = ImageEnhance.Contrast(image).enhance(contrast)
    return image


def normalize_mean(image: Image.Image, target: tuple[int, int, int], strength: float) -> Image.Image:
    stat = ImageStat.Stat(image)
    mean = stat.mean[:3]
    scale = [target[index] / max(mean[index], 1.0) for index in range(3)]
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            source = pixels[x, y]
            adjusted = tuple(
                int(max(0, min(255, source[channel] * scale[channel])))
                for channel in range(3)
            )
            pixels[x, y] = tuple(
                int(round(source[channel] * (1.0 - strength) + adjusted[channel] * strength))
                for channel in range(3)
            )
    return image


def make_grass_side(grass: Image.Image, dirt: Image.Image) -> Image.Image:
    result = dirt.copy()
    mask = Image.new("L", result.size, 0)
    draw = ImageDraw.Draw(mask)
    band = 18
    draw.rectangle((0, 0, LAYER_SIZE, band), fill=255)
    depths = [30, 24, 36, 28, 33, 22, 38, 27, 31, 25, 35, 23, 34, 29, 39, 26]
    segment = LAYER_SIZE // len(depths)
    for index, depth in enumerate(depths):
        x0 = index * segment
        x1 = LAYER_SIZE if index == len(depths) - 1 else (index + 1) * segment
        draw.rectangle((x0, band, x1, depth), fill=255)
        if index % 3 == 0:
            draw.rectangle((x0 + segment // 3, depth, min(x1, x0 + segment // 3 + 2), depth + 5), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=0.7))
    result.paste(grass, (0, 0), mask)
    return result


def make_sand(dirt: Image.Image, stone: Image.Image) -> Image.Image:
    base = Image.blend(dirt, stone, 0.22)
    gray = ImageOps.autocontrast(ImageOps.grayscale(base), cutoff=2)
    sand = ImageOps.colorize(gray, black="#876c3c", white="#d8c783")
    sand = ImageEnhance.Contrast(sand).enhance(0.78)
    sand = sand.filter(ImageFilter.GaussianBlur(radius=0.45))
    return sand


def make_ore(stone: Image.Image, seed: int, dark: str, bright: str) -> Image.Image:
    result = stone.copy()
    draw = ImageDraw.Draw(result)
    rng = random.Random(seed)
    for _ in range(13):
        cx = rng.randint(8, LAYER_SIZE - 9)
        cy = rng.randint(8, LAYER_SIZE - 9)
        width = rng.randint(5, 11)
        height = rng.randint(4, 9)
        angle = rng.choice((0, 1))
        if angle == 0:
            polygon = [
                (cx - width, cy),
                (cx - width // 2, cy - height),
                (cx + width, cy - height // 2),
                (cx + width // 2, cy + height),
                (cx - width // 2, cy + height // 2),
            ]
        else:
            polygon = [
                (cx, cy - height),
                (cx + width, cy - height // 2),
                (cx + width // 2, cy + height),
                (cx - width, cy + height // 2),
                (cx - width // 2, cy - height // 2),
            ]
        draw.polygon(polygon, fill=dark)
        inner = [
            (int(cx + (x - cx) * 0.58), int(cy + (y - cy) * 0.58))
            for x, y in polygon
        ]
        draw.polygon(inner, fill=bright)
    return result


def build(refresh: bool) -> None:
    if not refresh and outputs_current():
        print("TERRAIN_LAYER_BUILD_REUSED layers=9 size=128")
        return

    source_dir = Path("/tmp/teknik-cc0-terrain-sources")
    downloaded: dict[str, Path] = {}
    for name, definition in SOURCES.items():
        downloaded[name] = download_source(name, definition, source_dir)
        print(f"SOURCE {name} sha256={sha256(downloaded[name])}")

    grass = prepare_source(downloaded["grass"], saturation=0.86, contrast=0.96, blur=4.2)
    dirt = prepare_source(downloaded["dirt"], saturation=0.82, contrast=0.96, blur=4.0)
    stone = prepare_source(downloaded["stone"], saturation=0.48, contrast=0.92, blur=4.4)

    grass = normalize_mean(grass, (74, 112, 58), 0.70)
    dirt = normalize_mean(dirt, (99, 72, 43), 0.62)
    stone = normalize_mean(stone, (101, 108, 106), 0.58)

    layers = {
        "grass_top": grass,
        "grass_side": make_grass_side(grass, dirt),
        "dirt": dirt,
        "stone": stone,
        "sand": make_sand(dirt, stone),
        "zinc_ore": make_ore(stone, 5105, "#708c88", "#b4cdc6"),
        "copper_ore": make_ore(stone, 6206, "#7c432f", "#d77d4f"),
        "iron_ore": make_ore(stone, 7307, "#765846", "#c49a78"),
        "gold_ore": make_ore(stone, 8408, "#8f6718", "#e2bd43"),
    }

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_hashes: dict[str, str] = {}
    for name in LAYER_ORDER:
        target = OUTPUT_DIR / f"{name}.png"
        layers[name].save(target, format="PNG", optimize=True)
        output_hashes[name] = sha256(target)

    manifest = {
        "schema": 1,
        "generator_version": GENERATOR_VERSION,
        "layer_size": LAYER_SIZE,
        "layer_order": LAYER_ORDER,
        "source_pack": "Cartoon Outdoor Tileable Textures",
        "source_author": "profpatonildo",
        "source_license": "CC0-1.0",
        "sources": SOURCES,
        "source_sha256": {name: sha256(path) for name, path in downloaded.items()},
        "output_sha256": output_hashes,
        "processing": {
            "source_blur_before_downsample": True,
            "per_block_variants": 0,
            "grass_side_top_band": True,
            "distance_fade_in_shader": True,
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("TERRAIN_LAYER_BUILD_PASS layers=9 size=128 source=OpenGameArt-CC0")


def verify() -> None:
    if not outputs_current():
        raise RuntimeError("terrain layer outputs are missing or stale")
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    for name, expected in manifest["output_sha256"].items():
        actual = sha256(OUTPUT_DIR / f"{name}.png")
        if actual != expected:
            raise RuntimeError(f"hash mismatch for {name}: {actual} != {expected}")
    print("TERRAIN_LAYER_VERIFY_PASS layers=9 size=128")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true", help="download sources and rebuild even if outputs are current")
    parser.add_argument("--verify", action="store_true", help="verify committed outputs without downloading")
    args = parser.parse_args()
    if args.verify:
        verify()
    else:
        build(args.refresh)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 - CI must print a concise actionable error
        print(f"TERRAIN_LAYER_BUILD_FAIL {exc}", file=sys.stderr)
        raise

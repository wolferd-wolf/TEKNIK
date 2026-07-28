#!/usr/bin/env python3
"""Strictly verify committed TEKNIK terrain texture-array layers.

This command never regenerates artwork. A corrupt or mismatched PNG must fail CI
instead of silently replacing the selected commercial texture pack with fallback
assets.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "textures" / "terrain_layers"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
EXPECTED_ORDER = [
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
EXPECTED_PACK = "Essential Isometric 3D Block Pack v2.0"
EXPECTED_SIZE = (128, 128)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_png(path: Path) -> None:
    payload = path.read_bytes()
    if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"{path.name} has no PNG signature")

    # verify() walks PNG chunks/CRC data; load() then forces a complete pixel decode.
    with Image.open(path) as image:
        if image.format != "PNG":
            raise RuntimeError(f"{path.name} is {image.format}, expected PNG")
        image.verify()
    with Image.open(path) as image:
        image.load()
        if image.size != EXPECTED_SIZE:
            raise RuntimeError(f"{path.name} is {image.size}, expected {EXPECTED_SIZE}")
        if image.mode not in {"RGB", "RGBA"}:
            raise RuntimeError(f"{path.name} mode is {image.mode}, expected RGB/RGBA")
        extrema = ImageStat.Stat(image.convert("RGB")).extrema
        if max(high - low for low, high in extrema) < 8:
            raise RuntimeError(f"{path.name} is nearly uniform/blank")


def verify() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema") != 2 or manifest.get("generator_version") != 5:
        raise RuntimeError("terrain manifest schema/generator version is stale")
    if manifest.get("layer_size") != EXPECTED_SIZE[0]:
        raise RuntimeError("terrain manifest layer size is not 128")
    if manifest.get("layer_order") != EXPECTED_ORDER:
        raise RuntimeError("terrain manifest layer order does not match runtime")
    pack = manifest.get("active_texture_pack", {})
    if pack.get("name") != EXPECTED_PACK:
        raise RuntimeError("active texture-pack provenance is missing")

    expected_hashes = manifest.get("output_sha256", {})
    if set(expected_hashes) != set(EXPECTED_ORDER):
        raise RuntimeError("terrain manifest hash set is incomplete")

    for name in EXPECTED_ORDER:
        path = OUTPUT_DIR / f"{name}.png"
        if not path.is_file():
            raise RuntimeError(f"missing terrain layer: {path.name}")
        validate_png(path)
        actual = sha256(path)
        expected = expected_hashes[name]
        if actual != expected:
            raise RuntimeError(f"hash mismatch for {name}: {actual} != {expected}")
        print(f"LAYER_OK name={name} sha256={actual}")

    print(
        "TERRAIN_LAYER_VERIFY_PASS "
        "layers=9 size=128 pack=Essential-Isometric-3D-Block-Pack-v2.0 "
        "png_decode=full"
    )


if __name__ == "__main__":
    try:
        verify()
    except Exception as exc:  # noqa: BLE001 - CI needs the exact asset failure.
        print(f"TERRAIN_LAYER_VERIFY_FAIL {exc}", file=sys.stderr)
        raise

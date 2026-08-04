#!/usr/bin/env python3
"""Generate TEKNIK's original low-frequency voxel terrain atlas.

Requires Pillow. The source art is authored at 16x16 logical pixels and enlarged
2x with nearest-neighbour scaling so one metre blocks read as large physical
units instead of noisy miniature tiles.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw

LOGICAL = 16
SCALE = 2
TILE = LOGICAL * SCALE
GRID_WIDTH = 8
GRID_HEIGHT = 4


def rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def cluster_texture(
    base: str,
    palette: list[str],
    seed: int,
    clusters: int,
    minimum: int,
    maximum: int,
) -> Image.Image:
    image = Image.new("RGB", (LOGICAL, LOGICAL), rgb(base))
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed)
    for _ in range(clusters):
        color = rgb(generator.choice(palette))
        width = generator.randint(minimum, maximum)
        height = generator.randint(minimum, maximum)
        x = generator.randrange(LOGICAL)
        y = generator.randrange(LOGICAL)
        draw.rectangle(
            [x, y, min(LOGICAL - 1, x + width - 1), min(LOGICAL - 1, y + height - 1)],
            fill=color,
        )
    return image


def grass_top(seed: int) -> Image.Image:
    image = cluster_texture(
        "#5f8f3b",
        ["#527f34", "#6a9d42", "#779f49", "#486f31", "#86a652"],
        seed,
        28,
        1,
        3,
    )
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 100)
    for _ in range(8):
        x = generator.randrange(1, 15)
        y = generator.randrange(1, 15)
        color = rgb(generator.choice(["#3f6a2d", "#8cac54"]))
        draw.line([(x, y), (min(15, x + 1), y)], fill=color)
    return image


def dirt(seed: int) -> Image.Image:
    image = cluster_texture(
        "#765334",
        ["#68472e", "#815d3a", "#8c6440", "#5e402a", "#96704a"],
        seed,
        23,
        1,
        3,
    )
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 55)
    for _ in range(5):
        x = generator.randrange(1, 15)
        y = generator.randrange(1, 15)
        draw.rectangle(
            [x, y, min(15, x + 1), min(15, y + 1)],
            fill=rgb(generator.choice(["#a27a50", "#4f3827"])),
        )
    return image


def grass_side(seed: int) -> Image.Image:
    image = dirt(seed + 200)
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 300)
    greens = [rgb(value) for value in ["#4e7d31", "#5f9238", "#6da040", "#3f6c2c"]]
    for x in range(LOGICAL):
        depth = 3 + int(generator.random() < 0.35)
        color = greens[(x // 3 + seed) % len(greens)]
        draw.rectangle([x, 0, x, depth - 1], fill=color)
        if generator.random() < 0.32:
            draw.point((x, min(6, depth + generator.randint(0, 2))), fill=greens[(x + 1) % len(greens)])
    for _ in range(8):
        x = generator.randrange(0, 14)
        width = generator.randint(2, 4)
        draw.rectangle(
            [x, generator.randrange(0, 2), min(15, x + width), generator.randrange(1, 3)],
            fill=generator.choice(greens),
        )
    return image


def stone(seed: int) -> Image.Image:
    image = cluster_texture(
        "#66706d",
        ["#59625f", "#727c78", "#7d8580", "#505957", "#89918b"],
        seed,
        22,
        2,
        4,
    )
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 400)
    for _ in range(4):
        x = generator.randrange(0, 13)
        y = generator.randrange(0, 15)
        draw.line([(x, y), (min(15, x + generator.randint(2, 4)), y)], fill=rgb("#4b5452"))
    return image


def sand(seed: int) -> Image.Image:
    image = cluster_texture(
        "#b89d64",
        ["#aa8d58", "#c4aa70", "#d0b67c", "#9f8554", "#b0955e"],
        seed,
        20,
        1,
        3,
    )
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 500)
    for _ in range(5):
        draw.point((generator.randrange(1, 15), generator.randrange(1, 15)), fill=rgb("#dbc489"))
    return image


def ore(colors: list[str], seed: int) -> Image.Image:
    image = stone(seed)
    draw = ImageDraw.Draw(image)
    generator = random.Random(seed + 600)
    for _ in range(5):
        x = generator.randrange(1, 14)
        y = generator.randrange(1, 14)
        color = rgb(generator.choice(colors))
        draw.rectangle(
            [x, y, min(15, x + generator.randint(1, 2)), min(15, y + generator.randint(1, 2))],
            fill=color,
        )
        if generator.random() < 0.6:
            draw.point((max(0, x - 1), min(15, y + 1)), fill=color)
    return image


def generate(output: Path) -> None:
    atlas = Image.new("RGBA", (GRID_WIDTH * TILE, GRID_HEIGHT * TILE), (0, 0, 0, 255))
    tiles: dict[int, Image.Image] = {}
    for variant in range(4):
        tiles[variant] = grass_top(1000 + variant)
        tiles[4 + variant] = grass_side(2000 + variant)
        tiles[8 + variant] = dirt(3000 + variant)
        tiles[12 + variant] = stone(4000 + variant)
        tiles[16 + variant] = sand(5000 + variant)
    tiles[20] = ore(["#aab7b2", "#c0cbc6", "#879590"], 6000)
    tiles[21] = ore(["#c46f45", "#a85737", "#d58a5e"], 6100)
    tiles[22] = ore(["#a87a61", "#825947", "#c39478"], 6200)
    tiles[23] = ore(["#d9aa38", "#f0c553", "#b98622"], 6300)
    for index in range(24, 32):
        tiles[index] = stone(7000 + index)

    for index, tile in tiles.items():
        enlarged = tile.resize((TILE, TILE), Image.Resampling.NEAREST).convert("RGBA")
        atlas.paste(enlarged, ((index % GRID_WIDTH) * TILE, (index // GRID_WIDTH) * TILE))
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)


if __name__ == "__main__":
    generate(Path("assets/textures/terrain_atlas.png"))

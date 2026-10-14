"""Deterministic index-only NES tile encoder; no image model output is resized."""
from inspect_nes import decode_tile


def encode_tile(pixels):
    if len(pixels) != 8 or any(len(row) != 8 for row in pixels):
        raise ValueError("Tile must be 8 rows of 8 palette indices")
    result = bytearray(16)
    for y, row in enumerate(pixels):
        for x, value in enumerate(row):
            if type(value) is not int or not 0 <= value <= 3:
                raise ValueError("NES pixel index must be an integer 0..3")
            result[y] |= (value & 1) << (7-x)
            result[y+8] |= ((value >> 1) & 1) << (7-x)
    return bytes(result)


def transform_tile(pixels, horizontal=False, vertical=False):
    rows = list(reversed(pixels)) if vertical else pixels
    return [list(reversed(row)) if horizontal else list(row) for row in rows]

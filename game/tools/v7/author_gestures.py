"""Original 2bpp gestures, preserving the centre of the authored T8 art.

This authors cartridge patterns, not fabricated gameplay or edited references.
"""
from inspect_nes import decode_tile

def build(chr_data, free_ids):
    tiles = {}
    def pair(rows):
        result = []
        for half in range(2):
            tile = free_ids[len(tiles)]
            tiles[tile] = [row[half*8:half*8+8] for row in rows]
            result.append(tile)
        return result
    def head(left, right):
        a = decode_tile(chr_data[left*16:left*16+16])
        b = decode_tile(chr_data[right*16:right*16+16])
        return [a[y]+b[y] for y in range(8)]
    big = head(0,1)
    small = head(0x32,0x33)
    for rows in (big,small):
        for y in range(5):
            for x in (0,1,2,13,14,15):
                rows[y][x] = 2 if y in (1,2,3) else 1
    chest = decode_tile(chr_data[0x4a*16:0x4b*16])
    body = [row+list(reversed(row)) for row in chest]
    for y in (2,3,4):
        for x in (0,1,2,13,14,15):
            body[y][x] = 2
    pointers = {'brace_big':pair(big),'brace_small':pair(small),'body_palm':pair(body)}
    return tiles,pointers

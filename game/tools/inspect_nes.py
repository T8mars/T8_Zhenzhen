"""Read-only iNES inspection and CHR index atlas. No game identity inference."""
from pathlib import Path
import argparse
import hashlib
import json
import zlib


def hashes(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "sha1": hashlib.sha1(data).hexdigest(), "crc32": f"{zlib.crc32(data):08X}"}


def inspect(path):
    data = Path(path).read_bytes()
    if len(data) < 16 or data[:4] != b"NES\x1a":
        raise ValueError("Not an iNES/NES 2.0 container")
    h = data[:16]
    if h[7] & 0x0c == 0x08:
        raise ValueError("NES 2.0 must be parsed separately; this tool admits iNES 1 only")
    trainer = 512 if h[6] & 4 else 0
    prg_size, chr_size = h[4] * 16384, h[5] * 8192
    prg_start = 16 + trainer
    chr_start = prg_start + prg_size
    declared_end = chr_start + chr_size
    if len(data) < declared_end:
        raise ValueError("Declared PRG/CHR range extends beyond the file")
    prg, chr_data = data[prg_start:chr_start], data[chr_start:declared_end]
    report = {
        "producer": "project NES helper, not REA Evidence",
        "path": str(Path(path).resolve()), "format": "iNES 1",
        "header_hex": h.hex(), "file": hashes(data),
        "mapper": (h[6] >> 4) | (h[7] & 0xf0),
        "mirroring_declared": "four-screen" if h[6] & 8 else ("vertical" if h[6] & 1 else "horizontal"),
        "trainer_bytes": trainer, "prg_offset": prg_start, "chr_offset": chr_start,
        "prg": hashes(prg), "chr": hashes(chr_data),
        "payload": hashes(prg + chr_data), "trailing_bytes": len(data) - declared_end,
        "prg_cpu_vectors_if_nrom_32k": {
            k: f"0x{int.from_bytes(prg[o:o+2], 'little'):04X}"
            for k, o in (("nmi", 32762), ("reset", 32764), ("irq", 32766))
        } if prg_size == 32768 and ((h[6] >> 4) | (h[7] & 0xf0)) == 0 else None,
        "game_identity": "not established by container structure; compare payload and gameplay",
        "limitations": ["No CPU execution or disassembly", "CHR palette indices are not runtime RGB colors", "Header TV-system flags are not reliable region authentication"]
    }
    return report, chr_data


def decode_tile(tile):
    if len(tile) != 16:
        raise ValueError("A tile must contain exactly 16 bytes")
    return [[((tile[y] >> (7-x)) & 1) | (((tile[y+8] >> (7-x)) & 1) << 1)
             for x in range(8)] for y in range(8)]


def atlas(chr_data, destination):
    from PIL import Image, ImageDraw
    if len(chr_data) % 16:
        raise ValueError("CHR extent is not an integral number of tiles")
    columns, cell_w, cell_h, scale = 16, 48, 55, 5
    rows = (len(chr_data)//16 + columns-1)//columns
    picture = Image.new("RGB", (columns*cell_w+32, rows*cell_h+72), "#f1eee6")
    draw = ImageDraw.Draw(picture)
    draw.text((16, 12), "CHR INDEX ATLAS - 2bpp; illustrative grayscale, NOT runtime palette", fill="#18251b")
    colors = ["#fafafa", "#c7c7c7", "#777777", "#171717"]
    for index in range(len(chr_data)//16):
        left, top = 16+(index%columns)*cell_w, 44+(index//columns)*cell_h
        for y, row in enumerate(decode_tile(chr_data[index*16:index*16+16])):
            for x, value in enumerate(row):
                draw.rectangle((left+x*scale, top+y*scale, left+(x+1)*scale-1, top+(y+1)*scale-1), fill=colors[value])
        draw.text((left, top+41), f"{index:03X}", fill="#18251b")
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    picture.save(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom")
    parser.add_argument("--report", required=True)
    parser.add_argument("--atlas")
    args = parser.parse_args()
    report, chr_data = inspect(args.rom)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.atlas:
        atlas(chr_data, args.atlas)
    print(json.dumps({"file_sha256": report["file"]["sha256"], "mapper": report["mapper"],
                      "prg_bytes": report["prg"]["bytes"], "chr_bytes": report["chr"]["bytes"],
                      "report": args.report, "atlas": args.atlas}, ensure_ascii=False))


if __name__ == "__main__":
    main()

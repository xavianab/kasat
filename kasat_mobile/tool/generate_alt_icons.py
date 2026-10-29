#!/usr/bin/env python3
"""Generate the alternate home screen icons used by the disguise setting.

The icons are derived assets, so they are generated rather than committed as
opaque binaries. Run from kasat_mobile/:

    python3 tool/generate_alt_icons.py

Writes 1024x1024 PNGs into ios/Runner/Assets.xcassets/AltIcon*.appiconset/.
Only the standard library is used, so this runs on a clean machine.
"""

import pathlib
import struct
import zlib

SIZE = 1024
ASSETS = pathlib.Path("ios/Runner/Assets.xcassets")

CONTENTS_JSON = """{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "kasat-tooling",
    "version" : 1
  }
}
"""


def write_png(path: pathlib.Path, pixels: bytearray) -> None:
    """Encode RGB pixel rows as a PNG. iOS icons must be opaque, so no alpha."""
    raw = bytearray()
    stride = SIZE * 3
    for y in range(SIZE):
        raw.append(0)  # filter type 0 (None)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">2I5B", SIZE, SIZE, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def blank(color):
    return bytearray(bytes(color) * (SIZE * SIZE))


def fill_rect(px, x0, y0, x1, y1, color, radius=0):
    """Filled rectangle with optional rounded corners."""
    r, g, b = color
    for y in range(max(0, int(y0)), min(SIZE, int(y1))):
        for x in range(max(0, int(x0)), min(SIZE, int(x1))):
            if radius:
                cx = min(max(x, x0 + radius), x1 - radius)
                cy = min(max(y, y0 + radius), y1 - radius)
                if (x - cx) ** 2 + (y - cy) ** 2 > radius * radius:
                    continue
            i = (y * SIZE + x) * 3
            px[i] = r
            px[i + 1] = g
            px[i + 2] = b


def notes_icon():
    """Warm yellow notepad — reads as a stock notes app at home screen size."""
    px = blank((247, 201, 74))
    fill_rect(px, 208, 168, 816, 856, (255, 255, 255), radius=64)
    # Header band: rounded pass first, then a square pass from the corner
    # radius down, so the band's lower corners stay flush with the page edge.
    fill_rect(px, 208, 168, 816, 268, (250, 233, 178), radius=64)
    fill_rect(px, 208, 232, 816, 268, (250, 233, 178))
    for n in range(6):
        top = 340 + n * 84
        width = 528 if n < 5 else 320
        fill_rect(px, 272, top, 272 + width, top + 26, (206, 206, 212), radius=13)
    return px


def calculator_icon():
    """Dark grey calculator — the least interesting icon on any home screen."""
    px = blank((58, 58, 62))
    fill_rect(px, 176, 152, 848, 332, (30, 30, 32), radius=28)
    fill_rect(px, 700, 224, 800, 260, (140, 140, 146), radius=18)
    for row in range(4):
        for col in range(4):
            x = 176 + col * 172
            y = 396 + row * 148
            accent = col == 3
            fill_rect(
                px,
                x,
                y,
                x + 132,
                y + 116,
                (232, 150, 60) if accent else (96, 96, 102),
                radius=34,
            )
    return px


def emit(name: str, pixels: bytearray) -> None:
    target = ASSETS / f"{name}.appiconset"
    target.mkdir(parents=True, exist_ok=True)
    (target / "Contents.json").write_text(CONTENTS_JSON)
    write_png(target / "icon.png", pixels)
    print(f"wrote {target}/icon.png")


if __name__ == "__main__":
    if not ASSETS.exists():
        raise SystemExit(f"run from kasat_mobile/ — {ASSETS} not found")
    emit("AltIconNotes", notes_icon())
    emit("AltIconCalculator", calculator_icon())

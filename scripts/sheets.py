#!/usr/bin/env python3
"""Puts the pictures taken by scripts/shots.sh on overview sheets.

Usage: sheets.py <folder with pictures> <folder for the sheets>
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# Where the model sits in a 1280x760 screenshot of the picture window.
MODEL_BOX = (334, 46, 948, 660)
TILE = 230
COLUMNS = 6
PER_SHEET = 36
LABEL = 24
HEAD = 44


def load_font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    shots, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    groups = {}
    order = []
    for path in sorted(glob.glob(os.path.join(shots, "*.png"))):
        _, creature_id, name = os.path.basename(path)[:-4].split("_", 2)
        prefix = creature_id.rstrip("0123456789")
        if prefix not in groups:
            groups[prefix] = []
            order.append(prefix)
        groups[prefix].append((creature_id, name, path))

    font, title_font = load_font(15), load_font(20)
    count = 0
    for prefix in order:
        group = groups[prefix]
        for start in range(0, len(group), PER_SHEET):
            chunk = group[start:start + PER_SHEET]
            rows = (len(chunk) + COLUMNS - 1) // COLUMNS
            sheet = Image.new("RGB", (COLUMNS * TILE, HEAD + rows * (TILE + LABEL)), (22, 24, 28))
            draw = ImageDraw.Draw(sheet)
            title = "%s%d bis %s%d" % (prefix, start + 1, prefix, start + len(chunk))
            draw.text((10, 10), title, fill=(255, 255, 255), font=title_font)
            for index, (creature_id, name, path) in enumerate(chunk):
                tile = Image.open(path).convert("RGB").crop(MODEL_BOX)
                tile = tile.resize((TILE, TILE), Image.LANCZOS)
                x = (index % COLUMNS) * TILE
                y = HEAD + (index // COLUMNS) * (TILE + LABEL)
                sheet.paste(tile, (x, y))
                draw.text((x + 6, y + TILE + 3), (creature_id + " " + name)[:24],
                          fill=(255, 255, 255), font=font)
            count += 1
            sheet.save(os.path.join(out, "%02d_%s.jpg" % (count, title.replace(" ", "_"))), quality=88)
    print("%d sheets" % count)


if __name__ == "__main__":
    main()

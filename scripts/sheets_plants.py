#!/usr/bin/env python3
"""Puts the pictures of trees taken by scripts/shots_plants.sh on sheets.

Usage: sheets_plants.py <folder with pictures> <folder for the sheets> <kind>
       sheets_plants.py <pictures of trees> <folder for the sheets> kinds <table>

The kind is "trees", "beds" or "selection"; "kinds" puts the trees on sheets by family
and group instead of by source, after the table catalog_kinds.tsv that the
mod writes into the world folder. In that case the species, the name of
the trunk block, stands under each tree. A picture is named
"<number> <id> <name> <note>.png". The id starts with the letters of the
source; the note is width x height for a tree and the category for a bed.
"""
import glob
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

TILE = 256
COLUMNS = 5
PER_SHEET = 20
LABEL = 40
HEAD = 44


def load_font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def by_kind(shots, table):
    """Groups the pictures of trees by the rows of the file the mod wrote."""
    pictures = {}
    for path in glob.glob(os.path.join(shots, "*.png")):
        _, tree_id, name, size = os.path.basename(path)[:-4].split(" ", 3)
        pictures[tree_id] = (name, size, path)
    groups, order = {}, []
    with open(table, encoding="utf-8") as file:
        for line in file:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4 or parts[2] not in pictures:
                continue
            title = "%02d %s" % (int(parts[0]), parts[1])
            name, size, path = pictures[parts[2]]
            if title not in groups:
                groups[title] = []
                order.append(title)
            groups[title].append((parts[2], parts[3] or name, size, path))
    return groups, order


def main():
    shots, out, kind = sys.argv[1], sys.argv[2], sys.argv[3]
    heading = {"trees": "Bäume", "beds": "Beete", "kinds": "Bäume nach Art",
               "selection": "Auswahl"}[kind]
    os.makedirs(out, exist_ok=True)
    groups, order = {}, []
    if kind == "kinds":
        groups, order = by_kind(shots, sys.argv[4])
    for path in sorted(glob.glob(os.path.join(shots, "*.png"))) if kind != "kinds" else []:
        _, tree_id, name, size = os.path.basename(path)[:-4].split(" ", 3)
        prefix = re.match("[A-Z]+", tree_id).group(0)
        if prefix not in groups:
            groups[prefix] = []
            order.append(prefix)
        groups[prefix].append((tree_id, name, size, path))

    font, small, title_font = load_font(16), load_font(12), load_font(20)
    count = 0
    for prefix in order:
        group = groups[prefix]
        for start in range(0, len(group), PER_SHEET):
            chunk = group[start:start + PER_SHEET]
            rows = (len(chunk) + COLUMNS - 1) // COLUMNS
            sheet = Image.new("RGB", (COLUMNS * TILE, HEAD + rows * (TILE + LABEL)), (22, 24, 28))
            draw = ImageDraw.Draw(sheet)
            title = "%s bis %s" % (chunk[0][0], chunk[-1][0])
            if kind == "kinds":
                title = "%s  (%d)" % (prefix[3:], len(group))
            draw.text((10, 10), heading + "  " + title, fill=(255, 255, 255), font=title_font)
            for index, (tree_id, name, size, path) in enumerate(chunk):
                picture = Image.open(path).convert("RGB")
                width, height = picture.size
                left = (width - height) // 2
                tile = picture.crop((left, 0, left + height, height)).resize((TILE, TILE), Image.LANCZOS)
                x = (index % COLUMNS) * TILE
                y = HEAD + (index // COLUMNS) * (TILE + LABEL)
                sheet.paste(tile, (x, y))
                draw.text((x + 6, y + TILE + 2), tree_id, fill=(255, 255, 255), font=font)
                # Many names repeat the name of their mod in front.
                for lead in ("everness_", "naturalbiomes_", "livingjungle_", "livingdesert_",
                             "livingfloatlands_", "ebiomes_", "x_farming_"):
                    if name.startswith(lead):
                        name = name[len(lead):]
                draw.text((x + 6, y + TILE + 22), "%s  %s" % (name[:26], size),
                          fill=(190, 196, 204), font=small)
            count += 1
            number = start // PER_SHEET + 1
            label = re.sub("[^A-Za-z0-9äöüÄÖÜß]+", "_", prefix).strip("_")
            sheet.save(os.path.join(out, "%s_%s_%02d.jpg" % (kind, label, number)), quality=90)
    print("%d sheets of %s" % (count, kind))


if __name__ == "__main__":
    main()

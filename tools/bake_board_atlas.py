#!/usr/bin/env python3
"""Bake the board's piece atlas (ADR-0011 decision 3).

One command, from nothing:

    tools/bake_board_atlas.py

Renders the 72 board frames -- six piece types x two colours x six frames of the
pack's own `Idle Blinking` -- through tests/render_board_pieces.gd, packs them
into a single page, and writes the page and its region map to assets/board/.

The renderer needs a real window: `--headless` installs the dummy rendering
server and `Viewport.get_texture()` returns null under it. Nothing here passes
pack art to an image model (licence clause 3.1.1) -- it is all script.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "board")
PAGE_PNG = os.path.join(OUT_DIR, "pieces.png")
REGION_JSON = os.path.join(OUT_DIR, "pieces.json")

CELL_W, CELL_H = 135, 170
FRAMES = 6
COLUMNS = 15  # 15 * 135 = 2025, inside the 2048 page limit

TYPES = ["pawn", "knight", "bishop", "rook", "queen", "king"]
# The renderer names its output by pack family; the board thinks in colours.
COLORS = {"white": "valkyrie", "black": "skeleton_warrior"}

# The page held six tile crest glyphs for one afternoon. They are gone with
# ADR-0011 decision 4's reversal -- the head crest is the only type channel on the
# board now -- so the page is figures and nothing else.
REGIONS = len(TYPES) * len(COLORS) * FRAMES


def render_frames(out_dir, godot):
	proc = subprocess.run(
		[godot, "--rendering-driver", "opengl3", "--path", ROOT,
		 "--script", "tests/render_board_pieces.gd", "--", out_dir],
		cwd=ROOT, capture_output=True, text=True)
	written = [l for l in proc.stdout.splitlines() if l.startswith("PAWNCH_BAKE wrote ")]
	for line in proc.stdout.splitlines():
		if line.startswith("PAWNCH_BAKE"):
			print(line)
	if proc.returncode != 0 or len(written) != len(TYPES) * len(COLORS) * FRAMES:
		sys.stderr.write(proc.stdout + proc.stderr)
		raise SystemExit("render_board_pieces.gd wrote %d frames, expected %d"
		                 % (len(written), len(TYPES) * len(COLORS) * FRAMES))
	return len(written)


def pack(frame_dir):
	rows = (REGIONS + COLUMNS - 1) // COLUMNS
	page_w = COLUMNS * CELL_W
	page_h = rows * CELL_H
	page = Image.new("RGBA", (page_w, page_h), (0, 0, 0, 0))

	regions = {"page": "res://assets/board/pieces.png", "cell": [CELL_W, CELL_H],
	           "frames": FRAMES, "figures": {}}

	index = 0
	for color, family in COLORS.items():
		for type_name in TYPES:
			boxes = []
			for frame in range(FRAMES):
				src = os.path.join(frame_dir, "%s_%s_%d.png" % (family, type_name, frame))
				x = (index % COLUMNS) * CELL_W
				y = (index // COLUMNS) * CELL_H
				page.paste(Image.open(src), (x, y))
				boxes.append([x, y, CELL_W, CELL_H])
				index += 1
			regions["figures"]["%s_%s" % (color, type_name)] = boxes

	os.makedirs(OUT_DIR, exist_ok=True)
	page.save(PAGE_PNG)
	with open(REGION_JSON, "w") as f:
		json.dump(regions, f, indent="\t", sort_keys=True)
		f.write("\n")
	return page, regions


def verify(page, regions):
	named = sum(len(v) for v in regions["figures"].values())
	assert named == REGIONS, "region map names %d regions, expected %d" % (named, REGIONS)
	assert page.width <= 2048 and page.height <= 1024, "page is %dx%d" % page.size
	for x, y, w, h in [b for v in regions["figures"].values() for b in v]:
		assert x >= 0 and y >= 0 and x + w <= page.width and y + h <= page.height, \
			"region %s escapes the %dx%d page" % ([x, y, w, h], page.width, page.height)


def headroom(page, regions):
	"""How much clear space each figure leaves above its own head.

	The board draws one figure per cell and never outside it, so a figure taller
	than its cell would be cropped rather than overhanging -- but the gap printed
	here is what a column of eight has between one figure's head and the feet of
	the one above (ADR-0011 decision 2). It is measured on every bake because it
	moves with FIGURE_SCALE in tests/render_board_pieces.gd.
	"""
	worst = {}
	for key, boxes in sorted(regions["figures"].items()):
		for x, y, w, h in boxes:
			bbox = page.crop((x, y, x + w, y + h)).getbbox()
			if bbox is None:
				continue
			gap, tall = bbox[1], bbox[3] - bbox[1]
			if key not in worst or gap < worst[key][0]:
				worst[key] = (gap, tall)
	for key, (gap, tall) in sorted(worst.items(), key=lambda kv: kv[1][0]):
		print("headroom %-16s %3d px above the head, figure %3d px tall" % (key, gap, tall))
	assert min(v[0] for v in worst.values()) >= 0


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
	ap.add_argument("--keep", metavar="DIR", help="write the loose frames here instead of a temp dir")
	args = ap.parse_args()

	frame_dir = args.keep or tempfile.mkdtemp(prefix="pawnch_board_")
	try:
		count = render_frames(frame_dir, args.godot)
		page, regions = pack(frame_dir)
		verify(page, regions)
		headroom(page, regions)
	finally:
		if not args.keep:
			shutil.rmtree(frame_dir, ignore_errors=True)

	print("wrote %s %dx%d (%d KB)"
	      % (PAGE_PNG, page.width, page.height, os.path.getsize(PAGE_PNG) // 1024))
	print("wrote %s (%d figure frames)" % (REGION_JSON, count))


if __name__ == "__main__":
	main()

#!/usr/bin/env python3
"""Bake the board's piece atlas (ADR-0011 decision 3).

One command, from nothing:

    tools/bake_board_atlas.py

Renders the 72 board frames -- six piece types x two colours x six frames of the
pack's own `Idle Blinking` -- through tests/render_board_pieces.gd, draws the
four cell marks procedurally, packs the lot into a single page, and writes the
page and its region map to assets/board/.

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

from PIL import Image, ImageDraw, ImageFilter

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
# board now. What it does carry beside the figures is the four cell marks: they
# are quads out of this page precisely so they batch with the figures, where
# Day 4's draw_rect outlines cost +3..6 draw calls.
FIGURE_REGIONS = len(TYPES) * len(COLORS) * FRAMES
MARKS = ["move", "capture", "check", "selected"]
REGIONS = FIGURE_REGIONS + len(MARKS)

# Drawn at 4x and downscaled, because every mark has a curved edge and none of
# them may show a stair-step next to the figures' own antialiased silhouettes.
SS = 4

# Four marks, told apart by geometry first and colour second, so that a
# screenshot settles which is which without a colour-picker: a centred blob, an
# inscribed ring, a wash hugging the cell's edges, and a frame on them.
MOVE_COLOR = (56, 189, 248, 255)
CAPTURE_COLOR = (232, 52, 40, 255)
CHECK_COLOR = (255, 72, 40, 255)
SELECTED_COLOR = (245, 158, 11, 255)


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


def _mark_move():
	"""An empty square a piece may move to: a soft blob in the middle of the cell.

	Nothing stands on an empty square, so the centre is the one place on the cell
	that is guaranteed clear -- and a blob cannot be confused with the ring or
	either of the two edge marks at arm's length.
	"""
	alpha, w, h = _alpha_canvas()
	r = 32 * SS
	# Blurred on the full cell, not on a tight sub-image: clipping the blur at
	# the disc's own bounding box leaves a hard square edge where the falloff is
	# cut off, which is exactly what the first bake showed.
	ImageDraw.Draw(alpha).ellipse(
		[w // 2 - r, h // 2 - r, w // 2 + r, h // 2 + r], fill=236)
	return MOVE_COLOR, alpha.filter(ImageFilter.GaussianBlur(r * 0.30))


def _mark_capture():
	"""A square holding a piece that may be taken: a ring round the figure on it.

	Drawn over the character rather than under it -- a figure fills 123 of the
	cell's 135 px and hid all but a sliver of the first ring baked here -- and
	dropped to sit below the head, because the crest on that head is the board's
	only channel for what the piece is and a ring across it would cost more than
	it buys.
	"""
	alpha, w, _h = _alpha_canvas()
	r = 58 * SS
	cy = 106 * SS
	ImageDraw.Draw(alpha).ellipse(
		[w // 2 - r, cy - r, w // 2 + r, cy + r], outline=255, width=10 * SS)
	return CAPTURE_COLOR, alpha


def _mark_check():
	"""The attacked king's cell: a wash held against the cell's own edges.

	The king is standing in the middle of it, so a centred mark would be behind
	him. Ramping in from the edges leaves the figure legible and still reads as
	the whole square being on fire.
	"""
	alpha, w, h = _alpha_canvas(255)
	inset = 14 * SS
	ImageDraw.Draw(alpha).rounded_rectangle(
		[inset, inset, w - 1 - inset, h - 1 - inset], radius=18 * SS, fill=0)
	return CHECK_COLOR, alpha.filter(ImageFilter.GaussianBlur(16 * SS)) \
		.point(lambda v: int(v * 0.92))


def _mark_selected():
	"""The piece the finger is on: a frame on the cell's edges.

	The edges are the one part of the cell the figure never occupies, which is
	why this mark was already an outline before it moved onto the page.
	"""
	alpha, w, h = _alpha_canvas()
	m = 4 * SS
	ImageDraw.Draw(alpha).rounded_rectangle(
		[m, m, w - 1 - m, h - 1 - m], radius=16 * SS, outline=255, width=7 * SS)
	return SELECTED_COLOR, alpha


def _alpha_canvas(fill=0):
	w, h = CELL_W * SS, CELL_H * SS
	return Image.new("L", (w, h), fill), w, h


def marks():
	"""The four marks at cell size, one flat colour each with a shaped alpha.

	Colour and alpha are kept apart all the way down to the resize: downscaling a
	sparse RGBA drags the transparent pixels' black into every soft edge, which
	on the first bake put a grey box round the move glow.
	"""
	out = {}
	for name in MARKS:
		color, alpha = globals()["_mark_%s" % name]()
		image = Image.new("RGBA", (CELL_W, CELL_H), color)
		image.putalpha(alpha.resize((CELL_W, CELL_H), Image.LANCZOS))
		out[name] = image
	return out


def pack(frame_dir):
	rows = (REGIONS + COLUMNS - 1) // COLUMNS
	page_w = COLUMNS * CELL_W
	page_h = rows * CELL_H
	page = Image.new("RGBA", (page_w, page_h), (0, 0, 0, 0))

	regions = {"page": "res://assets/board/pieces.png", "cell": [CELL_W, CELL_H],
	           "frames": FRAMES, "figures": {}, "marks": {}}

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

	for name, image in marks().items():
		x = (index % COLUMNS) * CELL_W
		y = (index // COLUMNS) * CELL_H
		page.paste(image, (x, y))
		regions["marks"][name] = [x, y, CELL_W, CELL_H]
		index += 1

	os.makedirs(OUT_DIR, exist_ok=True)
	page.save(PAGE_PNG)
	with open(REGION_JSON, "w") as f:
		json.dump(regions, f, indent="\t", sort_keys=True)
		f.write("\n")
	return page, regions


def verify(page, regions):
	named = sum(len(v) for v in regions["figures"].values()) + len(regions["marks"])
	assert named == REGIONS, "region map names %d regions, expected %d" % (named, REGIONS)
	assert sorted(regions["marks"]) == sorted(MARKS), "marks are %s" % sorted(regions["marks"])
	assert page.width <= 2048 and page.height <= 1024, "page is %dx%d" % page.size
	boxes = [b for v in regions["figures"].values() for b in v] + list(regions["marks"].values())
	for x, y, w, h in boxes:
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
	print("wrote %s (%d figure frames, %d marks)" % (REGION_JSON, count, len(MARKS)))


if __name__ == "__main__":
	main()

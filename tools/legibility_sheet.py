#!/usr/bin/env python3
"""The legibility contact sheet -- the check nobody has ever run.

ADR-0003's test is a human judgement: "identifiable filled solid black at 110 px
tall". ADR-0007 decision 8 ran it against a script's own composite and fixed what
it found with a crest, but no *person* has ever been shown these six, and the
weapon half of identity did not exist until Day 7. This builds the sheet to show
one.

    tools/legibility_sheet.py

Three bands per side, each at its true on-screen size, so nothing here flatters
itself by being bigger than the game draws it:

    silhouette  110 px, filled solid black, crest and weapon both -- ADR-0003's test
    crest        30 px, the crest alone, the size the board draws it (ADR-0011 d4)
    duel        the pair at duel-panel scale, which is where the weapon earns its place

The six tiles in each band are numbered, in an order shuffled per band from a
fixed seed, and **the key is printed to stdout and never drawn on the sheet** --
a labelled sheet cannot be shown to someone and asked "what is this one".

Output goes to docs/media/, which carries a .gdignore: images anywhere else under
the project get imported by Godot and shipped in the APK.

Craftpix licence: pack art is rasterised and composited here, never fed to an
image model (clause 3.1.1).
"""
import argparse
import os
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "media")
GODOT = os.environ.get("GODOT", "godot")

TYPES = ["pawn", "knight", "bishop", "rook", "queen", "king"]
FAMILIES = ["valkyrie", "skeleton_warrior"]

# scenes/duel_panel.tscn mounts both rigs at 0.52, and the duel panel is the
# device's own 1080 px short edge tall, so this band is 1:1 with the pixels a
# player sees. It was 0.714 until Day 8 restaged the panel to stop the figures
# being clipped by its edges, and 0.45 for the few hours between that restage and
# the landscape flip, which gave the height back. Keep this in step with the
# scene or the band stops being 1:1, which is the only thing it is for.
DUEL_MOUNT_SCALE = 0.52
SILHOUETTE_PX = 110   # ADR-0003's test height.
CREST_PX = 30         # what the board draws (ADR-0011 decision 4).

# Mid grey: a black silhouette and a bone-white skeleton both have to read
# against it, which rules out either end of the range.
BACKGROUND = (154, 160, 166, 255)
INK = (24, 24, 27, 255)
PAD = 28
SEED = 20260819


def font(size):
	for path in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
	             "/System/Library/Fonts/Helvetica.ttc"):
		if os.path.exists(path):
			return ImageFont.truetype(path, size)
	return ImageFont.load_default(size=size)


def render(out_dir):
	"""tests/render_legibility.gd -- twelve transparent figures, one per type per side."""
	cmd = [GODOT, "--rendering-driver", "opengl3", "--resolution", "200x200",
	       "--script", "tests/render_legibility.gd", "--", out_dir]
	proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
	if proc.returncode != 0:
		sys.stdout.write(proc.stdout + proc.stderr)
		raise SystemExit("godot render failed")


def union_box(images):
	"""One bounding box for all six, so the six scale identically.

	Per-figure cropping would silently make the type with the longest weapon the
	smallest character on the sheet, which is the opposite of what a size-sensitive
	legibility test wants to show.
	"""
	boxes = [im.split()[3].getbbox() for im in images]
	return (min(b[0] for b in boxes), min(b[1] for b in boxes),
	        max(b[2] for b in boxes), max(b[3] for b in boxes))


def scaled(im, box, height):
	tile = im.crop(box)
	w = max(1, round(tile.width * height / tile.height))
	return tile.resize((w, height), Image.LANCZOS)


def blacken(im):
	"""Alpha -> solid black. ADR-0003's test is the outline and nothing else."""
	out = Image.new("RGBA", im.size, (0, 0, 0, 0))
	out.paste(Image.new("RGBA", im.size, (0, 0, 0, 255)), (0, 0), im.split()[3])
	return out


def crest_tile(piece_type, height):
	with Image.open(os.path.join(ROOT, "assets", "rig", "crest_%s.png" % piece_type)) as im:
		im = im.convert("RGBA")
		return scaled(im, im.split()[3].getbbox(), height)


HEAD = 46   # label strip above each band
FOOT = 40   # numbers below it


def band(images, height, label, order, width, f_num, f_label):
	"""One row of the sheet: a label, then the six tiles in `order`, each numbered.

	The tiles are grouped at their own natural spacing and that group is centred
	in `width`, rather than each band being stretched across six shared columns:
	six 110 px silhouettes 800 px apart cannot be compared at a glance, and
	comparing them at a glance is the whole test.
	"""
	cell_w = max(t.width for t in images.values()) + PAD
	sheet = Image.new("RGBA", (width, HEAD + height + FOOT), BACKGROUND)
	draw = ImageDraw.Draw(sheet)
	draw.text((PAD, 12), label, font=f_label, fill=INK)
	left = (width - len(order) * cell_w) // 2
	for i, piece_type in enumerate(order):
		tile = images[piece_type]
		x = left + i * cell_w + (cell_w - tile.width) // 2
		sheet.alpha_composite(tile, (x, HEAD + height - tile.height))
		draw.text((left + i * cell_w + cell_w // 2, HEAD + height + 8), str(i + 1),
		          font=f_num, fill=INK, anchor="ma")
	return sheet


def sheet_for(family, frames, out_path):
	raw = {t: Image.open(os.path.join(frames, "%s_%s.png" % (family, t))).convert("RGBA")
	       for t in TYPES}
	box = union_box(list(raw.values()))
	duel_px = round((box[3] - box[1]) * DUEL_MOUNT_SCALE)

	rows = (
		({t: blacken(scaled(raw[t], box, SILHOUETTE_PX)) for t in TYPES},
		 SILHOUETTE_PX, "A  silhouette, %d px, filled solid black" % SILHOUETTE_PX),
		({t: crest_tile(t, CREST_PX) for t in TYPES},
		 CREST_PX, "B  crest alone, %d px, board scale" % CREST_PX),
		({t: scaled(raw[t], box, duel_px) for t in TYPES},
		 duel_px, "C  crest and weapon at duel-panel scale, %d px" % duel_px),
	)
	width = max(len(TYPES) * (max(t.width for t in tiles.values()) + PAD)
	            for tiles, _h, _l in rows)

	rng = random.Random(SEED)
	orders = []
	sheet = Image.new("RGBA", (width, sum(HEAD + h + FOOT for _t, h, _l in rows)), BACKGROUND)
	y = 0
	for tiles, height, label in rows:
		# Shuffled per band, so a reader cannot carry an answer from one band to
		# the next -- band C shows the weapon in colour and would give A away.
		order = TYPES[:]
		rng.shuffle(order)
		orders.append((label.split()[0], order))
		sheet.alpha_composite(band(tiles, height, label, order, width, font(26), font(24)), (0, y))
		y += HEAD + height + FOOT
	sheet.save(out_path)
	return out_path, orders


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("--frames", help="skip the Godot run and use figures already rendered here")
	ap.add_argument("--out", default=OUT_DIR)
	args = ap.parse_args()

	os.makedirs(args.out, exist_ok=True)
	workdir = tempfile.mkdtemp(prefix="pawnch-legibility-")
	try:
		frames = args.frames or os.path.join(workdir, "figures")
		if not args.frames:
			render(frames)
		for family in FAMILIES:
			path, orders = sheet_for(
				family, frames, os.path.join(args.out, "day7-legibility-%s.png" % family))
			with Image.open(path) as im:
				print("sheet   %s %dx%d" % (path, im.width, im.height))
			for label, order in orders:
				print("key %s   %s" % (label, "  ".join(
					"%d=%s" % (i + 1, t) for i, t in enumerate(order))))
	finally:
		shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
	main()

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
import glob
import math
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "board")
PAGE_PNG = os.path.join(OUT_DIR, "pieces.png")
REGION_JSON = os.path.join(OUT_DIR, "pieces.json")

CELL_W, CELL_H = 135, 135
HERO_W, HERO_H = 300, 300
FRAMES = 6
COLUMNS = 15  # 15 * 135 = 2025, inside the 2048 page limit

TYPES = ["pawn", "knight", "bishop", "rook", "queen", "king"]
# The renderer names its output by pack family; the board thinks in colours.
COLORS = {"white": "valkyrie", "black": "skeleton_warrior"}

# The commander standing at the end of each margin (board-view spec). Neither is
# a piece and neither is rigged: one still frame each is the whole asset, so it
# comes straight out of the pack .zip rather than through a second importer
# (ADR-0009 -- the pipeline is code, not that every asset needs a rig).
#
# Chosen for what they say without words. The fallen angel shares the valkyrie's
# silver-and-white palette and her grey hair, so she reads as that army's own
# senior rather than as a visitor; the necromancer is the character who would
# have raised these skeletons, which is an explanation a six-year-old gets for
# free in a game with twelve strings and no localisation.
#
# Swapping either commander is this table and a re-bake. Nothing downstream
# knows which character it is.
HEROES = {
	"white": ("free-fallen-angel",
	          "Fallen_Angels_1/PNG/PNG Sequences/Idle Blinking/"
	          "0_Fallen_Angels_Idle Blinking_000.png"),
	"black": ("necromancer-of-the-shadow",
	          "Necromancer_of_the_Shadow_1/PNG/PNG Sequences/Idle Blinking/"
	          "0_Necromancer_of_the_Shadow_Idle Blinking_000.png"),
}
DONOR_PACK_DIR = os.path.expanduser("~/Downloads")
HERO_PAD = 8

# The page held six tile crest glyphs for one afternoon. They are gone with
# ADR-0011 decision 4's reversal -- the head crest is the only type channel on the
# board now. What it does carry beside the figures is the four cell marks: they
# are quads out of this page precisely so they batch with the figures, where
# Day 4's draw_rect outlines cost +3..6 draw calls.
FIGURE_REGIONS = len(TYPES) * len(COLORS) * FRAMES
CREST_REGIONS = len(TYPES) * len(COLORS)
MARKS = ["move", "capture", "check", "selected", "last_move"]
# The pause and take-back controls, on this page for exactly the reason the
# marks are: the margins batch into one unbroken run of textured quads, and two
# buttons drawn with draw_rect would break it and cost the draw calls Day 4
# measured. A control is a whole button -- plate, edge and glyph in one quad --
# rather than a flat colour with a shaped alpha, because it has two tones.
CONTROLS = ["pause", "takeback"]
# The pool of light the active commander stands in (board-view spec). It is on
# the page with its colour already in it rather than being the destination
# blob's region tinted gold, which is what the first attempt did: modulate
# *multiplies*, and gold times the blob's cyan is a pale green nobody reads as
# emphasis. A flat-coloured region and a white modulate is the only way to get
# a colour out of this page that is not already on it.
HUD = ["pedestal"]
# Everything on the 135 grid. The two commanders are 300 px and go on their own
# strip under it, because they do not divide into the cell.
REGIONS = FIGURE_REGIONS + CREST_REGIONS + len(MARKS) + len(CONTROLS) + len(HUD)

# Drawn at 4x and downscaled, because every mark has a curved edge and none of
# them may show a stair-step next to the figures' own antialiased silhouettes.
SS = 4

# Five marks, told apart by geometry first and colour second, so that a
# screenshot settles which is which without a colour-picker: a centred blob, a
# wash hugging the cell's edges, and three nested edge marks -- a frame flush to
# them, a rounded frame 4 px in, brackets on the corners 9 px in.
MOVE_COLOR = (56, 189, 248, 255)
CAPTURE_COLOR = (232, 52, 40, 255)
CHECK_COLOR = (255, 72, 40, 255)
SELECTED_COLOR = (245, 158, 11, 255)
# Deliberately nowhere near the other four, which are all warm or cyan: this is
# the only mark that reports something the player cannot act on.
LAST_MOVE_COLOR = (167, 139, 250, 255)
PEDESTAL_COLOR = (255, 205, 68, 255)


def render_frames(out_dir, godot):
	proc = subprocess.run(
		[godot, "--rendering-driver", "opengl3", "--path", ROOT,
		 "--script", "tests/render_board_pieces.gd", "--", out_dir],
		cwd=ROOT, capture_output=True, text=True)
	written = [l for l in proc.stdout.splitlines() if l.startswith("PAWNCH_BAKE wrote ")]
	for line in proc.stdout.splitlines():
		if line.startswith("PAWNCH_BAKE") and not line.startswith("PAWNCH_BAKE wrote "):
			print(line)
	expected = FIGURE_REGIONS + CREST_REGIONS
	if proc.returncode != 0 or len(written) != expected:
		sys.stderr.write(proc.stdout + proc.stderr)
		raise SystemExit("render_board_pieces.gd wrote %d frames, expected %d"
		                 % (len(written), expected))
	return FIGURE_REGIONS


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
	"""A square holding a piece that may be taken: a frame on the cell's edges.

	**This was a red ring until Day 9, and the ring was the only round thing on a
	board that otherwise speaks in squares.** It read as a different kind of
	statement rather than as a different statement, and on a cell carrying the
	last-move brackets as well -- which happens every time the opponent moves a
	piece the player can then take -- the circle cut across the brackets' corners
	and the two marks fought. Squaring it puts all three edge marks in one family
	told apart by inset, weight and colour: this one flush to the edge, the
	selection frame 4 px in and rounded, the last-move brackets 9 px in.

	Flush to the edge and not inset any further, because the two marks that can
	share a cell must not touch: 0..7 here against the brackets' 9..16 leaves a
	2 px gap of bare square between them, which is what makes a cell carrying both
	read as two marks rather than as one thick two-tone border. Insetting this one
	instead -- drawing it *inside* the brackets, at 20 px -- was rendered and
	rejected: it puts a red box across the figure's face and over the head crest,
	which is the board's only channel for what the piece is.

	The selection frame's own 4..11 band overlaps this one, and that is safe
	rather than lucky: a capturable piece belongs to the other side, so the two
	marks cannot land on the same cell.
	"""
	alpha, w, h = _alpha_canvas()
	t = 7 * SS  # the selection frame's own stroke, so the three read as one family
	ImageDraw.Draw(alpha).rectangle([0, 0, w - 1, h - 1], outline=255, width=t)
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


def _mark_last_move():
	"""The two squares the opponent's move joined: brackets on the cell's corners.

	The pair always lands on one empty cell and one with a figure standing in it,
	so the mark has to survive both -- which rules out anything centred, because
	the figure buries it, and rules out a wash, because the empty half of the pair
	would then be the only half anyone sees. The edges are the one part of a cell
	a figure leaves clear, and this is drawn over the figures for the same reason
	the selection frame is.

	Broken at the middle of every side, where the selection frame is continuous.
	That gap is what tells the two apart before their colours are compared, and
	neither can be mistaken for the blob or the ring -- the two marks that mean
	"you may go here" both sit in the middle of the cell, and this one never does.
	"""
	alpha, w, h = _alpha_canvas()
	draw = ImageDraw.Draw(alpha)
	t = 7 * SS  # the selection frame's own stroke, so the two read as one family
	m = 9 * SS  # inside it, so a cell carrying both shows two separate marks
	arm_x, arm_y = 40 * SS, 46 * SS
	for x in (m, w - 1 - m):
		for y in (m, h - 1 - m):
			dx = arm_x if x == m else -arm_x
			dy = arm_y if y == m else -arm_y
			draw.rectangle(_box(x, y, x + dx, y + (t if y == m else -t)), fill=255)
			draw.rectangle(_box(x, y, x + (t if x == m else -t), y + dy), fill=255)
	return LAST_MOVE_COLOR, alpha


# The controls' own palette, carried over from the turn card this change
# deleted: a near-black plate with a gold edge was already the game's one HUD
# treatment, and reusing it means the buttons look like they belong to a screen
# they arrived on after everything else.
PLATE_COLOR = (23, 26, 33, 235)
PLATE_EDGE = (245, 158, 11, 255)
GLYPH_COLOR = (245, 158, 11, 255)


def _plate():
	"""The button under both glyphs: a rounded plate with a gold edge."""
	w, h = CELL_W * SS, CELL_H * SS
	image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	m = 4 * SS
	draw.rounded_rectangle([m, m, w - 1 - m, h - 1 - m], radius=24 * SS,
	                       fill=PLATE_COLOR, outline=PLATE_EDGE, width=5 * SS)
	return image, draw, w, h


def _control_pause():
	"""Two bars: the one glyph a child who cannot read already knows from a phone."""
	image, draw, w, h = _plate()
	bar, tall, gap = 14 * SS, 54 * SS, 18 * SS
	for sign in (-1, 1):
		cx = w // 2 + sign * (gap + bar) // 2
		draw.rounded_rectangle(_box(cx - bar // 2, h // 2 - tall // 2,
		                            cx + bar // 2, h // 2 + tall // 2),
		                       radius=5 * SS, fill=GLYPH_COLOR)
	return image


def _control_takeback():
	"""An arrow curving anticlockwise back on itself: put the last move back.

	Deliberately the mirror of the banner's restart arrow rather than a second
	idea: one turns forward and starts again, this one turns backward and undoes,
	and a child reading them side by side gets the difference from the direction
	alone.
	"""
	image, draw, w, h = _plate()
	r = 30 * SS
	cx, cy = w // 2, h // 2 + 3 * SS
	# PIL measures clockwise from 3 o'clock on a y-down canvas, so this leaves
	# the gap at the top and the two ends of the stroke either side of it. The
	# head goes on the 300 deg end and points left, which is the end an
	# anticlockwise stroke arrives at -- put on the other end it drew a
	# convincing *redo* arrow, which is the one thing this must not say.
	draw.arc([cx - r, cy - r, cx + r, cy + r], start=300, end=240,
	         width=11 * SS, fill=GLYPH_COLOR)
	# Built from the tangent rather than from three hand-placed points: an
	# arrowhead that is merely *near* the end of a stroke reads as pointing
	# wherever its longest edge happens to lie, and the first two attempts here
	# both came out as a convincing *redo* arrow.
	theta = math.radians(300)
	tip = (cx + r * math.cos(theta), cy + r * math.sin(theta))
	# Anticlockwise on a y-down canvas is theta decreasing, so this is where the
	# stroke is travelling when it arrives.
	dx, dy = math.sin(theta), -math.cos(theta)
	head = 26 * SS
	draw.polygon([(tip[0] + dx * head, tip[1] + dy * head),
	              (tip[0] - dy * head * 0.62, tip[1] + dx * head * 0.62),
	              (tip[0] + dy * head * 0.62, tip[1] - dx * head * 0.62)],
	             fill=GLYPH_COLOR)
	return image


def _hud_pedestal():
	"""A soft pool of light, stretched flat under the active commander's boots.

	Drawn as a disc and not an ellipse: the board draws it into a 460 x 190 quad,
	so the flattening is the quad's job and a disc keeps the falloff even.
	"""
	alpha, w, h = _alpha_canvas()
	r = 46 * SS
	ImageDraw.Draw(alpha).ellipse(
		[w // 2 - r, h // 2 - r, w // 2 + r, h // 2 + r], fill=242)
	image = Image.new("RGBA", (CELL_W, CELL_H), PEDESTAL_COLOR)
	image.putalpha(alpha.filter(ImageFilter.GaussianBlur(r * 0.34))
	               .resize((CELL_W, CELL_H), Image.LANCZOS))
	return image


def hud():
	return {"pedestal": _hud_pedestal()}


def controls():
	"""The two buttons at cell size, plate and glyph already composited."""
	return {name: globals()["_control_%s" % name]().resize(
		(CELL_W, CELL_H), Image.LANCZOS) for name in CONTROLS}


def _box(x0, y0, x1, y1):
	return [min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)]


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


def heroes(packs_dir=DONOR_PACK_DIR):
	"""One idle frame per commander, out of the pack .zip, fitted to HERO_CELL.

	The same convention the board figures use -- width centred, feet on the
	bottom pad -- so a commander and the graveyard under it stand on lines that
	agree. Nothing here goes near an image model (Craftpix clause 3.1.1); it is a
	crop and a Lanczos resize.
	"""
	out = {}
	for color, (pattern, member) in HEROES.items():
		zips = sorted(glob.glob(os.path.join(packs_dir, "*%s*.zip" % pattern)))
		if len(zips) != 1:
			raise SystemExit("expected one *%s*.zip in %s, found %d"
			                 % (pattern, packs_dir, len(zips)))
		with zipfile.ZipFile(zips[0]) as z:
			with z.open(member) as f:
				src = Image.open(f).convert("RGBA")
				src.load()
		src = src.crop(src.getbbox())
		room_w, room_h = HERO_W - 2 * HERO_PAD, HERO_H - 2 * HERO_PAD
		scale = min(room_w / src.width, room_h / src.height)
		figure = src.resize((max(1, round(src.width * scale)),
		                     max(1, round(src.height * scale))), Image.LANCZOS)
		cell = Image.new("RGBA", (HERO_W, HERO_H), (0, 0, 0, 0))
		cell.alpha_composite(figure, ((HERO_W - figure.width) // 2,
		                              HERO_H - HERO_PAD - figure.height))
		print("PAWNCH_BAKE hero %-5s %-28s %dx%d from %s"
		      % (color, pattern, figure.width, figure.height, os.path.basename(zips[0])))
		out[color] = cell
	return out


def pack(frame_dir):
	rows = (REGIONS + COLUMNS - 1) // COLUMNS
	page_w = COLUMNS * CELL_W
	grid_h = rows * CELL_H
	page_h = grid_h + HERO_H
	page = Image.new("RGBA", (page_w, page_h), (0, 0, 0, 0))

	regions = {"page": "res://assets/board/pieces.png", "cell": [CELL_W, CELL_H],
	           "hero_cell": [HERO_W, HERO_H],
	           "frames": FRAMES, "figures": {}, "crests": {}, "marks": {},
	           "controls": {}, "hud": {}, "heroes": {}}

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

	# The crest of each piece on its own, in register with the figure above it.
	# The graveyard dims the body and draws this over it at full colour; without
	# it, dimming a fallen bishop takes the turquoise that says "bishop" with it.
	for color, family in COLORS.items():
		for type_name in TYPES:
			src = os.path.join(frame_dir, "%s_%s_crest.png" % (family, type_name))
			x = (index % COLUMNS) * CELL_W
			y = (index // COLUMNS) * CELL_H
			page.paste(Image.open(src), (x, y))
			regions["crests"]["%s_%s" % (color, type_name)] = [x, y, CELL_W, CELL_H]
			index += 1

	for group, images in (("marks", marks()), ("controls", controls()), ("hud", hud())):
		for name, image in images.items():
			x = (index % COLUMNS) * CELL_W
			y = (index // COLUMNS) * CELL_H
			page.paste(image, (x, y))
			regions[group][name] = [x, y, CELL_W, CELL_H]
			index += 1

	# The two commanders, on their own strip under the grid: 300 px does not
	# divide into the 135 cell, and squeezing them in would cost more page than
	# a strip does.
	for slot, (color, image) in enumerate(sorted(heroes(DONOR_PACK_DIR).items())):
		x = slot * HERO_W
		page.paste(image, (x, grid_h))
		regions["heroes"][color] = [x, grid_h, HERO_W, HERO_H]

	os.makedirs(OUT_DIR, exist_ok=True)
	page.save(PAGE_PNG)
	with open(REGION_JSON, "w") as f:
		json.dump(regions, f, indent="\t", sort_keys=True)
		f.write("\n")
	return page, regions


def verify(page, regions):
	named = (sum(len(v) for v in regions["figures"].values())
	         + len(regions["crests"]) + len(regions["marks"]) + len(regions["controls"])
	         + len(regions["hud"]))
	assert named == REGIONS, "region map names %d regions, expected %d" % (named, REGIONS)
	assert sorted(regions["marks"]) == sorted(MARKS), "marks are %s" % sorted(regions["marks"])
	assert sorted(regions["controls"]) == sorted(CONTROLS), \
		"controls are %s" % sorted(regions["controls"])
	assert sorted(regions["hud"]) == sorted(HUD), "hud is %s" % sorted(regions["hud"])
	assert sorted(regions["crests"]) == sorted(regions["figures"]), "crests do not match figures"
	assert sorted(regions["heroes"]) == sorted(COLORS), "heroes are %s" % sorted(regions["heroes"])
	# Was `height <= 1024`, which was a description of the page's then-current
	# shape rather than a limit: the commander strip takes it to 1110 and the
	# number that actually matters on an Adreno 610 is 2048 on both axes.
	assert page.width <= 2048 and page.height <= 2048, "page is %dx%d" % page.size
	boxes = ([b for v in regions["figures"].values() for b in v]
	         + list(regions["crests"].values()) + list(regions["marks"].values())
	         + list(regions["controls"].values()) + list(regions["hud"].values())
	         + list(regions["heroes"].values()))
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
	ap.add_argument("--packs", default=DONOR_PACK_DIR, metavar="DIR",
	                help="directory holding the commander pack .zip files (default: %(default)s)")
	args = ap.parse_args()

	globals()["DONOR_PACK_DIR"] = args.packs
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
	print("wrote %s (%d figure frames, %d crests, %d marks, %d controls, %d hud, %d heroes)"
	      % (REGION_JSON, count, CREST_REGIONS, len(MARKS), len(CONTROLS), len(HUD),
	         len(COLORS)))


if __name__ == "__main__":
	main()

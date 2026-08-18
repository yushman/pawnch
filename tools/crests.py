#!/usr/bin/env python3
# Procedural chess-piece crests (ADR-0007 decision 8): pawn/knight/bishop/rook/queen/king,
# drawn by code with no art-pack lineage, mounted rigidly on the head. Specify 18% of
# character height with a 12% floor; SIZE below is the raster canvas, not that fraction.
#
# Shapes are drawn solid black, then styled: the packs' own parts are a flat colour fill
# with a thick black outline, and a solid black crest reads as a hole rather than a piece
# of kit. Styling only recolours the RGB channels inside the silhouette the 110 px test
# was run against; the alpha (outer edge) is untouched.
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "rig")
SIZE = 256

# Outline weight, measured from assets/rig/valkyrie/head.png (the part the crest sits on):
# scanning inward from the alpha silhouette edge, the black outline is ~25 px thick on an
# 840 px canvas (10th percentile of edge-run lengths from row and column scans, which
# discards the handful of diagonal edges that inflate a straight inward scan). Kept as a
# fraction of SIZE so it scales with the crest instead of being a guessed pixel value.
OUTLINE_FRACTION = 25 / 840
OUTLINE = round(SIZE * OUTLINE_FRACTION)

# Saturated amber/gold: both packs are desaturated grey, bone and tan, so this reads
# against the silver valkyrie and the bone skeleton alike and collides with nothing else
# on screen.
FILL = (245, 158, 11, 255)


def _canvas(S):
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	return im, ImageDraw.Draw(im)


def _style(silhouette):
	"""Solid black shape -> flat FILL with a black outline OUTLINE px thick.

	Erodes the silhouette's alpha mask by OUTLINE px to get the interior; the ring
	between that and the original edge stays black, the interior becomes FILL. The
	outer edge -- the shape the 110 px silhouette test ran against -- never moves.
	"""
	alpha = silhouette.split()[3]
	interior = alpha.filter(ImageFilter.MinFilter(OUTLINE * 2 + 1))
	out = Image.new("RGBA", silhouette.size, (0, 0, 0, 0))
	out.paste(Image.new("RGBA", silhouette.size, (0, 0, 0, 255)), (0, 0), alpha)
	out.paste(Image.new("RGBA", silhouette.size, FILL), (0, 0), interior)
	return out


def pawn(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.ellipse([32 * u, 8 * u, 68 * u, 44 * u], fill=(0, 0, 0, 255))
	d.polygon([(38 * u, 42 * u), (62 * u, 42 * u), (70 * u, 92 * u), (30 * u, 92 * u)], fill=(0, 0, 0, 255))
	d.rectangle([24 * u, 88 * u, 76 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


def knight(S=SIZE):
	# horse head in profile, facing right to match the rig
	im, d = _canvas(S)
	u = S / 100.0
	pts = [(32, 86), (24, 62), (28, 40), (36, 28), (38, 10), (50, 26),
	       (58, 8), (66, 28), (80, 38), (90, 52), (82, 60), (64, 57),
	       (58, 70), (60, 86)]
	d.polygon([(x * u, y * u) for x, y in pts], fill=(0, 0, 0, 255))
	d.rectangle([26 * u, 82 * u, 70 * u, 90 * u], fill=(0, 0, 0, 255))
	d.rectangle([20 * u, 90 * u, 78 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


def bishop(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.polygon([(50 * u, 4 * u), (70 * u, 40 * u), (66 * u, 74 * u), (34 * u, 74 * u), (30 * u, 40 * u)],
	          fill=(0, 0, 0, 255))
	d.rectangle([26 * u, 72 * u, 74 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([22 * u, 88 * u, 78 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


def rook(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	for x0 in (22, 42, 62):
		d.rectangle([x0 * u, 6 * u, (x0 + 16) * u, 30 * u], fill=(0, 0, 0, 255))
	d.rectangle([22 * u, 26 * u, 78 * u, 42 * u], fill=(0, 0, 0, 255))
	d.polygon([(32 * u, 40 * u), (68 * u, 40 * u), (72 * u, 86 * u), (28 * u, 86 * u)], fill=(0, 0, 0, 255))
	d.rectangle([20 * u, 86 * u, 80 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


def queen(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	pts = [(18, 34), (28, 10), (38, 34), (50, 6), (62, 34), (72, 10), (82, 34), (76, 70), (24, 70)]
	d.polygon([(x * u, y * u) for x, y in pts], fill=(0, 0, 0, 255))
	for cx in (28, 50, 72):
		d.ellipse([(cx - 8) * u, 2 * u, (cx + 8) * u, 18 * u], fill=(0, 0, 0, 255))
	d.rectangle([26 * u, 66 * u, 74 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([20 * u, 86 * u, 80 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


def king(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.rectangle([44 * u, 0, 56 * u, 26 * u], fill=(0, 0, 0, 255))
	d.rectangle([34 * u, 8 * u, 66 * u, 20 * u], fill=(0, 0, 0, 255))
	pts = [(20, 60), (24, 30), (38, 44), (50, 26), (62, 44), (76, 30), (80, 60)]
	d.polygon([(x * u, y * u) for x, y in pts], fill=(0, 0, 0, 255))
	d.rectangle([24 * u, 56 * u, 76 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([18 * u, 86 * u, 82 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im)


ALL = {"pawn": pawn, "knight": knight, "bishop": bishop,
       "rook": rook, "queen": queen, "king": king}


def main():
	os.makedirs(OUT, exist_ok=True)
	for name, fn in ALL.items():
		img = fn()
		path = os.path.join(OUT, f"crest_{name}.png")
		img.save(path)
		print(f"wrote {path} {img.size}")


# Guarded so tools/bake_board_atlas.py can import the six shape functions for the
# tile glyphs without rewriting assets/rig/ as a side effect (ADR-0011 decision 4:
# one set of shapes at two sizes).
if __name__ == "__main__":
	main()

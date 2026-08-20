#!/usr/bin/env python3
# Procedural chess-piece crests (ADR-0007 decision 8): pawn/knight/bishop/rook/queen/king,
# drawn by code with no art-pack lineage, mounted rigidly on the head. Specify 25% of
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

# One hue per piece type, so colour is a second channel behind the shape (the shape still
# carries the whole meaning on its own -- someone who cannot separate the hues still has the
# six outlines). ADR-0007's rationale for the single amber these replace was that both packs
# are desaturated grey, bone and tan, so a saturated hue reads against them and "collides
# with nothing else on screen". Measured against that same bar, the amber failed the second
# half of it, which is why this table is not just amber plus five friends:
#
#   dE00(amber, marks.selected)  =  0.0   -- the crest was the *same colour* as the
#                                            "this piece is selected" frame
#   dE00(amber, valkyrie tan)    = 16.8   -- and 17 from the character's own skin and hair
#   dE00(amber, light square)    = 23.7
#
# Derivation, not taste. The board is warm -- light square (237,222,189) at hue 40 deg, dark
# square (125,89,61) at 25 deg -- and three of the five cell marks live in that same band
# (capture 6 deg, check 12 deg, selected 38 deg). So the crest palette is the complement of
# it: six hues spread over 60..340 deg, avoiding the move blob (199 deg) and the last-move
# violet (258 deg), ordered by piece value so the mapping is a rule rather than six choices.
# Chroma is held above C*=48 and lightness inside L* 45..90, because a crest is ~40 px on the
# board inside a thick black outline: a dark fill disappears into the outline and a pale one
# into the light square.
#
# Measured on the numbers this table shipped with (CIEDE2000, sRGB):
#
#   worst pair among the six       queen/rook            23.3
#   nearest non-crest colour       rook / last-move mark 19.9
#   nearest body colour            bishop / valk silver  24.2
#
# The body colours are the twelve most common opaque pixels of the two families sampled off
# the board bake, i.e. what the crest actually sits on: valkyrie black/grey 64..128, tan
# (176,144,96), silver (192,192,176); skeleton bone (176,160,144), olive (128,128,112),
# white (192,192,192).
FILLS = {
	"pawn": (200, 240, 0, 255),      # lime      h  70  L* 89.2  C* 94.3
	"knight": (0, 179, 45, 255),     # green     h 135  L* 63.7  C* 83.9
	"bishop": (0, 222, 205, 255),    # turquoise h 175  L* 80.0  C* 48.4
	"rook": (30, 110, 240, 255),     # blue      h 217  L* 49.2  C* 76.0
	"queen": (160, 43, 230, 255),    # violet    h 277  L* 45.5  C* 102.8
	"king": (255, 61, 158, 255),     # rose      h 330  L* 59.0  C* 78.1
}


def _canvas(S):
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	return im, ImageDraw.Draw(im)


def _style(silhouette, fill):
	"""Solid black shape -> flat `fill` with a black outline OUTLINE px thick.

	Erodes the silhouette's alpha mask by OUTLINE px to get the interior; the ring
	between that and the original edge stays black, the interior becomes `fill`. The
	outer edge -- the shape the 110 px silhouette test ran against -- never moves,
	so the colour is strictly an added channel and the six outlines are unchanged.
	"""
	alpha = silhouette.split()[3]
	interior = alpha.filter(ImageFilter.MinFilter(OUTLINE * 2 + 1))
	out = Image.new("RGBA", silhouette.size, (0, 0, 0, 0))
	out.paste(Image.new("RGBA", silhouette.size, (0, 0, 0, 255)), (0, 0), alpha)
	out.paste(Image.new("RGBA", silhouette.size, fill), (0, 0), interior)
	return out


def pawn(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.ellipse([32 * u, 8 * u, 68 * u, 44 * u], fill=(0, 0, 0, 255))
	d.polygon([(38 * u, 42 * u), (62 * u, 42 * u), (70 * u, 92 * u), (30 * u, 92 * u)], fill=(0, 0, 0, 255))
	d.rectangle([24 * u, 88 * u, 76 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im, FILLS["pawn"])


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
	return _style(im, FILLS["knight"])


def bishop(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.polygon([(50 * u, 4 * u), (70 * u, 40 * u), (66 * u, 74 * u), (34 * u, 74 * u), (30 * u, 40 * u)],
	          fill=(0, 0, 0, 255))
	d.rectangle([26 * u, 72 * u, 74 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([22 * u, 88 * u, 78 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im, FILLS["bishop"])


def rook(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	for x0 in (22, 42, 62):
		d.rectangle([x0 * u, 6 * u, (x0 + 16) * u, 30 * u], fill=(0, 0, 0, 255))
	d.rectangle([22 * u, 26 * u, 78 * u, 42 * u], fill=(0, 0, 0, 255))
	d.polygon([(32 * u, 40 * u), (68 * u, 40 * u), (72 * u, 86 * u), (28 * u, 86 * u)], fill=(0, 0, 0, 255))
	d.rectangle([20 * u, 86 * u, 80 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im, FILLS["rook"])


def queen(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	pts = [(18, 34), (28, 10), (38, 34), (50, 6), (62, 34), (72, 10), (82, 34), (76, 70), (24, 70)]
	d.polygon([(x * u, y * u) for x, y in pts], fill=(0, 0, 0, 255))
	for cx in (28, 50, 72):
		d.ellipse([(cx - 8) * u, 2 * u, (cx + 8) * u, 18 * u], fill=(0, 0, 0, 255))
	d.rectangle([26 * u, 66 * u, 74 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([20 * u, 86 * u, 80 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im, FILLS["queen"])


def king(S=SIZE):
	im, d = _canvas(S)
	u = S / 100.0
	d.rectangle([44 * u, 0, 56 * u, 26 * u], fill=(0, 0, 0, 255))
	d.rectangle([34 * u, 8 * u, 66 * u, 20 * u], fill=(0, 0, 0, 255))
	pts = [(20, 60), (24, 30), (38, 44), (50, 26), (62, 44), (76, 30), (80, 60)]
	d.polygon([(x * u, y * u) for x, y in pts], fill=(0, 0, 0, 255))
	d.rectangle([24 * u, 56 * u, 76 * u, 84 * u], fill=(0, 0, 0, 255))
	d.rectangle([18 * u, 86 * u, 82 * u, 100 * u], fill=(0, 0, 0, 255))
	return _style(im, FILLS["king"])


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

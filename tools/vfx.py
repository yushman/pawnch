#!/usr/bin/env python3
# Procedural impact burst (Block B, knight-takes-pawn-clash): one chunky PvZ-style
# starburst, drawn the same way tools/crests.py draws crests -- PIL, flat fill,
# thick black outline -- so the one VFX asset in the game matches the crests it
# stands next to. A single sprite, not a particle system: cheaper on the ~60
# draw-call budget and reads chunkier, which is the art direction ADR-0003 asks
# for.
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "rig", "burst.png")
SIZE = 512

# Same outline-weight convention as tools/crests.py: a fraction of the canvas,
# not a guessed pixel value, so it scales with SIZE.
OUTLINE_FRACTION = 25 / 840
OUTLINE = round(SIZE * OUTLINE_FRACTION)

# Hot white-yellow core reads as "impact flash" against the amber crests and the
# desaturated packs; distinct from FILL in tools/crests.py on purpose so the
# burst never gets mistaken for a crest.
FILL = (255, 226, 86, 255)

POINTS = 10
OUTER_R = SIZE * 0.46
INNER_R = SIZE * 0.19


def _style(silhouette):
	alpha = silhouette.split()[3]
	interior = alpha.filter(ImageFilter.MinFilter(OUTLINE * 2 + 1))
	out = Image.new("RGBA", silhouette.size, (0, 0, 0, 0))
	out.paste(Image.new("RGBA", silhouette.size, (0, 0, 0, 255)), (0, 0), alpha)
	out.paste(Image.new("RGBA", silhouette.size, FILL), (0, 0), interior)
	return out


def burst(S=SIZE):
	im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	cx = cy = S / 2.0
	pts = []
	for i in range(POINTS * 2):
		angle = math.pi * i / POINTS - math.pi / 2.0
		r = OUTER_R if i % 2 == 0 else INNER_R
		pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
	d.polygon(pts, fill=(0, 0, 0, 255))
	return _style(im)


if __name__ == "__main__":
	img = burst()
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	img.save(OUT)
	print("wrote %s %s" % (OUT, img.size))

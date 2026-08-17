#!/usr/bin/env python3
# Turns one generated sheet image (several items side by side on white, per
# tools/art/GENERATION.md) into individual rig parts plus a JSON anchor
# sidecar, per ADR-0009: keying, cutting and anchoring are scripted, not
# done by hand in an editor.
#
# Usage:
#   python3 tools/split_rig_sheet.py SHEET.jpg --kind helmet --names cone,horse --out-dir assets/rig
#   python3 tools/split_rig_sheet.py SHEET.jpg --kind weapon --names sword,lance --out-dir assets/rig
#   python3 tools/split_rig_sheet.py SHEET.jpg --kind face --names smooth,bearded --out-dir assets/rig
#
# kind=helmet / kind=face: items land on one shared canvas so the anchor is
# the same pixel for every item (helmets top-aligned on a crown anchor,
# faces bottom-aligned on a neck anchor). kind=weapon: canvases stay trimmed
# to content (a lance and a hammer differ threefold in span) and only the
# grip anchor is shared, expressed per-canvas.
import argparse
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

# Must match EYE_XS / EYE_Y / EYE_R in gen_rig_placeholders.py so a face
# canvas and an expression overlay agree on where the eyes are.
FACE_EYE_XS = (0.32, 0.68)
FACE_EYE_Y = 0.42
FACE_MOUTH_Y = 0.62


def key_background(im, tol=40, erode_px=2):
	rgb = np.asarray(im.convert("RGB"), dtype=np.int16)
	near_white = (np.abs(rgb - 255).max(axis=2) <= tol)
	labeled, _ = ndimage.label(near_white, structure=np.ones((3, 3)))
	border_labels = set(labeled[0, :]) | set(labeled[-1, :]) | set(labeled[:, 0]) | set(labeled[:, -1])
	border_labels.discard(0)
	bg = np.isin(labeled, list(border_labels))
	fg = ~bg
	if erode_px > 0:
		fg = ndimage.binary_erosion(fg, structure=np.ones((3, 3)), iterations=erode_px)
	alpha = (fg * 255).astype(np.uint8)
	out = np.dstack([np.asarray(im.convert("RGB"), dtype=np.uint8), alpha])
	return Image.fromarray(out, mode="RGBA")


def find_items(rgba, min_area=200):
	alpha = np.asarray(rgba)[:, :, 3] > 0
	labeled, n = ndimage.label(alpha, structure=np.ones((3, 3)))
	items = []
	for i, sl in enumerate(ndimage.find_objects(labeled), start=1):
		if sl is None:
			continue
		ys, xs = sl
		area = (labeled[sl] == i).sum()
		if area < min_area:
			continue
		bbox = (xs.start, ys.start, xs.stop, ys.stop)
		items.append(bbox)
	items.sort(key=lambda b: (b[0] + b[2]) / 2.0)
	return items


def trim(rgba, bbox):
	return rgba.crop(bbox)


def process_weapon(rgba, items, names, out_dir):
	if len(items) != len(names):
		raise SystemExit(f"found {len(items)} items, expected {len(names)} names {names}")
	sidecar = {"kind": "weapon", "items": {}}
	for name, bbox in zip(names, items):
		part = trim(rgba, bbox)
		w, h = part.size
		fname = f"weapon_{name}.png"
		part.save(os.path.join(out_dir, fname))
		grip = (w / 2.0, h - 1.0)
		sidecar["items"][name] = {
			"file": fname,
			"size": [w, h],
			"grip_anchor_px": [grip[0], grip[1]],
			"grip_anchor_frac": [0.5, 1.0],
		}
	return sidecar


def process_aligned(rgba, items, names, out_dir, kind, align, margin=24):
	if len(items) != len(names):
		raise SystemExit(f"found {len(items)} items, expected {len(names)} names {names}")
	crops = [trim(rgba, b) for b in items]
	cw = max(c.width for c in crops) + 2 * margin
	ch = max(c.height for c in crops) + 2 * margin
	anchor_x = cw / 2.0
	anchor_y = margin if align == "top" else ch - margin
	sidecar = {
		"kind": kind,
		"canvas": [cw, ch],
		("crown_anchor_px" if kind == "helmet" else "neck_anchor_px"): [anchor_x, anchor_y],
		"items": {},
	}
	if kind == "face":
		sidecar["eye_mouth_grid"] = {
			"eye_xs_frac": list(FACE_EYE_XS),
			"eye_y_frac": FACE_EYE_Y,
			"mouth_y_frac": FACE_MOUTH_Y,
		}
	for name, crop in zip(names, crops):
		canvas = Image.new("RGBA", (int(cw), int(ch)), (0, 0, 0, 0))
		x0 = int((cw - crop.width) / 2.0)
		y0 = int(margin) if align == "top" else int(ch - margin - crop.height)
		canvas.paste(crop, (x0, y0), crop)
		fname = f"{kind}_{name}.png"
		canvas.save(os.path.join(out_dir, fname))
		sidecar["items"][name] = {"file": fname, "bbox_in_canvas": [x0, y0, x0 + crop.width, y0 + crop.height]}
	return sidecar


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("sheet")
	ap.add_argument("--kind", required=True, choices=["helmet", "weapon", "face"])
	ap.add_argument("--names", required=True, help="comma-separated, left to right on the sheet")
	ap.add_argument("--out-dir", default=os.path.join(os.path.dirname(__file__), "..", "assets", "rig"))
	ap.add_argument("--tolerance", type=int, default=40)
	ap.add_argument("--erode", type=int, default=2)
	ap.add_argument("--min-area", type=int, default=200)
	args = ap.parse_args()

	os.makedirs(args.out_dir, exist_ok=True)
	names = args.names.split(",")

	im = Image.open(args.sheet)
	rgba = key_background(im, tol=args.tolerance, erode_px=args.erode)
	items = find_items(rgba, min_area=args.min_area)
	print(f"found {len(items)} item(s): {items}")

	if args.kind == "weapon":
		sidecar = process_weapon(rgba, items, names, args.out_dir)
	else:
		align = "top" if args.kind == "helmet" else "bottom"
		sidecar = process_aligned(rgba, items, names, args.out_dir, args.kind, align)

	sidecar["source"] = os.path.relpath(args.sheet)
	sidecar_path = os.path.join(args.out_dir, f"{args.kind}s.json")
	with open(sidecar_path, "w") as f:
		json.dump(sidecar, f, indent=2)
	print(f"wrote {sidecar_path}")


if __name__ == "__main__":
	main()

#!/usr/bin/env python3
"""Compare the Godot rig against the Craftpix pack's own rendered PNG sequences.

The pack ships every animation pre-rendered at 900x900. Those frames are the only
independent ground truth for the port: if the Godot scene reproduces them, the
pivots, the y-flip and the bone composition order are all right, and if it does
not, one of those three is wrong.

    tools/verify_rig.py ~/Downloads/craftpix-net-469596-...-valkyrie-....zip
    tools/verify_rig.py ~/Downloads/craftpix-net-140672-...-skeleton-warrior-....zip

The pack's `PNG Sequences/` are ~18 MB per character and are never imported into
the repo; this extracts them to a temp directory and deletes them afterwards.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_craftpix import ANIMATIONS, ROOT, node_name, open_pack, raster_for, scene_path, slug

GODOT = os.environ.get("GODOT", "godot")


def masks(path):
	from PIL import Image
	import numpy as np

	with Image.open(path) as im:
		return np.asarray(im.convert("RGBA").split()[3]) > 127


def bbox(mask):
	import numpy as np

	ys, xs = np.where(mask)
	if len(xs) == 0:
		return (0, 0, 0, 0)
	return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)


def render_frames(out_dir, scene):
	cmd = [GODOT, "--rendering-driver", "opengl3", "--resolution", "200x200",
	       "--script", "tests/render_rig_frames.gd", "--", out_dir, scene]
	proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
	if proc.returncode != 0:
		sys.stdout.write(proc.stdout + proc.stderr)
		raise SystemExit("godot render failed")
	xforms = []
	for line in proc.stdout.splitlines():
		if line.startswith("PAWNCH_XFORM"):
			xforms.append(line.split()[1:])
		elif line.startswith("PAWNCH_"):
			print(line)
	with open(os.path.join(out_dir, "xforms.txt"), "w") as f:
		f.write("\n".join(" ".join(x) for x in xforms))


def check_transforms(scml_path, frames, raster, frame_ms=33.0):
	"""Every sprite's global transform against the .scml forward kinematics.

	The IoU above is a whole-image score, so a semi-transparent effect can move
	it without the rig being wrong. This one is per part: it is what actually
	fails if a pivot, the y-flip or the bone composition order is off.
	"""
	import math

	import rig as spriter

	path = os.path.join(frames, "xforms.txt")
	if not os.path.exists(path):
		return
	rig = spriter.Rig(scml_path)
	worst_pos = worst_rot = worst_scale = 0.0
	rows = 0
	for line in open(path):
		anim, index, name, x, y, rot, sx = line.split()
		anim_obj = rig.animations[anim]
		t = float(index) * frame_ms
		world = anim_obj.bone_world(t)
		expect = None
		for _oid, parent, tl, _z in anim_obj.objects:
			if node_name(anim_obj.timelines[tl].name) != name:
				continue
			local, _a, _f, _k = anim_obj.timelines[tl].sample(t, anim_obj.length)
			parent_t = world[parent] if parent is not None else spriter.Transform()
			expect = parent_t.compose(local)
			break
		if expect is None:
			raise SystemExit("no scml object matches sprite %s" % name)
		d_rot = (-math.radians(expect.angle) - float(rot) + math.pi) % (2 * math.pi) - math.pi
		worst_pos = max(worst_pos, math.hypot(float(x) - expect.x, float(y) + expect.y))
		worst_rot = max(worst_rot, abs(math.degrees(d_rot)))
		worst_scale = max(worst_scale, abs(float(sx) - expect.sx / raster))
		rows += 1
	print("transforms  %d sprite samples: max %.4f px, %.4f deg, %.5f scale"
	      % (rows, worst_pos, worst_rot, worst_scale))


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("source", help="pack .zip or an already-extracted pack directory")
	ap.add_argument("--frames", help="skip the Godot run and use frames already rendered here")
	args = ap.parse_args()

	import numpy as np
	import rig as spriter

	workdir = tempfile.mkdtemp(prefix="pawnch-verify-")
	try:
		pack_dir = open_pack(args.source, os.path.join(workdir, "pack"))
		seq_root = os.path.join(pack_dir, "PNG", "PNG Sequences")
		scml_path = os.path.join(pack_dir, "PNG", "Vector Parts", "Animations.scml")
		# The pack names the rig it has to be compared against; nothing here is
		# hardcoded to one family.
		family = slug(spriter.Rig(scml_path).entity)
		scene = "res://" + os.path.relpath(scene_path(family), ROOT)
		print("family     %s -> %s" % (family, scene))

		frames = args.frames or os.path.join(workdir, "godot")
		if not args.frames:
			render_frames(frames, scene)

		print("%-10s %6s %8s %8s %14s" % ("animation", "frames", "mean IoU", "min IoU", "max size delta"))
		overall = []
		for anim in ANIMATIONS:
			refs = sorted(os.listdir(os.path.join(seq_root, anim)))
			ious, deltas = [], []
			for i, ref_name in enumerate(refs):
				ref = masks(os.path.join(seq_root, anim, ref_name))
				mine = masks(os.path.join(frames, "%s_%03d.png" % (anim.lower(), i)))
				ious.append((ref & mine).sum() / (ref | mine).sum())
				a, b = bbox(mine), bbox(ref)
				deltas.append(max(abs((a[2] - a[0]) - (b[2] - b[0])),
				                  abs((a[3] - a[1]) - (b[3] - b[1]))))
			overall += ious
			print("%-10s %6d %8.4f %8.4f %11d px" % (anim, len(refs), np.mean(ious), min(ious), max(deltas)))
		print("%-10s %6d %8.4f %8.4f" % ("ALL", len(overall), np.mean(overall), min(overall)))
		check_transforms(scml_path, frames, raster_for(family))
	finally:
		shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
	main()

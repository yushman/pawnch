#!/usr/bin/env python3
"""Spriter `.scml` reader and forward-kinematics sampler.

The Craftpix packs ship their rig as a Spriter project. This module is the single
place that knows Spriter's conventions, so the Godot converter and the verifier
agree by construction:

  * Spriter is y-up, angles in degrees CCW.
  * `pivot_y = 1` is the *top* of the image, so the pivot pixel is
    `(pivot_x * w, (1 - pivot_y) * h)` measured down from the top.
  * `world = parent . local`: a child's offset is scaled by the parent's scale,
    then rotated by the parent's angle, then translated. Angles add, scales
    multiply -- it is a decomposed TRS hierarchy, not a matrix product.
  * `bone_ref` / `object_ref` `parent` attributes reference a bone_ref id.
  * Draw order is `object_ref`'s `z_index`.
  * `spin` on a key picks the rotation direction to the *next* key.

Verified against the packs' own rendered PNG sequences; see tools/verify_rig.py.
"""
import math
import os
import xml.etree.ElementTree as ET


class Transform:
	def __init__(self, x=0.0, y=0.0, angle=0.0, sx=1.0, sy=1.0):
		self.x, self.y, self.angle, self.sx, self.sy = x, y, angle, sx, sy

	def compose(self, local):
		r = math.radians(self.angle)
		c, s = math.cos(r), math.sin(r)
		return Transform(
			self.x + self.sx * local.x * c - self.sy * local.y * s,
			self.y + self.sx * local.x * s + self.sy * local.y * c,
			self.angle + local.angle,
			self.sx * local.sx,
			self.sy * local.sy,
		)


class Key:
	def __init__(self, time, spin, node):
		g = lambda k, d: float(node.get(k, d))
		self.time = time
		self.spin = spin
		self.x, self.y = g("x", 0), g("y", 0)
		self.angle = g("angle", 0)
		self.sx, self.sy = g("scale_x", 1), g("scale_y", 1)
		self.alpha = g("a", 1)
		self.pivot_x, self.pivot_y = g("pivot_x", 0), g("pivot_y", 1)
		self.file = None
		if node.get("folder") is not None:
			self.file = (int(node.get("folder")), int(node.get("file")))


class Timeline:
	def __init__(self, el):
		self.id = int(el.get("id"))
		self.name = el.get("name")
		self.is_bone = el.get("object_type") == "bone"
		self.keys = []
		for k in el.iter("key"):
			node = k.find("bone")
			if node is None:
				node = k.find("object")
			self.keys.append(Key(float(k.get("time", 0)), int(k.get("spin", 1)), node))
		self.keys.sort(key=lambda k: k.time)
		self._angles = _unwrap([k.angle for k in self.keys], [k.spin for k in self.keys])

	def sample(self, t, length):
		"""Local Transform, alpha and file id at time `t` ms."""
		keys, angles = self.keys, self._angles
		if len(keys) == 1:
			k = keys[0]
			return Transform(k.x, k.y, k.angle, k.sx, k.sy), k.alpha, k.file, k

		i = 0
		while i + 1 < len(keys) and keys[i + 1].time <= t:
			i += 1
		a = keys[i]
		if i + 1 < len(keys):
			b, b_angle, span = keys[i + 1], angles[i + 1], keys[i + 1].time - a.time
		else:
			# Spriter wraps the last segment back to the first key over the tail
			# of the animation. Idle's loop depends on this.
			b = keys[0]
			b_angle = angles[i] + _delta(a.spin, a.angle, b.angle)
			span = length - a.time
		u = 0.0 if span <= 0 else min(1.0, max(0.0, (t - a.time) / span))
		lerp = lambda p, q: p + (q - p) * u
		tr = Transform(
			lerp(a.x, b.x), lerp(a.y, b.y),
			lerp(angles[i], b_angle),
			lerp(a.sx, b.sx), lerp(a.sy, b.sy),
		)
		return tr, lerp(a.alpha, b.alpha), a.file, a

	def keyframes(self, length):
		"""[(time_ms, Transform-with-unwrapped-angle, alpha, file)] plus the wrap key.

		This is what the Godot exporter writes: Godot interpolates rotation
		linearly, so the angles must already be unwrapped.
		"""
		out = []
		for k, angle in zip(self.keys, self._angles):
			out.append((k.time, Transform(k.x, k.y, angle, k.sx, k.sy), k.alpha, k.file, k))
		last = self.keys[-1]
		if len(self.keys) > 1 and last.time < length:
			first = self.keys[0]
			angle = self._angles[-1] + _delta(last.spin, last.angle, first.angle)
			out.append((float(length), Transform(first.x, first.y, angle, first.sx, first.sy),
			            first.alpha, first.file, first))
		return out


class Animation:
	def __init__(self, el):
		self.name = el.get("name")
		self.length = float(el.get("length"))
		self.timelines = {}
		for tl in el.iter("timeline"):
			t = Timeline(tl)
			self.timelines[t.id] = t
		mk = list(el.find("mainline").iter("key"))[0]
		self.bones = [(int(b.get("id")),
		               None if b.get("parent") is None else int(b.get("parent")),
		               int(b.get("timeline"))) for b in mk.iter("bone_ref")]
		self.objects = [(int(o.get("id")),
		                 None if o.get("parent") is None else int(o.get("parent")),
		                 int(o.get("timeline")),
		                 int(o.get("z_index"))) for o in mk.iter("object_ref")]

	def bone_world(self, t):
		world = {}
		for bid, parent, tl in self.bones:
			local, _, _, _ = self.timelines[tl].sample(t, self.length)
			world[bid] = (world[parent] if parent is not None else Transform()).compose(local)
		return world

	def pose(self, t):
		"""[(file_id, world Transform, pivot_x, pivot_y, z_index, alpha)] at time `t`."""
		world = self.bone_world(t)
		out = []
		for _oid, parent, tl, z in self.objects:
			local, alpha, file_id, key = self.timelines[tl].sample(t, self.length)
			w = (world[parent] if parent is not None else Transform()).compose(local)
			out.append((file_id, w, key.pivot_x, key.pivot_y, z, alpha))
		return sorted(out, key=lambda p: p[4])


class Rig:
	"""One family's `Animations.scml`. Byte-identical across pack variants 1/2/3."""

	def __init__(self, scml_path):
		root = ET.parse(scml_path).getroot()
		self.dir = os.path.dirname(scml_path)
		self.files = {}
		for folder in root.iter("folder"):
			for f in folder.iter("file"):
				self.files[(int(folder.get("id")), int(f.get("id")))] = {
					"name": f.get("name"),
					"width": int(f.get("width")),
					"height": int(f.get("height")),
				}
		entity = root.find("entity")
		self.entity = entity.get("name")
		self.animations = {}
		for a in entity.iter("animation"):
			anim = Animation(a)
			self.animations[anim.name] = anim


def _delta(spin, a, b):
	d = b - a
	if spin > 0:
		while d < 0:
			d += 360.0
	elif spin < 0:
		while d > 0:
			d -= 360.0
	return d


def _unwrap(angles, spins):
	out = [angles[0]]
	for i in range(1, len(angles)):
		out.append(out[-1] + _delta(spins[i - 1], angles[i - 1], angles[i]))
	return out


def render(rig, anim_name, t, images, canvas=900, origin=None, hide=()):
	"""Composite one frame with PIL. `images` maps file id -> PIL image.

	Used only by the verifier -- the game renders this rig in Godot.
	"""
	from PIL import Image

	anim = rig.animations[anim_name]
	ox, oy = origin if origin else (canvas / 2, canvas / 2)
	out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
	for file_id, w, pvx, pvy, _z, alpha in anim.pose(t):
		if alpha < 0.004 or rig.files[file_id]["name"] in hide:
			continue
		im = images[file_id]
		iw, ih = im.size
		px, py = pvx * iw, (1.0 - pvy) * ih
		r = math.radians(w.angle)
		c, s = math.cos(r), math.sin(r)
		a11, a12 = w.sx * c, w.sy * s
		a21, a22 = -w.sx * s, w.sy * c
		a13 = ox + w.x - (a11 * px + a12 * py)
		a23 = oy - w.y - (a21 * px + a22 * py)
		det = a11 * a22 - a12 * a21
		if abs(det) < 1e-9:
			continue
		i11, i12 = a22 / det, -a12 / det
		i21, i22 = -a21 / det, a11 / det
		layer = im.transform(
			(canvas, canvas), Image.AFFINE,
			(i11, i12, -(i11 * a13 + i12 * a23), i21, i22, -(i21 * a13 + i22 * a23)),
			resample=Image.BICUBIC)
		if alpha < 0.996:
			layer.putalpha(layer.split()[3].point(lambda v: int(v * alpha)))
		out = Image.alpha_composite(out, layer)
	return out

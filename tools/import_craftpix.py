#!/usr/bin/env python3
"""Import a Craftpix chibi pack and emit the Godot character rig.

ADR-0009: the art pipeline is code. Running this command reproduces
`assets/rig/<family>/` and `scenes/character_rig_<family>.tscn` from the pack;
nothing is hand-assembled in the editor. One command per pack -- the two families
are two rigs (8 bones against 9, and the skeleton has no shield), so they get one
scene each rather than sharing one.

    tools/import_craftpix.py ~/Downloads/craftpix-net-469596-free-chibi-valkyrie-character-sprites.zip
    tools/import_craftpix.py ~/Downloads/craftpix-net-140672-free-chibi-skeleton-warrior-character-sprites.zip

Parts are rasterised from the pack's vector `EPS/`, not from its pre-rendered
PNGs: the PNGs render a ~565 px character, so reaching ADR-0003's ~1000 px author
height from them would mean a soft 1.8x upscale. Ghostscript rasterises the EPS
at any size instead. The rig keeps the `.scml` coordinate space -- native Spriter
units -- so every sprite carries a 1/RASTER scale and the rig root carries
RASTER. Mixing the two spaces is what makes a rig that looks right in one
animation and drifts in another.

Craftpix licence: pack art may be shipped and modified but never fed to an
AI/ML system. This script only rasterises and transcribes it.
"""
import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig as spriter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Every pack canvas is a multiple of 16, so a raster factor only keeps every part
# size integral in steps of 1/16. The valkyrie's 584 native units at 7/4 land at
# 1022 px -- ADR-0003's ~1000 px author height without an upscale -- and that is
# the height the other side has to match, because the two must read as the same
# size when they fight. The skeleton is 504 native units: 2 is the 1/16 step that
# gets closest, 1008 px, 14 px (1.4%) short of the valkyrie.
RASTER = {"valkyrie": 1.75, "skeleton_warrior": 2.0}

ANIMATIONS = ["Idle", "Idle Blinking", "Slashing", "Hurt", "Dying"]
# "Idle Blinking" is the same 600 ms cyclic breathing pose as "Idle", just with
# Face 02 keyed in partway through, so it loops the same way once anything plays
# it -- nothing does yet (scripts/character_rig.gd only ever calls play_state
# with "Idle"), so this has no observable effect today.
LOOPING = {"Idle", "Idle Blinking"}

CREST_HEIGHT_FRACTION = 0.18  # ADR-0007 decision 8; 0.12 is the hard floor.
NODE_NAME_OVERRIDES = {"Face 01": "Face"}
# The pack keys the Sword's alpha to 0 for Idle (weapon hidden). Skipping that one
# track leaves the sprite's own `modulate` (the pack's a=0 default) in charge during
# Idle, and CharacterRig.show_idle_weapon (scripts/character_rig.gd) overrides it --
# same mechanism as show_crest, and why the shipped rig can hold the sword while
# tools/verify_rig.py still compares against the pack's own hidden-sword frames.
IDLE_WEAPON_ALPHA_SKIP = {("Idle", "Sword", "modulate:a")}


# ---------------------------------------------------------------- pack sources

def open_pack(source, workdir):
	"""Return the directory holding `PNG/Vector Parts` and `EPS` for variant 1."""
	if os.path.isfile(source) and source.endswith(".zip"):
		with zipfile.ZipFile(source) as z:
			z.extractall(workdir)
		source = workdir
	# Lowest-numbered variant, not whichever os.walk reached first: the three
	# variants have different heads and therefore different character heights, and
	# tools/verify_rig.py compares the rig against *this* variant's rendered frames.
	found = []
	for dirpath, dirnames, _ in os.walk(source):
		if "__MACOSX" in dirpath:
			continue
		if "EPS" in dirnames and "PNG" in dirnames:
			found.append(dirpath)
	if not found:
		raise SystemExit("no pack variant with EPS/ and PNG/ found under %s" % source)
	return min(found)


def slug(name):
	return re.sub(r"[^a-z0-9]+", "_", os.path.splitext(name)[0].lower()).strip("_")


def node_name(name):
	return re.sub(r"[^A-Za-z0-9]", "", NODE_NAME_OVERRIDES.get(name, name))


def raster_for(family):
	if family not in RASTER:
		raise SystemExit("no raster factor for family %r; add one to RASTER" % family)
	return RASTER[family]


def scene_path(family):
	return os.path.join(ROOT, "scenes", "character_rig_%s.tscn" % family)


# ---------------------------------------------------------------- rasterising

def rasterise(pack_dir, family, raster, file_names):
	"""EPS -> PNG at `raster` x. Returns {scml file name: (rel_path, w, h)}."""
	if not shutil.which("gs"):
		raise SystemExit("ghostscript ('gs') not found; brew install ghostscript")
	out_dir = os.path.join(ROOT, "assets", "rig", family)
	if os.path.isdir(out_dir):
		shutil.rmtree(out_dir)
	os.makedirs(out_dir)
	eps_dir = os.path.join(pack_dir, "EPS")
	prefix = os.path.basename(pack_dir).rsplit("_", 1)[0]
	from PIL import Image

	result = {}
	for name in sorted(file_names):
		stem = os.path.splitext(name)[0]
		eps = os.path.join(eps_dir, "%s_%s.eps" % (prefix, stem))
		if not os.path.exists(eps):
			raise SystemExit("missing vector source %s" % eps)
		png = os.path.join(out_dir, slug(name) + ".png")
		subprocess.run([
			"gs", "-q", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-dEPSCrop",
			"-sDEVICE=pngalpha", "-r%g" % (72 * raster),
			"-dTextAlphaBits=4", "-dGraphicsAlphaBits=4",
			"-sOutputFile=" + png, eps,
		], check=True)
		with Image.open(png) as im:
			result[name] = ("res://assets/rig/%s/%s" % (family, os.path.basename(png)), *im.size)
	return result


# ---------------------------------------------------------------- scene layout

class Part:
	"""One node in the emitted scene: a bone Node2D or an object Sprite2D."""

	def __init__(self, timeline_id, name, path, is_bone, z=0):
		self.timeline_id = timeline_id
		self.name = name
		self.path = path          # NodePath from the scene root
		self.is_bone = is_bone
		self.z = z


def build_tree(rig):
	"""Bones and objects for the four animations, whose hierarchy is identical."""
	base = rig.animations[ANIMATIONS[0]]
	for other in ANIMATIONS[1:]:
		a = rig.animations[other]
		if a.bones != base.bones or a.objects != base.objects:
			raise SystemExit("hierarchy differs between Idle and %s" % other)

	parts = {}
	children = {}   # parent path -> [Part], in emission order
	bone_path = {}

	for bid, parent, tl in base.bones:
		tl_name = base.timelines[tl].name
		parent_path = bone_path[parent] if parent is not None else "Rig"
		path = "%s/%s" % (parent_path, tl_name)
		bone_path[bid] = path
		p = Part(tl, tl_name, path, True)
		parts[tl] = p
		children.setdefault(parent_path, []).append(p)

	for _oid, parent, tl, z in base.objects:
		name = node_name(base.timelines[tl].name)
		parent_path = bone_path[parent] if parent is not None else "Rig"
		p = Part(tl, name, "%s/%s" % (parent_path, name), False, z)
		parts[tl] = p
		children.setdefault(parent_path, []).append(p)

	return parts, children


def local_of(rig, anim_name, timeline_id, t=0.0):
	anim = rig.animations[anim_name]
	return anim.timelines[timeline_id].sample(t, anim.length)


def godot_bone(tr):
	return (tr.x, -tr.y), -math.radians(tr.angle), (tr.sx, tr.sy)


def godot_sprite(tr, tex_w, tex_h, pivot_x, pivot_y, raster):
	pos, rot, _ = godot_bone(tr)
	offset = (-pivot_x * tex_w, -(1.0 - pivot_y) * tex_h)
	return pos, rot, (tr.sx / raster, tr.sy / raster), offset


# ---------------------------------------------------------------- measurements

def measure(rig, pack_dir, parts):
	"""Character height and the crest anchor, both in native scml units."""
	from PIL import Image

	vector_dir = os.path.join(pack_dir, "PNG", "Vector Parts")
	images = {k: Image.open(os.path.join(vector_dir, v["name"])).convert("RGBA")
	          for k, v in rig.files.items()}
	frame = spriter.render(rig, "Idle", 0.0, images, canvas=1200, origin=(600, 1000))
	box = frame.split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
	height = box[3] - box[1]

	head_tl = next(p.timeline_id for p in parts.values()
	               if not p.is_bone and p.name == "Head")
	tr, _, file_id, key = local_of(rig, "Idle", head_tl)
	head = images[file_id]
	hb = head.split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
	# Crown of the head in head-image pixels, y measured down from the top.
	u = (hb[0] + hb[2]) * 0.5 - key.pivot_x * head.width
	v = hb[1] - (1.0 - key.pivot_y) * head.height
	r = -math.radians(tr.angle)
	c, s = math.cos(r), math.sin(r)
	u, v = u * tr.sx, v * tr.sy
	crown = (tr.x + u * c - v * s, -tr.y + u * s + v * c)
	return height, crown


# ---------------------------------------------------------------- tscn writing

def fmt(v):
	"""Always a float literal. `0` would land in a track as an int and `-0` is
	not a number Godot's variant parser is worth trusting with."""
	if isinstance(v, tuple):
		return "Vector2(%s, %s)" % (fmt(v[0]), fmt(v[1]))
	text = "%.6f" % (float(v) + 0.0)
	text = text.rstrip("0")
	return text + "0" if text.endswith(".") else text


class Scene:
	def __init__(self):
		self.ext = []
		self.sub = []

	def ext_resource(self, rid, rtype, path):
		self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
		return 'ExtResource("%s")' % rid

	def sub_resource(self, rid, rtype, body):
		self.sub.append('[sub_resource type="%s" id="%s"]\n%s' % (rtype, rid, body))
		return 'SubResource("%s")' % rid


def value_track(index, path, keys, update=0, interp=1):
	times = ", ".join(fmt(t) for t, _ in keys)
	values = ", ".join(v for _, v in keys)
	return (
		'tracks/%d/type = "value"\n'
		'tracks/%d/path = NodePath("%s")\n'
		'tracks/%d/interp = %d\n'
		'tracks/%d/loop_wrap = true\n'
		'tracks/%d/keys = {\n'
		'"times": PackedFloat32Array(%s),\n'
		'"transitions": PackedFloat32Array(%s),\n'
		'"update": %d,\n'
		'"values": [%s]\n'
		'}\n' % (index, index, path, index, interp, index, index,
		         times, ", ".join("1" for _ in keys), update, values)
	)


def collect_tracks(rig, parts, textures, raster):
	"""Property paths that any of the four animations moves or overrides.

	A property is tracked in *every* animation as soon as one animation touches
	it, otherwise switching from Slashing back to Idle would leave the pose the
	first animation set.
	"""
	defaults = {}
	tracked = set()
	for tl, part in parts.items():
		tr, alpha, file_id, key = local_of(rig, ANIMATIONS[0], tl)
		if part.is_bone:
			pos, rot, scale = godot_bone(tr)
			defaults[tl] = {"position": fmt(pos), "rotation": fmt(rot), "scale": fmt(scale)}
		else:
			_, w, h = textures[rig.files[file_id]["name"]]
			pos, rot, scale, _off = godot_sprite(tr, w, h, key.pivot_x, key.pivot_y, raster)
			defaults[tl] = {
				"position": fmt(pos), "rotation": fmt(rot), "scale": fmt(scale),
				"modulate:a": fmt(alpha), "texture": file_id,
			}

	for anim_name in ANIMATIONS:
		for tl, part in parts.items():
			for prop, values in sampled(rig, anim_name, tl, part, textures, raster).items():
				if len(set(values)) > 1 or values[0] != defaults[tl][prop]:
					tracked.add((tl, prop))
	return defaults, tracked


def sampled(rig, anim_name, tl, part, textures, raster):
	"""{property: [value per keyframe]} for one timeline in one animation."""
	anim = rig.animations[anim_name]
	out = {}
	for _t, tr, alpha, file_id, key in anim.timelines[tl].keyframes(anim.length):
		if part.is_bone:
			pos, rot, scale = godot_bone(tr)
			row = {"position": fmt(pos), "rotation": fmt(rot), "scale": fmt(scale)}
		else:
			_, w, h = textures[rig.files[file_id]["name"]]
			pos, rot, scale, _off = godot_sprite(tr, w, h, key.pivot_x, key.pivot_y, raster)
			row = {"position": fmt(pos), "rotation": fmt(rot), "scale": fmt(scale),
			       "modulate:a": fmt(alpha), "texture": file_id}
		for k, v in row.items():
			out.setdefault(k, []).append(v)
	return out


def write_scene(rig, family, raster, parts, children, textures, height, crown, out_path):
	scene = Scene()
	script = scene.ext_resource("1_script", "Script", "res://scripts/character_rig.gd")
	tex_ref = {}
	for i, (name, (path, _w, _h)) in enumerate(sorted(textures.items())):
		tex_ref[name] = scene.ext_resource("t_%d" % i, "Texture2D", path)
	crest_tex = scene.ext_resource("t_crest", "Texture2D", "res://assets/rig/crest_pawn.png")

	defaults, tracked = collect_tracks(rig, parts, textures, raster)

	lib = {}
	for anim_name in ANIMATIONS:
		anim = rig.animations[anim_name]
		body = ['resource_name = "%s"' % anim_name,
		        "length = %s" % fmt(anim.length / 1000.0)]
		if anim_name in LOOPING:
			body.append("loop_mode = 1")
		index = 0
		for tl in sorted(parts):
			part = parts[tl]
			rows = sampled(rig, anim_name, tl, part, textures, raster)
			times = [t / 1000.0 for t, *_ in anim.timelines[tl].keyframes(anim.length)]
			for prop in ("position", "rotation", "scale", "modulate:a", "texture"):
				if (tl, prop) not in tracked or prop not in rows:
					continue
				if (anim_name, part.name, prop) in IDLE_WEAPON_ALPHA_SKIP:
					continue
				if prop == "texture":
					keys = [(t, tex_ref[rig.files[v]["name"]])
					        for t, v in zip(times, rows[prop])]
					body.append(value_track(index, "%s:%s" % (part.path, prop), keys, update=1))
				else:
					keys = list(zip(times, rows[prop]))
					body.append(value_track(index, "%s:%s" % (part.path, prop), keys))
				index += 1
		lib[anim_name] = scene.sub_resource("Animation_%s" % anim_name.replace(" ", "_"),
		                                    "Animation", "\n".join(body))

	library = scene.sub_resource(
		"AnimationLibrary_main", "AnimationLibrary",
		"_data = {\n%s\n}" % ",\n".join('"%s": %s' % (k, v) for k, v in sorted(lib.items())))

	nodes = [
		'[node name="CharacterRig" type="Node2D"]',
		"script = %s" % script,
		# Root sits at the character's feet (native pack origin), so running this
		# scene on its own puts the character above the viewport. This offset is
		# only a preview -- scenes/duel_panel.tscn sets position on both rig
		# instances explicitly and overrides it.
		"position = Vector2(413, 1804)",
		"",
		'[node name="Rig" type="Node2D" parent="."]',
		# tests/render_rig_frames.gd reads the raster factor back off this node, so
		# the verifier never has to be told which family it is looking at.
		"scale = %s" % fmt((raster, raster)),
		"",
	]

	def emit(parent_path):
		for part in children.get(parent_path, []):
			d = defaults[part.timeline_id]
			if part.is_bone:
				nodes.append('[node name="%s" type="Node2D" parent="%s"]' % (part.name, parent_path))
				nodes.extend(["position = %s" % d["position"], "rotation = %s" % d["rotation"],
				              "scale = %s" % d["scale"], ""])
			else:
				tr, _alpha, file_id, key = local_of(rig, ANIMATIONS[0], part.timeline_id)
				name = rig.files[file_id]["name"]
				_, w, h = textures[name]
				_pos, _rot, _scale, offset = godot_sprite(tr, w, h, key.pivot_x, key.pivot_y, raster)
				nodes.append('[node name="%s" type="Sprite2D" parent="%s"]' % (part.name, parent_path))
				if part.name in ("Sword", "Head", "Face"):
					# %Sword for show_idle_weapon; %Head/%Face for the knockout detach (Day 3).
					nodes.append("unique_name_in_owner = true")
				nodes.extend([
					"position = %s" % d["position"], "rotation = %s" % d["rotation"],
					"scale = %s" % d["scale"], "z_index = %d" % part.z,
					"texture = %s" % tex_ref[name], "centered = false",
					"offset = %s" % fmt(offset),
				])
				if d["modulate:a"] != "1":
					nodes.append("modulate = Color(1, 1, 1, %s)" % d["modulate:a"])
				nodes.append("")
			emit(part.path)

	emit("Rig")

	# Crest: rigid on the crown of the head bone, so it follows the head through
	# every animation without a track of its own (ADR-0007 decision 8). It needs
	# the same local rotation the Head sprite carries -- that's what cancels the
	# bone chain's accumulated rotation and makes the artwork stand upright -- or
	# it inherits the raw chain angle and renders on its side.
	from PIL import Image

	head_bone = next(p for p in parts.values() if not p.is_bone and p.name == "Head")
	crest_parent = head_bone.path.rsplit("/", 1)[0]
	head_tr, _alpha, _file_id, _key = local_of(rig, ANIMATIONS[0], head_bone.timeline_id)
	crest_rotation = godot_bone(head_tr)[1]
	with Image.open(os.path.join(ROOT, "assets", "rig", "crest_pawn.png")) as im:
		cb = im.split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
	crest_scale = height * CREST_HEIGHT_FRACTION / (cb[3] - cb[1])
	nodes += [
		'[node name="Crest" type="Sprite2D" parent="%s"]' % crest_parent,
		"unique_name_in_owner = true",
		"position = %s" % fmt(crown),
		"rotation = %s" % fmt(crest_rotation),
		"scale = %s" % fmt((crest_scale, crest_scale)),
		"z_index = %d" % (max(p.z for p in parts.values() if not p.is_bone) + 1),
		"texture = %s" % crest_tex,
		"centered = false",
		"offset = %s" % fmt((-(cb[0] + cb[2]) * 0.5, -float(cb[3]))),
		"",
		'[node name="AnimationPlayer" type="AnimationPlayer" parent="."]',
		"callback_mode_method = 1",
		'libraries = {\n"": %s\n}' % library,
		"",
	]

	header = "[gd_scene load_steps=%d format=3]" % (len(scene.ext) + len(scene.sub) + 1)
	text = "\n".join([header, ""] + scene.ext + [""] + scene.sub + [""] + nodes)
	with open(out_path, "w") as f:
		f.write(text)
	return height, crest_scale


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("source", help="pack .zip or an already-extracted pack directory")
	ap.add_argument("--family", default=None, help="asset subdirectory name (default: entity name)")
	args = ap.parse_args()

	workdir = tempfile.mkdtemp(prefix="craftpix-")
	try:
		pack_dir = open_pack(args.source, workdir)
		rig = spriter.Rig(os.path.join(pack_dir, "PNG", "Vector Parts", "Animations.scml"))
		family = args.family or slug(rig.entity)
		raster = raster_for(family)
		parts, children = build_tree(rig)

		used = set()
		for anim_name in ANIMATIONS:
			anim = rig.animations[anim_name]
			for tl in anim.timelines.values():
				for k in tl.keys:
					if k.file:
						used.add(rig.files[k.file]["name"])
		textures = rasterise(pack_dir, family, raster, used)

		height, crown = measure(rig, pack_dir, parts)
		out = scene_path(family)
		height, crest_scale = write_scene(rig, family, raster, parts, children, textures,
		                                  height, crown, out)
		bones = sum(1 for p in parts.values() if p.is_bone)
		print("family        %s (%d bones, %d objects)" % (family, bones, len(parts) - bones))
		print("parts         %d rasterised at %gx -> assets/rig/%s/" % (len(textures), raster, family))
		print("character     %.0f native units, %.0f px at %gx" % (height, height * raster, raster))
		print("crest         %.0f%% of height, crown at (%.1f, %.1f), scale %.4f"
		      % (CREST_HEIGHT_FRACTION * 100, crown[0], crown[1], crest_scale))
		print("scene         %s" % out)
		# Rasterising wipes assets/rig/<family>/, and with it Godot's .import
		# files; without this the scene cannot resolve its textures.
		godot = os.environ.get("GODOT", "godot")
		if shutil.which(godot):
			subprocess.run([godot, "--headless", "--import"], cwd=ROOT,
			               check=True, capture_output=True)
			print("imported      %s --headless --import" % godot)
		else:
			print("imported      SKIPPED -- run `godot --headless --import` before opening the scene")
	finally:
		shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
	main()

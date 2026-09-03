extends Node2D
class_name CharacterRig

# Craftpix cutout rig ported from a pack's Animations.scml (ADR-0003, ADR-0007):
# nested Node2D bones, one Sprite2D per part, seven body parts plus head, face and
# weapon -- plus a shield on the valkyrie, which the skeleton does not have. The
# scenes are generated, one per pack -- edit tools/import_craftpix.py and re-run it,
# never the .tscn by hand (ADR-0009). This script drives both, so it may only touch
# what both rigs have: %Crest, %Sword and the AnimationPlayer.
#
# Identity lives in the crest and the weapon. There is no side recolour: white is
# the valkyrie pack and black is the skeleton pack, two different characters.

const CRESTS := {
	"pawn": preload("res://assets/rig/crest_pawn.png"),
	"knight": preload("res://assets/rig/crest_knight.png"),
	"bishop": preload("res://assets/rig/crest_bishop.png"),
	"rook": preload("res://assets/rig/crest_rook.png"),
	"queen": preload("res://assets/rig/crest_queen.png"),
	"king": preload("res://assets/rig/crest_king.png"),
}

## The per-type weapon, ADR-0007 decision 5: six donor shapes, one per piece type,
## the same shape on both sides. Unlike the crest -- one procedural file shared by
## both families -- each family carries its own rasterisation of those six at its
## own raster factor, so this is a file name resolved against the directory the
## generated scene's own sword came from, not a preload table like CRESTS: one
## script drives two families and cannot preload both. tools/import_craftpix.py
## writes the twelve files and is the only place a donor pack is named.
const WEAPON_FILE := "weapon_%s.png"

@export var piece_type := "pawn"
## Off for the IoU check against the pack's own rendered frames, which have no crest.
@export var show_crest := true
## The pack's Idle keys the sword's alpha to 0 (weapon hidden); ADR-0007 puts identity
## in crest and weapon both, so the shipped idle draws it. Idle carries no alpha track
## of its own for the sword -- this is what sets it -- so off reproduces the pack's own
## hidden-sword idle for tools/verify_rig.py's frame comparison.
@export var show_idle_weapon := true
## Off for tools/verify_rig.py, which compares against the pack's own rendered
## frames and those hold the pack's own sword. Same precedent as show_crest:
## the shipped rig swaps the weapon per piece type, the verifier must not.
@export var show_type_weapon := true

@onready var _crest: Sprite2D = %Crest
@onready var _sword: Sprite2D = %Sword
@onready var _head: Sprite2D = %Head
@onready var _face: Sprite2D = %Face
@onready var _anim: AnimationPlayer = $AnimationPlayer

# Knockout (ADR-0007 decision 4, black side only): the head comes off and flies
# out of frame carrying its crest. `Dying` keys the head *bone* (bone_007), which
# Head, Face and Crest are all children of, by NodePath -- reparenting any of them
# at runtime to animate a flight path would desync those tracks. Instead a
# duplicate of each is spawned in place, the originals are hidden, and the
# duplicates fly while Dying keeps driving the (now invisible) originals
# underneath. bone_007 carries all three sprites; leaving any one of them
# un-duplicated leaves it floating in place, still visible, once the other two
# fly off.
#
# The three duplicates hang under **one container**, and the flight is tweened on
# the container alone. That is the fix for the Day-5 defect: they used to be
# three siblings under this node with `rotation` tweened on each, and Head, Face
# and Crest each have their own origin -- none of them the skull's centre, all of
# them a texture corner -- so each spun about a different point and they fanned
# apart. 670 px of drift by the end of the flight, which is the crest coming off
# the skull and hanging beside the valkyrie for the rest of the duel.
var _detached: Node2D
var _detach_tween: Tween
## The weapon the generated scene mounts, captured before the first per-type swap
## overwrites it. Its path is also what names this rig's own family directory.
var _pack_weapon: Texture2D


func _ready() -> void:
	_pack_weapon = _sword.texture
	set_piece_type(piece_type)
	_crest.visible = show_crest
	play_state("Idle Blinking")
	print("PAWNCH_RIG %s crest=%s weapon=%s" % [
		name, _crest.texture.resource_path.get_file(),
		_sword.texture.resource_path.get_file()])


func set_piece_type(type: String) -> void:
	piece_type = type
	if not is_node_ready():
		return
	_crest.texture = CRESTS[type]
	# A texture assignment and nothing else: every donor pack puts its weapon on
	# the same 400x128 canvas at pivot (0, 1) as the Sword being replaced, so the
	# rasterisation comes out exactly the size this family's own sword.png is and
	# hangs in the hand at the same grip point. If this ever needs an offset or a
	# scale, the fault is upstream in tools/import_craftpix.py, not here.
	if show_type_weapon:
		_sword.texture = load(_pack_weapon.resource_path.get_base_dir() \
			.path_join(WEAPON_FILE % type))


func play_state(state: String) -> void:
	if state == "Idle" or state == "Idle Blinking":
		_sword.modulate.a = 1.0 if show_idle_weapon else 0.0
	_anim.play(state)


## The flight, as fractions of `duration`. START is when the fade begins, SEC is
## how long it takes, and START + SEC is the frame the skull is gone.
##
## The constraint on them is geometric, not aesthetic. The black rig stands at
## x=893 in a 1240-wide panel and the skull's own box already reaches x=1114
## standing still, so there are 126 px of panel to the right of a severed head
## and 370 px above it -- and whatever is left of it when it reaches either edge
## is cut in half by the Mask in front of the player. `distance` and the
## direction below are chosen so the whole flight fits inside those two numbers
## (measured: tools/measure_stage_bounds.gd --detach), and the fade then only has
## to finish before the panel wipes out -- 0.45 + 0.40 of a 0.9 s flight, on top
## of the strike's impact at 0.52 and its 0.11 s hitstop, puts the last lit frame
## of the skull on `exit` at 1.40. The strike is the tightest of the three; the
## pounce and the charge exit later still.
##
## They used to be 0.65 and 0.35 against a 900-unit flight aimed almost straight
## downrange: the skull crossed the right edge 0.14 s after impact and the fade
## had not started, so every capture in the game ended on a skull sliced by an
## invisible line.
const DETACH_FADE_START := 0.45
const DETACH_FADE_SEC := 0.40

# `local_direction` is in this node's own local space, i.e. skeleton-local --
# scenes/duel_panel.tscn mounts the skeleton at scale=(-0.52, 0.52), so a
# negative local x arrives on screen as positive x: away from the valkyrie.
# `distance` is in rig units for the same reason: 620 of them is 620*0.52 = 322
# px of travel on the panel.
#
# Up rather than downrange, which is the direction the room is in. The default
# used to be (-1, -0.35), i.e. almost flat and away from the attacker -- the
# natural read, and the one there is no space for: 126 px of panel that way
# against 370 px straight up.
func detach_head(local_direction := Vector2(-0.18, -1.0), distance := 620.0, duration := 0.9) -> void:
	if _detached:
		return
	# One container, three sprites, one tween on the container. Its origin is the
	# skull's own centre, so the tumble spins about the head instead of about a
	# texture corner.
	#
	# Parented to the **stage**, not to this rig, and that is a fix rather than a
	# tidy-up: a severed head must not be carried by what happens to the body
	# afterwards. STRIKE_KNOCKBACK drives the defender's root 133 px downrange
	# and STRIKE_KNOCK_TILT rolls it 0.22 rad, and a head hanging off that root
	# inherited about 210 px of travel it never should have had -- more than the
	# 126 px of clear panel it has, so on the strike no flight distance and no
	# fade timing could have kept it in frame. Ownership does not move with it:
	# reset_defeat() frees it and debris_count() is how the skip sweep sees it.
	var host := get_parent()
	if host == null:
		host = self
	_detached = Node2D.new()
	_detached.name = "HeadDuplicate"
	_detached.z_index = z_index
	host.add_child(_detached)
	_detached.global_transform = Transform2D(0.0,
		_head.get_global_transform() * _head.get_rect().get_center())
	for source: Sprite2D in [_head, _face, _crest]:
		var dup := source.duplicate() as Sprite2D
		dup.name = source.name + "Duplicate"
		dup.z_index = source.z_index + 50
		_detached.add_child(dup)
		# After the reparent, and from the source rather than from the copy: this
		# is what freezes the three in their impact-frame arrangement while
		# `Dying` carries on collapsing the originals underneath.
		dup.global_transform = source.get_global_transform()
		source.visible = false

	# Rig units into stage px, mirror included: the mount basis is what turns a
	# negative local x into travel away from the valkyrie, and it carries the
	# 0.52 as well, so `distance` stays quoted in the rig's own units.
	var offset := get_transform().basis_xform(local_direction.normalized()) * distance
	_detach_tween = create_tween()
	_detach_tween.set_parallel(true)
	# EASE_OUT, not the EASE_IN this used to need: a fast-start curve was
	# unusable while the skull was flying at an edge two frames away, and it is
	# the right curve now that the flight ends inside the frame -- the head is
	# thrown off the neck by the blow, not launched, so it covers most of its arc
	# early and coasts to a stop while it fades.
	_detach_tween.tween_property(_detached, "position", _detached.position + offset, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The spin decays with the travel rather than running on linearly past it: a
	# head still turning at full rate after it has stopped moving reads as a
	# sprite being animated, not as an object that was hit.
	_detach_tween.tween_property(_detached, "rotation", _detached.rotation + 5.5, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_detach_tween.tween_property(_detached, "modulate:a", 0.0, duration * DETACH_FADE_SEC) \
		.set_delay(duration * DETACH_FADE_START)


## Whether the flying head is still in the scene, for the skip sweep's state
## string. A method rather than a child count on this node, because the container
## lives on the stage: counting this rig's children would report 0 forever and
## the sweep would stop being able to see a head left behind.
func debris_count() -> int:
	return 1 if _detached != null and not _detached.is_queued_for_deletion() else 0


# Idempotent: safe to call whether or not detach_head() ever ran (back-to-back
# clashes, warm-up). Puts the head, the face, the crest and the tween back to
# nothing.
func reset_defeat() -> void:
	if _detach_tween and _detach_tween.is_valid():
		_detach_tween.kill()
	if _detached:
		# Removed before it is freed, not just queued: queue_free() leaves the
		# container in the tree until the end of the frame, and a clash that
		# starts in that same frame -- which is what a skip followed by another
		# capture does -- would draw the previous clash's flying head.
		var host := _detached.get_parent()
		if host:
			host.remove_child(_detached)
		_detached.queue_free()
		_detached = null
	_head.visible = true
	_face.visible = true
	_crest.visible = show_crest


# Failure mode 4: pay the duplicate-sprite construction and first-draw cost at
# boot, not on the player's first clash. The panel is invisible (modulate.a=0)
# whenever this runs.
func warm_detach() -> void:
	detach_head()
	reset_defeat()

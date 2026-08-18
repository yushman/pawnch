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

@export var piece_type := "pawn"
## Off for the IoU check against the pack's own rendered frames, which have no crest.
@export var show_crest := true
## The pack's Idle keys the sword's alpha to 0 (weapon hidden); ADR-0007 puts identity
## in crest and weapon both, so the shipped idle draws it. Idle carries no alpha track
## of its own for the sword -- this is what sets it -- so off reproduces the pack's own
## hidden-sword idle for tools/verify_rig.py's frame comparison.
@export var show_idle_weapon := true

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
# duplicates are tweened independently while Dying keeps driving the (now
# invisible) originals underneath. bone_007 carries all three sprites; leaving
# any one of them un-duplicated leaves it floating in place, still visible,
# once the other two fly off.
var _detached_head: Sprite2D
var _detached_face: Sprite2D
var _detached_crest: Sprite2D
var _detach_tween: Tween


func _ready() -> void:
	set_piece_type(piece_type)
	_crest.visible = show_crest
	play_state("Idle Blinking")


func set_piece_type(type: String) -> void:
	piece_type = type
	if is_node_ready():
		_crest.texture = CRESTS[type]


func play_state(state: String) -> void:
	if state == "Idle" or state == "Idle Blinking":
		_sword.modulate.a = 1.0 if show_idle_weapon else 0.0
	_anim.play(state)


# `local_direction` is in this node's own local space, i.e. skeleton-local --
# scenes/duel_panel.tscn mounts the skeleton at scale=(-0.714, 0.714), so a
# negative local x arrives on screen as positive x: away from the valkyrie.
func detach_head(local_direction := Vector2(-1.0, -0.35), distance := 900.0, duration := 0.9) -> void:
	if _detached_head:
		return
	_detached_head = _spawn_duplicate(_head)
	_detached_face = _spawn_duplicate(_face)
	_detached_crest = _spawn_duplicate(_crest)
	_head.visible = false
	_face.visible = false
	_crest.visible = false

	var offset := local_direction.normalized() * distance
	_detach_tween = create_tween()
	_detach_tween.set_parallel(true)
	for dup in [_detached_head, _detached_face, _detached_crest]:
		# EASE_IN, not EASE_OUT: the defender's head bone sits close to the
		# panel's clipped right edge already (see duel_panel.gd's staging
		# comment), so a fast-start curve crossed that edge, and left the
		# panel's Mask (clip_contents), within a couple of frames -- the head
		# and face never had a visible flight, only the crest (mounted closer
		# to the bone's centre) did. Starting slow keeps the duplicates inside
		# the mask for most of the beat and lets them accelerate away only
		# once they are meant to be leaving frame.
		_detach_tween.tween_property(dup, "position", dup.position + offset, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_detach_tween.tween_property(dup, "rotation", dup.rotation + 5.5, duration)
		_detach_tween.tween_property(dup, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)


func _spawn_duplicate(source: Sprite2D) -> Sprite2D:
	var dup := source.duplicate() as Sprite2D
	dup.name = source.name + "Duplicate"
	dup.z_index = source.z_index + 50
	add_child(dup)
	dup.global_transform = source.global_transform
	return dup


# Idempotent: safe to call whether or not detach_head() ever ran (back-to-back
# clashes, warm-up). Puts the head, the face, the crest and the tween back to
# nothing.
func reset_defeat() -> void:
	if _detach_tween and _detach_tween.is_valid():
		_detach_tween.kill()
	for dup in [_detached_head, _detached_face, _detached_crest]:
		if dup == null:
			continue
		# Removed before it is freed, not just queued: queue_free() leaves the
		# duplicate in the tree until the end of the frame, and a clash that
		# starts in that same frame -- which is what a skip followed by another
		# capture does -- would draw the previous clash's flying head.
		remove_child(dup)
		dup.queue_free()
	_detached_head = null
	_detached_face = null
	_detached_crest = null
	_head.visible = true
	_face.visible = true
	_crest.visible = show_crest


# Failure mode 4: pay the duplicate-sprite construction and first-draw cost at
# boot, not on the player's first clash. The panel is invisible (modulate.a=0)
# whenever this runs.
func warm_detach() -> void:
	detach_head()
	reset_defeat()

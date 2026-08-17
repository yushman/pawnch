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

signal cue_fired(cue_name: String)

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
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	set_piece_type(piece_type)
	_crest.visible = show_crest
	play_state("Idle")


func set_piece_type(type: String) -> void:
	piece_type = type
	if is_node_ready():
		_crest.texture = CRESTS[type]


func play_state(state: String) -> void:
	if state == "Idle":
		_sword.modulate.a = 1.0 if show_idle_weapon else 0.0
	_anim.play(state)


func play_cue_demo() -> void:
	_anim.stop()
	_anim.play("cue_demo")


func _fire_cue(cue_name: String) -> void:
	cue_fired.emit(cue_name)
	print("PAWNCH_CUE %s t=%.3f" % [cue_name, _anim.current_animation_position])

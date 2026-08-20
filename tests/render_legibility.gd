extends SceneTree

# Raw figures for the legibility contact sheet: six piece types per family, in a
# neutral stance, carrying both halves of ADR-0007's identity -- the crest and,
# from Day 7, the type's own weapon. tools/legibility_sheet.py composes them.
#
# ADR-0003's test ("identifiable filled solid black at 110 px tall") was last run
# in ADR-0007 decision 8, when there was one weapon per side and the crest was
# doing all the work. It has never been run against six weapons, and no person
# has ever been shown the crests at all -- which is what block B of
# per-type-weapons-and-generic-strike exists to fix.
#
# Same constraint as tests/render_rig_frames.gd: `--headless` installs the dummy
# rendering server and Viewport.get_texture() returns null under it, so this needs
# a real window on the Compatibility/OpenGL renderer the game ships with.
#
#   godot --rendering-driver opengl3 --script tests/render_legibility.gd -- <out_dir>

# Generous, because the sheet crops to the union of all twelve figures afterwards
# and the only cost of slack is temp-file size. A raised weapon reaches further
# than any pose does.
const CANVAS := Vector2i(2000, 1600)
const ROOT_AT := Vector2(1000, 1420)
const ANIM := "Idle Blinking"

const TYPES := ["pawn", "knight", "bishop", "rook", "queen", "king"]
# Mirrored exactly as the duel panel and the board mount them (ADR-0011
# decision 5), so the sheet shows the figure the player actually sees.
const FAMILIES := {
	"valkyrie": {"scene": "res://scenes/character_rig_valkyrie.tscn", "mirror": false},
	"skeleton_warrior": {"scene": "res://scenes/character_rig_skeleton_warrior.tscn", "mirror": true},
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/pawnch_legibility"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var viewport := SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	for family in FAMILIES:
		var rig: CharacterRig = (load(FAMILIES[family]["scene"]) as PackedScene).instantiate()
		rig.position = ROOT_AT
		var mirror: bool = FAMILIES[family]["mirror"]
		rig.scale = Vector2(-1.0 if mirror else 1.0, 1.0)
		viewport.add_child(rig)
		var player: AnimationPlayer = rig.get_node("AnimationPlayer")
		# Same reason as tests/render_rig_frames.gd: without manual callbacks the
		# mixer advances a frame delta between seek() and the capture -- and here
		# it would also re-apply the alpha track forced open below.
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(ANIM)
		var sword: Sprite2D = rig.get_node("%Sword")
		for type in TYPES:
			rig.set_piece_type(type)
			player.seek(0.0, true, true)
			# The pack keys the sword's alpha to 0 through the whole of Idle
			# Blinking, so a stance frame hides the half of identity this sheet
			# exists to test. Forced open after the seek, which is the same thing
			# ADR-0007 decision 8 did to run its own silhouette test at all.
			sword.modulate.a = 1.0
			await process_frame
			await process_frame
			var path := "%s/%s_%s.png" % [out_dir, family, type]
			viewport.get_texture().get_image().save_png(path)
			print("PAWNCH_LEGIBILITY wrote %s" % path)
		rig.queue_free()
		await process_frame

	quit(0)

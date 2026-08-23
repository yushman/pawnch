extends Control
class_name PauseMenu

# What the pause control will open, drawn and placed and wired to nothing.
#
# **Nothing in the game calls show_menu().** The board-view spec is explicit that
# the pause and take-back controls are layout only in this change: there is no
# pause state to enter, no clock to stop and no history to leave a game back
# into, and a menu that opened would have to answer both of its own buttons. It
# exists so that the shape of the thing can be looked at in a render and argued
# about before it is built, and so the margins are laid out once rather than
# twice. tests/render_board_states.gd is the only caller.
#
# When it does get wired, the two buttons are already the two questions a child
# leaving a game asks: stop, or start over. Dismissal is the third and the
# default -- the panel goes away and the game is exactly where it was.
#
# Input is not handled here, for the same reason it is not handled in the
# banner: InputRouter owns every tap.

## Centred over the board's 660..1740, so it covers neither margin -- the same
## rule the game-over banner follows, and for the same reason.
const PANEL := Rect2(800, 230, 800, 620)
const TITLE_BASELINE := 350.0
const TITLE_SIZE := 56
## Two buttons a finger's width apart, each far wider than the 140 px the
## controls that will open this menu are.
const BUTTON_SIZE := Vector2(600, 130)
const BUTTON_GAP := 40.0
const FIRST_BUTTON_Y := 440.0
## Russian with every other string on screen (hero-banter spec). The label is
## also the identity here -- button_rect() finds a button by it -- so this is one
## list, not a label table beside a key table.
const BUTTONS := ["ЗАНОВО", "ВЫЙТИ"]
const CLOSE_CENTER := Vector2(1530, 300)
const CLOSE_RADIUS := 42.0
const CLOSE_TOUCH := 84.0

const PANEL_COLOR := Color(0.09, 0.10, 0.13, 1.0)
const PANEL_EDGE := Color(0.96, 0.62, 0.04, 1.0)
const GOLD := Color(0.96, 0.62, 0.04, 1.0)
const TEXT_COLOR := Color(0.97, 0.96, 0.93, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	print("PAWNCH_MENU ready buttons=%s" % ",".join(PackedStringArray(BUTTONS)))


func show_menu() -> void:
	visible = true
	queue_redraw()


func hide_menu() -> void:
	visible = false
	queue_redraw()


# Static, because it is arithmetic over constants and the layout check reads it
# off the script without building a menu.
static func button_rect(label: String) -> Rect2:
	var slot := BUTTONS.find(label)
	return Rect2(Vector2(PANEL.get_center().x - BUTTON_SIZE.x * 0.5,
		FIRST_BUTTON_Y + slot * (BUTTON_SIZE.y + BUTTON_GAP)), BUTTON_SIZE)


func _draw() -> void:
	draw_rect(PANEL, PANEL_COLOR)
	draw_rect(PANEL, PANEL_EDGE, false, 6.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(PANEL.position.x, TITLE_BASELINE), "ПАУЗА",
		HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, TITLE_SIZE, TEXT_COLOR)
	for label in BUTTONS:
		var box := button_rect(label)
		draw_rect(box, PANEL_EDGE, false, 5.0)
		draw_string(font, Vector2(box.position.x, box.get_center().y + 18), label,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 48, TEXT_COLOR)
	draw_arc(CLOSE_CENTER, CLOSE_RADIUS, 0.0, TAU, 40, GOLD, 5.0)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(CLOSE_CENTER - d * CLOSE_RADIUS * 0.42,
			CLOSE_CENTER + d * CLOSE_RADIUS * 0.42, GOLD, 8.0)

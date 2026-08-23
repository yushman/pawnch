extends Control
class_name HeroBanter

# The speech bubble over a commander, and the corpus it draws from.
#
# The lines live in assets/text/banter.json and nowhere else: written once,
# read once, shipped as data. Nothing here is generated, fetched or completed
# at runtime -- the app has no network and never will, and
# tools/check_no_internet.sh gates that.
#
# **This node decides nothing about what is said.** GameSession works out which
# side speaks, which situation it speaks into and when, and calls say(); the
# only judgement here is which unused line of that group comes next. That split
# is what keeps the two clocks -- the player spoken to before its move, the
# opponent after its own -- in the one file that knows when a move is over.
#
# Two bubbles, one per side, on independent timers. Both may stand at once and
# that is the point: consecutive lines read as an argument between the two
# commanders rather than as a caption. What they may not do is arrive together,
# which is why say() takes a delay rather than the caller sleeping on one.
#
# The art is procedural (ADR-0009): a rounded rect and a tail, no drawing.

const CORPUS := "res://assets/text/banter.json"
## The four situations, and the four keys every side has in the corpus. Order is
## not priority -- priority is GameSession's, because it is the thing that knows
## what has happened since a side last spoke.
const GROUPS := ["idle", "lost", "took", "check"]
const SIDES := ["white", "black"]

## Appear, hold, fade (hero-banter spec). The hold is what "stands while they
## think" is worth: long enough for a six-year-old to read 27 characters twice,
## short enough that a side that stares at the board for a minute is not left
## with a stale line over its head.
const RISE_SEC := 0.12
const HOLD_SEC := 3.6
const FADE_SEC := 0.5

## One size for every line, never fitted per line: a line that shrank to fit
## would announce which line is the long one. 44 px is the largest size at which
## the longest phrase in the corpus -- 27 characters, black's `took` group --
## still fits a bubble that fits a 660 px margin, measured against
## ThemeDB.fallback_font rather than guessed. The phrase itself is deliberately
## not quoted here: the corpus is the only place a line is written down.
const TEXT_SIZE := 44
const TEXT_PAD := Vector2(26.0, 18.0)
## Board's own margin pad, so a bubble stops where everything else in the band
## stops. 660 - 2*20 = 620 px of bubble, of which 568 is text -- and the widest
## line measures 566 wrapped to that, which is what sets the number.
const MAX_WIDTH := 620.0
const CORNER := 26
const BORDER := 5
## Base width and the shortest drop below the box. The tail's tip follows the
## commander's *drawn* top edge, so the box never moves and only the tail grows:
## the speaker is usually the idle commander, which stands 0.78 as tall as the
## active one, and a bubble that jumped 66 px when the turn changed would be the
## most distracting thing on the screen.
const TAIL := Vector2(46.0, 26.0)

const FILL := Color(0.97, 0.96, 0.93, 1.0)
const EDGE := Color(0.09, 0.10, 0.13, 1.0)
const INK := Color(0.11, 0.12, 0.15, 1.0)

@onready var board: BoardView = get_node_or_null("../Board")

## Public so a strange session can be replayed, the same way GreedyBot's is.
var rng := RandomNumberGenerator.new()

var _corpus := {}
# "white_idle" -> the lines of that group not yet shown this game, shuffled.
# Every line is shown once before any repeats, and reset() empties this so two
# games do not open the same way.
var _bags := {}
# "white" -> {"text", "t", "delay"}. Absent means that side has nothing on
# screen and nothing scheduled.
var _bubbles := {}
var _box := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	_load_corpus()
	_box.set_corner_radius_all(CORNER)
	_box.set_border_width_all(BORDER)
	print("PAWNCH_BANTER ready board=%s lines=%d seed=%d" % [
		board != null, line_count(), rng.seed])


func _process(delta: float) -> void:
	advance(delta)


# `group` is one of GROUPS; `delay` is how long after this call the line lands.
# A second say() for the same side replaces whatever that side had, scheduled or
# showing, so a line can never be left behind by the next one.
func say(side: String, group: String, delay := 0.0) -> String:
	if not _corpus.has(side) or not _corpus[side].has(group):
		return ""
	var text: String = _pick(side, group)
	_bubbles[side] = {"text": text, "t": 0.0, "delay": delay}
	queue_redraw()
	print("PAWNCH_BANTER say side=%s group=%s delay=%.2f text=%s" % [
		side, group, delay, text])
	return text


# Both bubbles, gone at once. The clash owns the screen and the ending belongs
# to the two commanders, so this is what a capture and a mate both do.
func clear() -> void:
	if _bubbles.is_empty():
		return
	_bubbles.clear()
	queue_redraw()


# A new game: nothing on screen and every bag reshuffled.
func reset() -> void:
	_bags.clear()
	clear()


# The clock, split out of _process so the checks can run it without a tree.
func advance(delta: float) -> void:
	if _bubbles.is_empty():
		return
	var changed := false
	for side in _bubbles.keys():
		var bubble: Dictionary = _bubbles[side]
		var before := _alpha(bubble)
		bubble["t"] = float(bubble["t"]) + delta
		if float(bubble["t"]) >= float(bubble["delay"]) + RISE_SEC + HOLD_SEC + FADE_SEC:
			_bubbles.erase(side)
			changed = true
		elif not is_equal_approx(_alpha(bubble), before):
			changed = true
	if changed:
		queue_redraw()


# True from the moment a line is asked for until the fade has taken it away,
# including the beat it spends waiting to appear. This is what the skip sweep
# records: a bubble a skip left behind is a 1 where the unskipped run has a 0.
func pending(side: String) -> bool:
	return _bubbles.has(side)


# What is actually on screen over `side`, or "" for nothing visible yet.
func line_on(side: String) -> String:
	if not _bubbles.has(side) or _alpha(_bubbles[side]) <= 0.0:
		return ""
	return String(_bubbles[side]["text"])


func line_count() -> int:
	var total := 0
	for side in _corpus:
		for group in _corpus[side]:
			total += (_corpus[side][group] as Array).size()
	return total


func lines_in(side: String, group: String) -> Array:
	return (_corpus[side][group] as Array).duplicate()


# The box for one line over one commander, in this control's own space. Public
# because the layout check has to hold it against the board, both graveyards and
# both commanders, and geometry that is only true inside _draw() is geometry
# nothing can check.
func bubble_rect(side: String, text: String) -> Rect2:
	var font := ThemeDB.fallback_font
	var wrap := MAX_WIDTH - TEXT_PAD.x * 2.0
	var content := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, wrap, TEXT_SIZE)
	var box := (content + TEXT_PAD * 2.0).ceil()
	var cell := Rect2(board.hero_origin(side), BoardView.HERO_CELL)
	return Rect2(Vector2(cell.get_center().x - box.x * 0.5,
		cell.position.y - TAIL.y - box.y), box).abs()


func _draw() -> void:
	if board == null:
		return
	for side in _bubbles:
		_draw_bubble(side, _bubbles[side])


func _draw_bubble(side: String, bubble: Dictionary) -> void:
	var alpha := _alpha(bubble)
	if alpha <= 0.0:
		return
	var text := String(bubble["text"])
	var box := bubble_rect(side, text)
	# The tip lands on the top edge of the commander as it is actually drawn,
	# which is 66 px lower when that commander is the idle one -- and the idle
	# one is the usual speaker, since the opponent is spoken for after its move
	# has passed the turn back.
	var tip := Vector2(box.get_center().x, board.hero_rect(side).position.y)
	draw_colored_polygon(PackedVector2Array([
		Vector2(box.get_center().x - TAIL.x * 0.5, box.end.y - BORDER),
		Vector2(box.get_center().x + TAIL.x * 0.5, box.end.y - BORDER),
		tip,
	]), Color(EDGE, EDGE.a * alpha))
	_box.bg_color = Color(FILL, FILL.a * alpha)
	_box.border_color = Color(EDGE, EDGE.a * alpha)
	draw_style_box(_box, box)
	var font := ThemeDB.fallback_font
	var inner := box.size.x - TEXT_PAD.x * 2.0
	draw_multiline_string(font,
		box.position + Vector2(TEXT_PAD.x, TEXT_PAD.y + font.get_ascent(TEXT_SIZE)),
		text, HORIZONTAL_ALIGNMENT_CENTER, inner, TEXT_SIZE, -1, Color(INK, INK.a * alpha))


# Rise, hold, fade. Zero while a line is still waiting out its beat, which is
# how the opponent's line lands first and the player's follows.
func _alpha(bubble: Dictionary) -> float:
	var t := float(bubble["t"]) - float(bubble["delay"])
	if t <= 0.0:
		return 0.0
	if t < RISE_SEC:
		return t / RISE_SEC
	var fading := t - RISE_SEC - HOLD_SEC
	if fading <= 0.0:
		return 1.0
	return maxf(0.0, 1.0 - fading / FADE_SEC)


# Every line of a group is shown once before any is shown twice: the bag is
# drawn down and only refilled when it is empty.
func _pick(side: String, group: String) -> String:
	var key := "%s_%s" % [side, group]
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = _shuffle(_corpus[side][group])
		_bags[key] = bag
	return String(bag.pop_back())


# Fisher-Yates over this node's own rng rather than Array.shuffle(), which draws
# from the global one and cannot be replayed from a printed seed.
func _shuffle(lines: Array) -> Array:
	var out := lines.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


# Keys beginning with an underscore are the file's own notes -- who each voice
# is, and the measured length of the longest line in each group -- and are not
# lines. Skipped here rather than stripped from the file, because the notes are
# the reason the corpus can be reviewed at all.
func _load_corpus() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CORPUS))
	if data == null:
		push_error("banter corpus missing or malformed: %s" % CORPUS)
		return
	for side in SIDES:
		_corpus[side] = {}
		for group in GROUPS:
			_corpus[side][group] = (data[side][group] as Array).duplicate()

extends SceneTree

# The headless entry point: `godot --headless --script tests/run_headless.gd`.
# Exits 0 only when the suite loaded, ran, and every check in it passed.
#
# This file is deliberately tiny and deliberately boring, because it is the one
# thing that cannot be allowed to break. Twice on Day 5 a typo left the whole
# suite unloaded: `SCRIPT ERROR: Parse Error`, zero `check:` lines printed, and
# **exit code 0**. Godot exits 0 whatever happens to a `--script` file, and a
# script that never parsed cannot report its own failure -- so the only thing
# that can catch it is a second file, small enough that nobody edits it, which
# checks that the file people do edit actually loaded.
#
# `load()` is not enough on its own: a GDScript with a parse error still comes
# back as a non-null Script object. `can_instantiate()` is what returns false.
#
# The third failure this guards is quieter than either: a runtime error or a
# stray early return inside the suite drops a whole block of checks without
# failing any, so the count is asserted against a floor as well.

const SUITE_PATH := "res://tests/suite.gd"
## Raise this with the suite. A run that comes back with fewer checks than the
## suite is known to contain has lost some of them somewhere that did not fail.
const MIN_CHECKS := 184


func _initialize() -> void:
	var started_msec := Time.get_ticks_msec()
	var suite_script: Script = load(SUITE_PATH)
	if suite_script == null or not suite_script.can_instantiate():
		print("PAWNCH_TEST FAIL reason=suite_did_not_load path=%s" % SUITE_PATH)
		quit(2)
		return

	var suite: RefCounted = suite_script.new()
	await suite.run(self)

	var passed: int = suite.passed
	var failed: int = suite.failed
	var checks := passed + failed
	var ok := failed == 0 and checks >= MIN_CHECKS
	if checks < MIN_CHECKS:
		print("PAWNCH_TEST FAIL reason=too_few_checks ran=%d min=%d" % [checks, MIN_CHECKS])
	print("PAWNCH_TEST %s checks=%d passed=%d failed=%d min=%d elapsed=%.1fs" % [
		"PASS" if ok else "FAIL", checks, passed, failed, MIN_CHECKS,
		(Time.get_ticks_msec() - started_msec) / 1000.0])
	quit(0 if ok else 1)

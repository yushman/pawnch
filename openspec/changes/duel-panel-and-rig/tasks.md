## Implementation Tasks

Day 2 of `docs/mvp-plan.md` (~8h, *M4 1/3 and 2/3*). **Done when:** on the phone, a debug button
wipes the duel panel in, shows a knight and a pawn idling in frame at ≥50 fps, and wipes out.
No fight yet — the clash itself is Day 3.

If the rig alone eats both half-days, that is an acceptable trade. Day 3 does not slide.

---

## The art contract

Numbers below are derived from `docs/system-analysis.md` and
[ADR-0003](../../../docs/adr/0003-one-shared-2d-rig-pvz-art-direction.md). They are what the
scenarios in `specs/` are measured against, and violating one is expensive to undo later.

**Screen geometry.** Reference 1080×2400 (20:9); supported band 16:9 to 20:9. Everything that
matters — both characters, the point of impact, all effects — lives inside a **1080×1920 safe
band centred vertically**. On a 16:9 device the outer 240 px top and bottom do not exist. The
duel panel is 1080×1500, centred; the board stays visible, dimmed, above and below it.

**Character scale.** ~1000 px tall on screen. **Author at ~1400 px tall** (1.4×) — downscaling is
free and looks good, upscaling does not.

**Part budget: 12 parts per character, hard cap 16.**

```
       [head]                 ← unique per piece type (helmet / crown / mitre)
          │
  [arm_f]─┼─[arm_b]           f = far side, b = near side
     │    │     │
 [fore_f] │  [fore_b]
     │  [torso]  │
  [weapon]       │            ← unique per piece type
       ┌──┴──┐
  [thigh_f] [thigh_b]
      │        │
  [shin_f]  [shin_b]

+ a shadow blob under the feet (drawn, not part of the hierarchy)
```

Shared across all six types: torso, both arms, both forearms, both thighs, both shins. Unique per
type: head and weapon. **18 distinct images total** for all six piece types.

**Hierarchy: nested `Node2D` transforms, not `Skeleton2D` + `Polygon2D`.** Rotating a parent
carries its children, `AnimationPlayer` drives it directly, and there are no vertex weights to
paint. ADR-0003 already accepted that parts hinge rather than deform, so the deformation
`Polygon2D` would buy is not wanted.

**Joint overlap.** A part extends past its joint centre by 15–20% of the limb's width, with a
rounded cap. Verify by rotating each joint 30–40° in the editor: no gap may appear. This is the
`Articulation does not show gaps` scenario.

**Atlas discipline — this is what makes the ~60 draw-call budget reachable.** Twelve parts × two
characters is 24 sprites; with 24 separate textures that is 24 draw calls before the board, the
panel and any effects. Batched from one atlas page it is one or two.

```
page 1 (2048×2048)   all rig parts + 6 heads + 6 weapons   → 1–2 calls
page 2 (2048×2048)   impact VFX, stars, dust, panel trim   → 2–4 calls
board atlas          board + piece sprites                 → 2–3 calls
panel background     gradient / stretched, not a big PNG    → 1 call
```

Three rules keep that true, and all three are load-bearing:

1. **2048×2048 per page, no larger.** GLES3 guarantees it everywhere; the Compatibility renderer
   was chosen for weak hardware and should not acquire a dependency on 4096.
2. **No per-part material or shader. Outlines are baked into the artwork.** ADR-0003 forbids
   per-part shader work precisely because it breaks batching.
3. **Z-order must not interleave atlas pages.** Effects draw entirely above or entirely below
   both characters, never between a character's own parts.

Area check: one character ≈ 0.8 Mpx (torso ~400×500, head ~350×350, arm segments ~150×450,
leg segments ~180×500, weapon ~200×700) against 4.2 Mpx per page — the 18 shared images fit with
room. The 1080×1500 panel background is 1.6 Mpx on its own, which is why it stays out of the
character atlas.

**Pivots.** The rig is assembled exactly once, so pivot bookkeeping is a one-time cost: export
parts trimmed, note each joint position as a fraction of the part's size, set the offset once
during assembly. The rule that *does* matter, because it is paid six times over if broken:

> **All six heads share one canvas size and one anchor. All six weapons share one canvas size and
> one grip anchor.** They drop into the same rig slot.

**Board sprites are exported from the rig, not drawn separately.** Each piece type's idle pose is
rendered to a single flat ~110 px sprite for the board — one export per type. Identity between
board and duel comes for free, and the same flattened image is what the silhouette test runs on.

**Black side is one shader parameter applied to the whole character**, not per part and not a
second set of textures. One batch for white, one for black. Prove it on the pawn before drawing
the other five.

**Clash timing skeleton.** Impact must land within the first ~0.6 s; the whole clash must fit in
2.0 s. That leaves one workable layout, and the animation can be authored against it before any
of the juice code exists:

```
0.00 ─ 0.15   wipe in        panel enters, board dims
0.15 ─ 0.40   wind-up        crouch, weapon back, anticipation
0.40 ─ 0.55   charge         lunge, smear pose, stretch
0.55          ▮ impact cue ▮  hitstop, shake, VFX, SFX, haptic
0.55 ─ 0.70   hitstop        everything frozen
0.70 ─ 1.10   recoil cue     defender knocked back, attacker follow-through
1.10 ─ 1.40   defeat/settle  stars, landing
1.40 ─ 1.70   exit cue       wipe out, board returns
──────────────────────────────────────────────────────────
total 1.70 s ≤ 2.0 ✓     impact at 0.55 ≤ 0.6 ✓     0.3 s spare
```

Wind-up is deliberately *longer* than the charge (0.25 s against 0.15 s). Anticipation is what
sells an impact to a six-year-old; the hit itself is not.

---

## Tasks

- [ ] **Duel panel scene: framing, background, board dimming.** 1080×1500 panel centred in the
      1080×1920 safe band, board dimmed and pushed back behind it, background built from a
      gradient and stretched elements rather than one large texture.
      *Verify:* run at 1080×2400 and at 1080×1920 — nothing that matters is cropped at 16:9, and
      the extra height at 20:9 shows only background.

- [ ] **Wipe in and wipe out.** Wipe in ≤150 ms, wipe out ≤300 ms, driven by an
      `AnimationPlayer` so the durations live in the animation and not in code.
      *Verify:* on the Redmi Note 13, open and close the panel from a debug button;
      `tools/frametime` reports no frame over 20 ms and ≥50 fps through both transitions.

- [ ] **Build the shared rig.** 12 nested `Node2D` parts per the diagram, assembled once, with
      pivots set during assembly. Idle, hit and defeat states on an `AnimationPlayer`.
      *Verify:* rotate every joint to its animation extremes — no gaps; the three states are
      visually distinct.

- [ ] **Author the pawn and the knight.** Shared body parts plus two heads and two weapons, drawn
      at ~1400 px character height, all on one 2048×2048 atlas page, outlines baked in, no
      per-part material.
      *Verify:* both are identifiable filled solid black at 110 px tall. If not, redraw the
      head or the weapon — this test gates the task, it does not follow it.

- [ ] **Cue markers on the timeline.** `impact`, `recoil` and `exit` emitted from the animation
      timeline, with nothing consuming them yet.
      *Verify:* a debug print shows the three cues firing in order at the authored times.

- [ ] **Black-side recolour on the pawn.** One shader parameter over the whole character.
      *Verify:* white and black pawns side by side are unambiguous at a glance; the draw-call
      count with both on screen is unchanged apart from the one extra material batch.

- [ ] **Board sprite export.** Flatten the pawn's and the knight's idle poses to ~110 px sprites
      for the board atlas.
      *Verify:* both are readable at board scale on the phone, and are recognisably the same
      characters as in the panel.

- [ ] **Warm the panel's assets at boot.** Everything the panel draws is loaded and its materials
      touched during startup, so the first open after a cold start does not compile a shader or
      upload a texture.
      *Verify:* cold-start the app and open the panel immediately; `tools/frametime` shows the
      first open meeting the same budget as a later one. This is failure mode 4 and it only
      appears on the device.

- [ ] **Draw-call measurement with the panel open.** Both characters idling, panel open.
      *Verify:* the number is recorded in the devlog against the ~60 budget, with the command
      that produced it.

- [ ] **Devlog entry for Day 2.** The measured frame times and draw-call count with their
      commands, whether the silhouette test needed a redraw and how many, and how much of the two
      half-days the rig actually consumed against its estimate.
      *Verify:* `docs/devlog.md` has a dated entry. If the rig ate both half-days, say so — Day 3
      still happens, with less polish.

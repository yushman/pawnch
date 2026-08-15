# Research

**Started:** 2026-08-15

## Context

Cycle target: a **12 working day (24 half-day) solo build** producing a playable Android
prototype.

Constraints carried in from the user before research began:

- **Platform:** Android only. No iOS, no web, no desktop.
- **Audience:** kids roughly 6–12.
- **Domain:** chess, as a game rather than as a teaching product.

This cycle entered at validation with one candidate already chosen — an Android chess game
for kids. The rubric below is therefore applied to the two *scope forms* that candidate took,
because that is the comparison that actually decided the project: the broad form was
researched, scored, and killed; the narrow form was re-validated from scratch and survived.
Recording both is the point. The interesting finding of this cycle is not "chess game good",
it is that a 6-point swing in the score came entirely from **subtracting** features.

## Candidates

### 1. Kids Chess Academy — a story-campaign chess app that teaches kids chess

Story campaign with a world map and mini-bosses, progressive lessons, a voice assistant that
explains moves, a hint mode, per-piece visual upgrades on capture, and a cosmetic skin
economy on top of a free base game.

**Pain evidence:**
- [ChessKid surpassed 10M individual kid accounts](https://www.chess.com/blog/ChessKid/chesskid-surpasses-10-million-kids-playing-chess-on-the-site) (Jan 2024), 500k+ games/month, 200k+ MAU — large, real, paying demand for kids' chess apps.
- [Kahoot! Learn Chess: DragonBox](https://play.google.com/store/apps/details?id=com.kahoot.chess) charges $9.99/mo or $59.99/yr with no free tier beyond a 7-day trial — parents demonstrably pay recurring money here.
- [Duolingo shipped a chess course in 2025](https://blog.duolingo.com/chess-course) — a company with that distribution entering the category is evidence the category is live.

**Existing solutions:**
- [Chess Adventure for Kids](https://play.google.com/store/apps/details?id=chesskid.adventure) (Chess.com) — 40+ fantasy bosses with backstories across 15 difficulty levels, character customization and outfits bought with in-game coins, 6 story quests with 200+ mini-challenges. Free with an existing ChessKid login. This is a near-1:1 match for the pitch.
- [ChessKid main app](https://play.google.com/store/apps/details?id=com.chesskid) — free lessons from "how does a pawn move" to mate patterns, a hint button that highlights and explains good moves, bot personalities, video lessons, coach-mode game review.
- [Dr. Wolf](https://play.google.com/store/apps/details?id=com.chess.chesscoach) (Chess.com) — a virtual coach giving spoken feedback after *every move*, tailored to skill level. The "voice assistant explaining moves" feature, already shipped.
- [Kahoot!/DragonBox](https://www.appbrain.com/app/kahoot-learn-chess-dragonbox/com.kahoot.chess) — Magnus Carlsen-branded, world-map RPG chess teaching for ages 5+, from a studio known for playtested kids' learning games.
- [lichess](https://lichess.org) — free, open-source, has a Learn section, no kid character layer. The "boring but trustworthy" option.

**12-day core:** a story map with a handful of bosses, a lesson track, and the capture-upgrade
mechanic — i.e. three content pipelines at once.

**Scores:** pain 4 / self-use 2 / feasibility **2** / demo 4 / story 2 / gap 1 = **15**

**Main risk:** it is a content-volume competition against three funded incumbents. A solo dev
does not out-produce 40 bosses and 200 mini-challenges in twelve days, and the only remaining
differentiator — per-piece capture animation — is buried under everything else.

**Naming:** "Kids Chess Academy" is also unusable. Play is saturated with
[Chess Academy for Kids](https://www.commonsensemedia.org/app-reviews/chess-academy-for-kids-by-geek-kids),
[Champions Chess Academy](https://play.google.com/store/apps/details?id=com.champions_chess_academy.shortcastle),
[ChessKids](https://play.google.com/store/apps/details?id=com.chesskids.shortcastle),
[Kid Chess App](https://play.google.com/store/apps/details?id=com.kidchess.app.app) and
[ChessWorld](https://play.google.com/store/apps/details?id=com.altermanchess.AltermanChessEdu).
It would land on page 3 of its own name.

---

### 2. Pawnch — every capture is a full-screen character duel

The same candidate with the story, the lessons, the voice coaching, the hints and the
cosmetics **all removed**. One mechanic remains: when a piece takes a piece, the board cuts
away to a framed duel panel and the two characters fight — hitstop, screen shake, VFX, sound,
haptics — then the panel wipes and the board returns.

**Pain evidence:**
- [Ani Chess 3D](https://play.google.com/store/apps/details?id=anichess.gsgames.asia) (formerly Battle Chess 3D, dev GS Games): **1,000,000+ installs, ~38,681 ratings**, free, content rated 7+, multi-year sustained existence. That is proof the mechanic has a mass mobile market.
- The same listing's reviews are the friction: graphics "kind of low quality", and the birds-eye camera means you "can't really see the artwork" during play. The demand is proven *and* the incumbent's execution is publicly complained about, in the exact two places this project attacks.
- [Combat Chess](https://store.steampowered.com/app/1557050/Combat_Chess/) (Steam, Player Score 83/100) is praised specifically for animation — "stunning", "fluid", clashes "particularly impressive". Proof that doing this *well* is received well. But PC-only, general-audience, and a tiny title.

**Existing solutions:**
- Ani Chess 3D — mobile, at scale, free, but the art is the complaint (above).
- Combat Chess — well animated, but PC, not kid-branded, review counts in the dozens.
- [Apochess](https://apochess.com/) — browser, captures trigger animated RPG battles with HP/ATK/DEF, crits and poison. Validates the combat layer, not mobile, not kids.
- [Chess Warfare 3D](https://play.google.com/store/apps/details?id=com.chess.apptwig) — fantasy battle chess with equippable weapons and spells. Mixed reviews, less traction than Ani Chess 3D.
- [Battle Chess HD](https://apps.apple.com/us/app/battle-chess-hd/id6538715222) (iOS, $2.99) — 2 ratings, 3.0 average, crash reports on load. A low-effort attempt at this exact concept that shipped broken and sank. Cautionary, not a market signal.

**12-day core:** one clash animation, at a quality that visibly beats a free app with a
million installs. Everything else in the build exists to give that animation somewhere to
happen.

**Scores:** pain 4 / self-use 2 / feasibility **3** / demo 5 / story 3 / gap 4 = **21**

**Main risk:** it is a pure production-quality bet. The mechanic is 38 years old (Battle
Chess, 1988). Nothing here is novel in kind — the wedge is entirely "we can animate this
better than the incumbent does", which is a claim that can only be settled by making one
animation and looking at it.

## Ranking

| # | Scope form | Pain | Self-use | Feas. | Demo | Story | Gap | Total | Gates | Verdict |
|---|-----------|------|----------|-------|------|-------|-----|-------|-------|---------|
| 2 | **Pawnch** — captures are duels | 4 | 2 | 3 | 5 | 3 | 4 | **21** | pass | **Go** (conditional) |
| 1 | Kids Chess Academy — story + lessons | 4 | 2 | 2 | 4 | 2 | 1 | 15 | **feasibility < 3 → drop** | No-go |

### The score change, and why it moved

Same idea, same author, same twelve days, **+6 points** — recorded here because the mechanism
is the reusable lesson.

| Axis | Broad → Narrow | Why |
|------|----------------|-----|
| Feasibility | 2 → 3 | The broad scope needed three content pipelines (story, lessons, cosmetics) against incumbents shipping 40 bosses and 200 challenges. The narrow scope needs six animations, and only because of three locked decisions: 2D, one shared rig, one cutaway camera. It clears the gate — barely, and only with those locked. |
| Gap | 1 → 4 | The broad scope's every feature is already shipped by Chess.com, Kahoot!/DragonBox and Duolingo. The narrow scope's intersection — mobile **and** kid-appropriate **and** genuinely well animated — has no occupant: the one app at scale is reviewed as visually mediocre, the one reviewed as well-animated is PC-only and tiny. |
| Demo | 4 → 5 | The deliverable shrank to a thing that *is* a 15-second vertical video. Nothing has to be explained before it is impressive. |
| Story | 2 → 3 | Content production has no technical story. The narrow scope does: how the cutaway framing collapses Battle Chess's 35 attacker×defender combinations into 6 animations, and what fits in a 16 ms frame on a mid-range phone. |
| Pain | 4 → 4 | Unchanged, but the *evidence* is better: round 1's pain was "kids' chess apps are popular", round 2's is a named 1M-install app with a named, quotable complaint about the exact thing being fixed. |
| Self-use | 2 → 2 | Unchanged and still the weakest axis. The author is not the user; the feedback loop is a playtest rather than daily use. The success metrics compensate by requiring a real kid in the room, not a proxy. |

Inherited scores were treated as provisional and the competitive check was re-run in full
from scratch, not carried over. That re-run is what found Ani Chess 3D — round 1 had been
looking at the wrong competitors entirely (kids' *education* apps), and the real incumbent
was in a different category the first search never touched.

## Recommendation

**Build Pawnch — the narrow form.** It wins on the only two axes that were contested. The
broad form loses the gap axis outright: every one of its features is shipped, free, by a
company with 10M kid accounts, and the honest answer to "why would someone use ours" is
"ours is newer". The narrow form has a gap backed by public reviews of a live app, and it
converts an unwinnable content-volume fight into a craft fight against an incumbent whose own
users say the craft is weak.

The trade is that it is now a **pure execution bet with no fallback position**. If the
animation is not visibly better, there is no second differentiator to retreat to — which is
why the whole plan is arranged around producing that one animation first and judging it on
day 3, while eight days are still recoverable.

**Name:** *Pawnch* (pawn + punch). One syllable, states the product in six letters, and a
6-year-old can both pronounce and understand it on first hearing. Collision check is **clean**
— nothing on Google Play, the App Store, Steam or itch.io, no trademark hits, package id
`com.pawnch.game` free. Play returns only generic `Pawn*` chess apps
([Pawn Play](https://play.google.com/store/apps/details?id=com.developpixel.pawnplay),
[Pawn of the Dead](https://apps.apple.com/us/app/pawn-of-the-dead-chess-game/id811061183)),
none competing for the literal string. Non-blocking noise only: a never-shipped
[fan-wiki title](https://fantendo.fandom.com/wiki/PAWNCH!_(2012_Game)), a
[WoW character](https://worldofwarcraft.blizzard.com/en-us/character/eu/blackmoore/pawnch),
and a Nintendocore band [Falcon Pawnch!!!](https://music.apple.com/us/artist/falcon-pawnch/1198939093).
Only downside: homophone with "paunch" — acceptable, nobody types it, they see the icon.

Rejected during the name search for live collisions: **Clashmate**
([ClashMates: Study Game](https://play.google.com/store/apps/details?id=com.thirdshake.clashmates),
[Clash Mate — Stats & Decks](https://play.google.com/store/apps/details?id=com.romerock.apps.utilities.clashroyale.tournamentfinder));
**Thwack** ([Thwack Studio](https://play.google.com/store/apps/developer?id=Thwack+Studio) is an
existing Play developer, plus SolarWinds' THWACK owns the general-web result);
**Smashmate** ([the Smash Bros. Ultimate ladder site](https://www.ssbwiki.com/Smashmate));
**Gambrawl** (clean string, but [Gambol](https://store.steampowered.com/app/713310/Gambol/) and
[Gambonanza](https://store.steampowered.com/app/3509230/Gambonanza/) are two live Gamb-prefixed
indie chess-ish titles, and "gambit" is vocabulary a 7-year-old does not have);
**Rookus** (clean, but Hasbro holds a long-standing
[ROOK trademark](https://trademarks.justia.com/710/59/rook-71059489.html) in the games class,
and the name says nothing about fighting).

---

## Validation (chosen idea)

Two rounds. Round 1 validated the broad scope and returned **No-go**. The user then narrowed
the hook to combat-capture spectacle, and round 2 re-validated from scratch and returned
**conditional go**.

### Round 1 — broad scope: No-go

**Platform/incumbent check.** The dominant incumbent already builds almost this exact product.
Chess.com's ChessKid ecosystem has [10M+ kid accounts](https://www.chess.com/blog/ChessKid/chesskid-surpasses-10-million-kids-playing-chess-on-the-site),
and its companion app [Chess Adventure for Kids](https://apps.apple.com/us/app/chess-adventure-for-kids/id1474398798)
ships 40+ fantasy bosses with backstories across 15 difficulty levels, customizable character
outfits bought with in-game coins, 6 story quests with 200+ mini-challenges, a puzzle duel
mode and 100,000+ puzzles — free with an existing ChessKid login, bundled into Gold rather
than sold separately. The [main ChessKid app](https://www.chesskid.com/learn/articles/complete-guide-to-chesskid)
ships the lessons and the hint button. [Dr. Wolf](https://www.chess.com/news/view/dr-wolf-joins-chess-com)
ships the voice coaching. This was the "invisible incumbent" risk, and it turned out to be the
dominant finding rather than a footnote.

**Where the incumbents stop:** none of them do stylized *combat/capture animation with
per-piece visual upgrade progression*, and none sells cosmetic skins à la carte on a free
base. That gap is real but narrow — and the second half of it is a monetization model, not a
product.

**Competitor teardown (round 1).**

| Competitor | Does well | Breaks | Verdict |
|-----------|-----------|--------|---------|
| [Chess Adventure for Kids](https://play.google.com/store/apps/details?id=chesskid.adventure) (Chess.com) | Fantasy-boss RPG framing, character customization, story quests, 10M-account safety/moderation infrastructure, brand trust with parents and schools | No per-piece capture-combat animation; bosses are defeated, individual pieces do not level up. Reviews note many features sit behind paid Gold and free users hit limits fast. A bolt-on to ChessKid rather than a self-contained game | **Most dangerous direct competitor.** Same core hook, 6+ years of chess-app expertise, zero marginal cost to a parent already inside ChessKid Gold. The pitch is not better on the RPG/character axis at all |
| [Kahoot! Learn Chess: DragonBox](https://play.google.com/store/apps/details?id=com.kahoot.chess) | DragonBox pedagogy, playtested kids' learning-game design, world-map RPG for ages 5+, no ads | $9.99/mo or $59.99/yr after a 7-day trial, no free base game | Proves the subscription model works, but sets parent price expectations at $60–120/yr for a *whole* app, which undermines a cosmetic-skin-pack model on a free base |
| [Duolingo Chess](https://blog.duolingo.com/chess-course) | Enormous install base, streak habit loop, mascot gamification, bite-sized puzzle-first lessons, free | Not kid-specific; [a reviewer called it "useless for non-beginners"](https://www.chess.com/blog/raync910/duolingo-chess-review); no story campaign or capture combat — closer to Anki-with-chess | Not a direct RPG competitor, but a massive distribution threat for the exact "teach my kid chess" search intent, and proof that huge companies see this as worth building in 2025–2026 |

**Riskiest assumption (round 1):** that a solo dev can produce professional-quality character
art, capture-combat animation and VFX fast enough to look better than Chess.com's (funded) or
DragonBox's (award-winning kids-edu studio) existing character products. The wedge was
explicitly a *polish* bet, and the features around it were already commoditized by three
funded players.

**Cheap spike (round 1).** Ran a store check. Confirmed the 10M ChessKid accounts and the
Kahoot! price point live. On assets: Unity and Godot marketplaces (Synty, CGTrader,
fantasy3dassets.com) do sell stylized fantasy-warrior packs and chess-specific prop sets, so
base art is purchasable — but **none found are pre-rigged for per-piece capture/attack
sequences with an upgrade state machine.** The combat-animation layer is bespoke work, and
that is the actual bottleneck, not raw art. Left unresolved: whether one person can animate 6
piece types × 3–4 upgrade tiers × attack sequences in a sprint. Nothing off the shelf does it.

**Go/No-go (round 1): No-go as scoped.** The story campaign, voice coaching, hint mode,
cosmetic skins and world map are all already shipped at scale by three funded incumbents. The
one remaining differentiator is a production-polish bet buried under features that would
consume the entire sprint before reaching it. The naming space is also saturated.

### Round 2 — narrowed to "captures are duels": conditional go

Scope change from round 1: story, lessons, voice coaching and cosmetics dropped or made
secondary. Core hook = every capture triggers a stylized piece-vs-piece combat animation.

**Prior art check — this idea is 38 years old.**
[Battle Chess (Interplay, 1988)](https://en.wikipedia.org/wiki/Battle_Chess) is literally this
pitch: chess pieces come to life and fight when one captures another, with **35 distinct
battle animations** (6 piece types × colors, no king-captures-king). Iconic on DOS, Amiga and
NES ([MobyGames](https://www.mobygames.com/game/1950/battle-chess/),
[TVTropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/BattleChess)).
Its 2015 remaster, [Battle Chess: Game of Kings](https://store.steampowered.com/app/200150/Battle_Chess_Game_of_Kings/)
($29.99, Steam), was redone in 3D/HD by a professional studio with a real budget and landed
**mixed: Player Score 52/100 from 370 reviews** (193 positive / 177 negative), with reviewers
citing bugs, "alarmingly weak" AI, and high price for limited content
([Steambase](https://steambase.io/games/battle-chess-game-of-kings/reviews)).

That last data point matters more than it looks: **a funded studio spent a 3D budget on this
exact idea and still scored 52/100.** Fidelity is not what makes it work.

**Competitor teardown (round 2) — the real competitors.**

| Competitor | Does well | Breaks | Verdict |
|-----------|-----------|--------|---------|
| **[Ani Chess 3D](https://play.google.com/store/apps/details?id=anichess.gsgames.asia)** (GS Games, Android/iOS, free; [App Store](https://apps.apple.com/us/app/ani-chess-3d/id1637877443); [prior listing](https://play.google.com/store/apps/details?id=gs.battlechess.vn)) | **1M+ installs, ~38,681 ratings, ~40,000 active players**, rated 7+, 8 humanoid 3D fantasy chess sets (Barbarian, Dwarf, Undead, Orcs, Spartan, Elf, Viking, Kingdom), pieces visibly stab/take over on capture, online play via the lichess API, multi-year sustained existence | Reviews are mixed: graphics "kind of low quality"; birds-eye view means you "can't really see the artwork" during actual play; difficulty-tuning complaints; occasional bugs. Not kid-specific — no kid mode, no parental controls. More novelty skin than duel choreography | **This is the real direct competitor.** It proves the mechanic has a mass mobile market *and* that the default execution bar in this niche is mediocre — leaving room above it, not below it |
| [Combat Chess](https://store.steampowered.com/app/1557050/Combat_Chess/) (Steam, PC) | "Mostly Positive", Player Score 83/100. 600+ animation sequences including idle/fidget states; praised specifically for animation — "stunning", "fluid", clashes "particularly impressive" | PC-only, not mobile, not aimed at kids, and small: review counts in the dozens, not thousands | Proof that a *well-executed* version of this mechanic is genuinely well received — but by a tiny PC niche, so it is a quality proof, not a market-size proof |
| [Apochess](https://apochess.com/) (browser, free; [Kongregate](https://www.kongregate.com/en/games/mansimas/apochess)) | Captures trigger animated real-time RPG battles with HP/ATK/DEF, crits, poison, heals. Reviews positive — "genuinely fun, addictive, very creative" | Not kids-specific, not mobile-native | Validates the combat layer as something players respond to, beyond cosmetic animation |
| [Chess Warfare 3D](https://play.google.com/store/apps/details?id=com.chess.apptwig) | Fantasy battle chess with equippable weapons, spells, legions | Mixed reviews ("so much potential"), difficulty-calibration complaints, less traction than Ani Chess 3D | Smaller sibling of the main competitor |
| [Battle Chess HD](https://apps.apple.com/us/app/battle-chess-hd/id6538715222) (iOS, $2.99) | — | 2 ratings, 3.0 average, crash reports on load | Evidence a low-effort attempt at this exact concept ships broken and sinks without trace. Execution risk, not market data |

**The incumbent tried this and pulled it.** Chess.com/ChessKid shipped a **"Battle Mode"**
board-animation setting, described by its own developer as "mostly added for kids on
ChessKid" — arcade-style capture effects selectable alongside Slow/Medium/Fast/Natural. Forum
threads report the option was later **removed**
([thread 1](https://www.chess.com/forum/view/community/have-you-tried-battle-mode-animation-style),
[thread 2](https://www.chess.com/forum/view/general/battle-mode-animation)).

This cuts both ways. It confirms the dominant kids product independently decided the idea was
worth building and marketed it at kids specifically. But they discontinued it — from low
usage, from engineering cost, or because generic board VFX is much shallower than a per-piece
duel with character reactions. Not proof the deeper version fails; a real signal to test
stickiness early rather than assume it.

**Adjacent (minor):** [Gambonanza](https://store.steampowered.com/app/3509230/Gambonanza/)
(2026, Steam/mobile roguelike) makes losing a piece permanent for a run — not a per-capture
duel, but another 2026 data point that "chess + gamified capture stakes" is an active indie
genre right now.

**Who exactly.** A kid aged 6–12 — or a parent browsing the store for them — who already plays
fighting/RPG-lite mobile games, finds plain chess visually boring and static, and picks
whichever chess app *looks the most like an actual game* in its screenshots and preview video.
Judged in the first ten seconds by whether captures look cool, not by lesson depth.

**The wedge.** *A mobile, kid-safe chess app where every capture is a genuinely
fighting-game-quality duel — filling the gap between Ani Chess 3D (1M+ installs, but reviewers
call the art "kind of low quality" and the birds-eye camera means you can't see it anyway) and
Combat Chess (animation reviewers call "stunning", but PC-only, not kid-branded, tiny
audience).* Mobile **and** kid-appropriate **and** high production animation, all three at
once, has no clear incumbent today.

State plainly what kind of wedge this is: a **quality and positioning wedge, not an idea
wedge.** The mechanic has existed since 1988 and has live mobile clones right now. The bet is
that we can out-animate a free 1M-download incumbent — not that nobody thought of this.

**Riskiest assumption (shifted from round 1).** *Can a solo dev produce clash animations at a
bar clearly above Ani Chess 3D's "kind of low quality" execution — and is animation spectacle
**alone**, with no story, lesson or cosmetic layer, sufficient reason for a kid to choose this
over a free, already-installed incumbent doing the same basic mechanic?*

Secondary risk: ChessKid built and then removed a shallow version of this inside the dominant
kids product. A soft signal (not proof) that spectacle alone may not be sticky without an
identity or progression layer attached — which is why the sprint measures skip rate on a real
kid rather than assuming.

**Kill criteria.** Build **one** capture animation — knight takes pawn — to the target quality
bar, put it next to a screen recording of the same capture in Ani Chess 3D, and look at the
two side by side. If ours does not obviously read as better, **kill it**: at that point the
wedge collapses back to nothing and the remaining days would go into building a worse copy of
a free app. One retry is allowed, and only one — switch art direction from semi-realistic to
heavily stylized, where craft beats fidelity — and if it fails twice, stop. This is written
into `docs/mvp-plan.md` as the day-3 checkpoint with its fallback, because deciding it
mid-build with four days invested never works.

**Go/No-go (round 2): conditional go.** Materially stronger than round 1, but now a pure
execution bet, and the condition is that the spike comes first.

- Dropping the story/lesson/cosmetic layer removes the weakest, most-covered part of the pitch
  — the part where three funded incumbents were already winning.
- The mechanic is not novel in kind, but the specific intersection is genuinely unoccupied,
  and that is backed by public reviews of a live app rather than by wishful thinking.
- The risk moved from "can we out-write a funded incumbent's content" (near-impossible solo)
  to "can we out-animate a free mobile incumbent whose bar is admittedly not high" (hard, but
  gradeable and spikeable before real budget is committed).
- Therefore: the animation goes first in the plan, and the go/no-go is re-taken on day 3 with
  eight days still recoverable.

### Sources

- https://www.chess.com/blog/ChessKid/chesskid-surpasses-10-million-kids-playing-chess-on-the-site
- https://www.chesskid.com/learn/articles/chesskid-celebrates-10-million-kids
- https://www.chess.com/news/view/new-chesskid-adventure-app-released
- https://www.chesskid.com/learn/articles/chesskid-adventure-launch
- https://apps.apple.com/us/app/chess-adventure-for-kids/id1474398798
- https://play.google.com/store/apps/details?id=chesskid.adventure
- https://www.chesskid.com/learn/articles/complete-guide-to-chesskid
- https://play.google.com/store/apps/details?id=com.chesskid
- https://www.chess.com/news/view/dr-wolf-joins-chess-com
- https://play.google.com/store/apps/details?id=com.chess.chesscoach
- https://www.appbrain.com/app/kahoot-learn-chess-dragonbox/com.kahoot.chess
- https://play.google.com/store/apps/details?id=com.kahoot.chess
- https://www.entrepreneur.com/business-news/duolingo-introduces-a-chess-course-for-all-skill-levels/490406
- https://www.chess.com/blog/raync910/duolingo-chess-review
- https://blog.duolingo.com/chess-course
- https://en.wikipedia.org/wiki/Battle_Chess
- https://www.mobygames.com/game/1950/battle-chess/
- https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/BattleChess
- https://store.steampowered.com/app/200150/Battle_Chess_Game_of_Kings/
- https://steambase.io/games/battle-chess-game-of-kings/reviews
- https://play.google.com/store/apps/details?id=anichess.gsgames.asia
- https://apps.apple.com/us/app/ani-chess-3d/id1637877443
- https://play.google.com/store/apps/details?id=gs.battlechess.vn
- https://store.steampowered.com/app/1557050/Combat_Chess/
- https://apochess.com/
- https://www.kongregate.com/en/games/mansimas/apochess
- https://play.google.com/store/apps/details?id=com.chess.apptwig
- https://apps.apple.com/us/app/battle-chess-hd/id6538715222
- https://www.chess.com/forum/view/community/have-you-tried-battle-mode-animation-style
- https://www.chess.com/forum/view/general/battle-mode-animation
- https://store.steampowered.com/app/3509230/Gambonanza/
- https://www.commonsensemedia.org/app-reviews/chess-academy-for-kids-by-geek-kids
- https://play.google.com/store/apps/details?id=com.champions_chess_academy.shortcastle
- https://play.google.com/store/apps/details?id=com.kidchess.app.app
- https://play.google.com/store/apps/details?id=com.chesskids.shortcastle
- https://play.google.com/store/apps/details?id=com.altermanchess.AltermanChessEdu
- https://play.google.com/store/apps/details?id=com.chessmatemon

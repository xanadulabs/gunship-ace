# Gunship Ace: review and release plan

## Status: 2026-11-07, v1.0.0 build

| Phase | State |
|---|---|
| 0 Safety net | **Done.** Git, `v0.1-grok` tag, source art in `art/source/`, probe, screenshot tour |
| 1 Runs anywhere | **Done.** Imported textures, bundled font, stretch, Compatibility renderer, pause and quit, F11, export presets. The exported Linux build passes the probe. |
| 2 Fair and fun slice | **Done in code.** Safe LZ spawns, altitude-aware fire, structures block, graded wash, visible gunfire, fuel tuned, facings 1 and 5. **Not yet playtested by people.** |
| 3 Feels like Desert Strike | **Done.** Two schemes, rebinding, gamepad, three weapons with ammo, pickups, HUD, radar, synthesized audio, shake, smoke, scorch |
| 4 A game | **Done.** Four missions on 220–300 m maps, eight enemy types, rescue, lives, title, briefing, map, saved progress |
| 5 Release | **Builds ready** via `tools/build.sh`. **Left for you:** the hand checks in [docs/RELEASE.md](docs/RELEASE.md) (Windows and web were exported but not run here), playtests, the name check, and the itch.io upload, which needs your account. |

**v1.1.0 (same day):** the original v0.1 rules are the floor again. The original keys are the default and the arrow keys are off. The wash attacks only on the ground and only while still. Trucks shake and never tip. Health is 8 and a shot removes 2. The original gun slew rules and point values are back, empty fuel lands safely, and the plates use the original sentences. The weight link from "Next slice" is in. The probe checks every minimum (244 checks).

Design as built: [MODE_BIBLE.md](MODE_BIBLE.md). The review below is kept as written for the record.

---

Reviewed 2026-11-07 against the code in `game/`, the stills, and a scripted 12-second play run (screenshots in the review session).

## Verdict

The art pipeline and the look are much better than the rest. The painted, orthographic, earth-palette frame is close to the Desert Strike bar, and the rotor-wash flip is a good new hook. Everything around them is unfinished or broken. The game cannot be exported as it stands, the opening is unwinnable, and the whole outing lasts about a minute on a map that fits on one screen. It is a tech demo with a design document written as if the game were done.

Keep: the sprite look, `rules.gd` as pure functions, the headless `--probe` check, the camera, and the wash-flip idea.
Rework: the controls, enemy fire, the HUD, the outing length, and the map.
Missing entirely: a game loop (objectives, pickups, weapons, missions), audio, menus, and an export.

## What I saw in a scripted run

Inputs: hold W for 2 s, turn right, climb twice, click twice, descend twice.

| Time | What happened |
|---|---|
| 0–3 s | The Hind spawns about 5 m from a building, facing it. W moves her 5 m, then "A building stops the Hind." |
| 3 s | The jeep at (4, 10) is already inside its 10 m range of the spawn. Health 8 → 6. |
| 5.5 s | Health 4 while climbing. **Enemy fire ignores altitude.** |
| 7.6 s | Two clicks at two steps up give "The gun is turning." No hit. |
| 12 s | Health 0, "Hind down." Fuel 74. Vehicles left 5. |

A new player can die without ever finding the gun's sweet spot.

---

## Findings

### A. Release blockers (an exported build will not work)

1. **Sprites load from raw PNGs.** `Meshes.tex()` uses `Image.load("res://art/sprites/…png")`, and `world.gd` gates the rotor frames on `FileAccess.file_exists(…png)`. Exported builds ship only the imported `.ctex`, not the source PNGs, so every sprite will be missing and the spinning rotor will silently fall back. Fix: `load()` the textures, check them with `ResourceLoader.exists()`, and bake the gear offsets (`_body_shift_of` reads pixels at runtime) into `layout.json` at art-build time.
2. **`layout.json` will not be exported.** It is not a resource. Add it to the export include filter, or convert it to a `.tres`/`.gd` const.
3. **The font is a system path.** `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf` does not exist on Windows or macOS, or on many Linux installs. Bundle a font under `game/ui/`.
4. **Hard-coded home paths.** The capture writes to `/home/hierophant/…`, and `art/paint_look.py` reads source images from `~/.grok/sessions/…/images`. **The source art lives only in a Grok session cache.** If that cache is pruned, the sprites can never be rebuilt.
5. **No stretch mode.** The window is fixed at 1600×900 and the HUD is in absolute pixels. Fullscreen, 1080p, 4K, and Steam Deck will all look wrong.
6. **No export preset, no Esc, no pause, no quit, no title screen.**
7. **No version control.** The folder is not a git repo, even though `.gitignore` exists.

### B. Gameplay bugs

1. **The spawn is a trap.** It faces a building 5 m away and sits inside a jeep's firing range (`map.gd: start()`).
2. **Enemy fire is flat 2D.** `_enemy_shots` and `_tick_bullets` measure XZ distance only, so altitude gives no protection. Altitude should be the core risk trade: low means wash and the gun but you get shot, high means safer but no wash.
3. **Vehicles drive through buildings and trees.** The props are sprites and blocker rectangles that only the Hind checks. The physics world has just the ground and four walls.
4. **The outing is about 66 s long.** 100 fuel at 1.5/s, with no refuel. You cannot finish the slice even when you play well.
5. **Facings 1 and 5 are copies of 2 and 4** (`install_hind_d.py: COPY`). Flying straight up or down the screen shows the nose pointing diagonally.
6. **The gun gives poor feedback.** It is an auto-lock hitscan with a 0.12 s tracer, and it says "The gun is turning." on almost every click. There is no stream of fire, no muzzle flash, and no hit flash.
7. **The wash is binary.** A flat 16000 torque applies anywhere inside 7 m, with no falloff. It also only works when you are landed and fully stopped, which is the exact moment you are easiest to hit.
8. **The map is 56 m square.** At top altitude the whole map and the blue void around it are on screen. At ground level the void shows at the edges.
9. **`vehicle.gd` defines `func ready()`.** That shadows Node's `ready` signal. Rename it to `can_fire()`.

### C. Gaps against Desert Strike

What makes Desert Strike work, and what this build has of it:

| Desert Strike | Gunship Ace now |
|---|---|
| Large scrolling map you explore | One 56 m screen |
| Several objectives per mission (radar, AAA, convoys, rescues) | Kill 5 vehicles |
| Fuel, ammo, and armor pickups drive routing decisions | None. Fuel only drains. |
| Three weapons (gun, Hydras, Hellfires) with ammo | One auto-aim gun, unlimited |
| Enemy tiers (infantry, AAA, ZSU, SAMs, tanks) | Jeep, technical, truck |
| Winch rescue and drop-off at an LZ | None |
| Map/status screen, briefing, lives, passwords | None |
| Simple controls: rotate + thrust on a d-pad, 3 buttons | 9 keys + mouse, arrows banned, no gamepad |
| Sound and music carry the feel | Silent |

The HUD covers about 40% of the screen with two permanent plates of tutorial text. It needs to be compact gauges, plus a controls card on F1 or on first launch.

### D. Code and process

- `meshes.gd` has about 250 lines of dead box-mesh models (`hind()`, `jeep()`, `tree()`, `building()`, `dust_ring()`, `_ground_material()`). The `rotor` sprite and the `sun` light are created and never used. `gun_pick`, `destination`, `action_key`, and `wash_scale` are only called by the probe.
- `world.gd` is an 821-line god object. State is string-typed (`"play"`, `"attack"`) and entities are Dictionaries. That is workable for a slice, but it needs splitting before more content goes in: Hind, Weapons, EnemyManager, HUD.
- Input uses hard-coded `keycode`s instead of an InputMap. That means no remapping, no gamepad, and the wrong layout on AZERTY.
- `MODE_BIBLE.md` locked a lot of placeholder decisions as if they were final: arrows banned, wash only on the ground, three fixed heights, one outing. Its clipped sentence style also leaked into the UI ("Height is two steps up."). Treat the bible as v0.1 notes, not law.

---

## The plan

Each phase has an exit test. Do not start the next phase until the test passes. That is the hand-holding Grok needs, written down once.

### Phase 0: Safety net (½ day)

- `git init`, then commit the current state as `v0.1-grok`.
- Copy the source images Grok generated from `~/.grok/sessions/…/images` into `art/source/`. Point `paint_look.py` and `install_hind_d.py` at that folder.
- Add a **scripted playthrough check** next to `--probe`: `--drive` feeds inputs, saves screenshots, and prints state. Every change must pass `--probe` and produce screenshots that a human looks at.
- **Exit:** a clean checkout rebuilds the sprites and passes `--probe`.

### Phase 1: Runs anywhere (1–2 days)

- Replace `Image.load`/`FileAccess.file_exists` with imported textures. Bake the gear offsets and the layout into a resource.
- Bundle a font (OFL licensed). Remove every absolute path.
- Stretch mode `canvas_items`, aspect `expand`, base 1600×900 (or 1280×720). Rebuild the HUD with anchors.
- **Switch to the Compatibility renderer.** Everything is unshaded sprites, so Forward+ buys nothing. Compatibility runs on weak GPUs and Steam Deck, and it is required for a web build on itch.io.
- Esc pause menu (Resume, Restart, Quit), F11 for fullscreen.
- Export presets for Linux, Windows, and Web.
- **Exit:** the Windows build runs in one of your VirtualBox VMs and the web build runs in a browser, with every sprite showing and the rotor spinning.

### Phase 2: The current slice is fair and fun (2–3 days)

- Move the spawn to a clear LZ that is out of enemy range.
- Make enemy fire altitude-aware. Small arms hit at ground level and one step up, and miss at two steps up. That makes height a real choice.
- Give buildings and trees StaticBody colliders so vehicles respect them. Route the patrols along the tracks.
- Make the wash work at ground level **and** one step up, scaling with distance and height, and allow it while moving slowly. Flips build up over about 0.5–1 s, so you have to commit.
- Gun: hold to fire a stream of visible rounds in a forward cone with mild aim assist, plus a muzzle flash, hit flash, and screen shake. Drop the "turning" notice.
- Tune fuel so a good run takes about 3–4 minutes. Add 2 fuel drums and 1 armor crate to the map.
- Paint real facings 1 and 5 for the Hind.
- Clean up: delete the dead mesh code, rename `ready()`, and split `world.gd`.
- **Exit:** three people who have never seen it can each win within 3 tries, and each says the flip felt good.

### Phase 3: It feels like Desert Strike (1–2 weeks)

- **Controls:** InputMap with WASD **and** arrows **and** gamepad. Offer two schemes. "Classic" is rotate + thrust, like Desert Strike. "Modern" is the current strafe scheme. Rebinding goes in the options menu.
- **Weapons:** gun (lots of ammo), rockets (medium), and an ATGM, the Hind's Shturm (few, homing, for armor). Each has its own ammo count.
- **Pickups:** fuel, ammo, and armor, some hidden under destructible buildings, as in Desert Strike.
- **HUD:** fuel, armor, and ammo bars in a corner, a small radar or minimap, and objective arrows.
- **Audio:** rotor loop pitched by speed, gun, rockets, explosions, and a music track. Freesound/Kenney CC0 is fine to start.
- **Juice:** damage smoke on the Hind below 50% armor, debris, a crash animation, and burning wrecks.
- **Exit:** a 5-minute session holds up when played on a gamepad from the couch.

### Phase 4: It is a game (3–6 weeks)

- **Map:** grow to about 300×300 m. Use a tiled or chunked ground, not one 1200 px texture, with ground detail and painted cliffs or rivers at the edges instead of a void.
- **Enemies:** infantry, AAA (hits you low), ZSU (hits you at any height), SAM site (hits you high and forces you low), light tank (wash-immune, needs an ATGM). That gives the three heights a real rock-paper-scissors.
- **Missions:** 4–6 missions, each with 3–5 objectives. Examples: destroy the radar, flip the convoy before it reaches the depot, winch the downed pilot and return to the LZ, capture the commander. The wash flip should be the star verb in at least one objective per mission.
- **Structure:** title screen, briefing screen, map/status screen (Tab), 3 lives per mission, save progress between missions.
- **Exit:** a full campaign can be played start to finish with no dev-only keys.

### Phase 5: Release (1–2 weeks, overlaps Phase 4)

- **First, a free itch.io demo** of the Phase 3 build (web, Windows, Linux). Gather feedback before building the campaign.
- Settings: volume sliders, key rebinding, fullscreen, and a screen-shake toggle.
- Write credits and licenses, covering the font, the sounds, and the provenance of the AI-generated art. Note that Steam requires an AI-content disclosure.
- Store page: 5 screenshots, a 30 s GIF of a flip, and a short pitch. Name check "Gunship Ace" for conflicts before buying anything.
- **Then** decide between Steam (US$100 fee, Steam Deck verified is a good fit) and an itch.io paid release.

---

## How to keep Grok on track

- Give it **one phase item at a time**, with the exit test pasted in.
- Require `--probe` plus the screenshot run after every change, and look at the screenshots yourself.
- Ban absolute paths and `Image.load("res://…")` in writing. They are its favorite mistakes here.
- Do not let it edit `MODE_BIBLE.md` to declare things "locked". You own design decisions. It owns implementation.

## Decisions that are yours

1. **Controls default:** classic rotate + thrust (Desert Strike), or keep the current strafe scheme? My recommendation: ship both, with classic as the default on gamepad.
2. **Relax the bible's wash rule** (ground and still only)? My recommendation: yes, as in Phase 2.
3. **Release target:** free itch demo first (recommended), or straight to a paid Steam release?
4. **Who builds it:** Grok with this plan as the leash, or me (Claude) on some or all of it?

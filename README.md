# Gunship Ace

A top-down attack-helicopter game in the spirit of the early-90s strike games. You fly one Mi-24 Hind through a four-mission campaign. The rotor wash is a weapon: come down to the ground, hold still beside a jeep or a technical, and it flips. Godot 4.7.1, Compatibility renderer.

Design, with the original minimums at the top: [MODE_BIBLE.md](MODE_BIBLE.md). Status and what is left before release: [PLAN.md](PLAN.md). Release steps: [docs/RELEASE.md](docs/RELEASE.md).

## Play

```
~/bin/godot --path game
```

| Action | Keys | Gamepad |
|---|---|---|
| Move forward / left / back / right | W A S D | Left stick |
| Turn left / right | Q E | Right stick |
| Up / down one step | R F | RB / LB |
| Chin gun | Left click (or Space) | A, RT |
| Rockets | Right click (or K) | X, LT |
| Guided missile | Middle click (or L) | Y |
| Map and objectives | Tab, M | Back |
| Pause | Esc, P | Start |
| Show or hide the key list | F1 | |
| Fullscreen | F11 | |

These are the original design keys and they are the default. The arrow keys do not move her. Options has an alternate scheme (A/D turn, Q/E slide), and every key can be rebound.

## Check and build

```
~/bin/godot --headless --path game -- --probe      # 244 rule, data, art and simulation checks
~/bin/godot --headless --path game -- --balance    # health loss in hot spots, for tuning
~/bin/godot --path game -- --shots /tmp/shots      # scripted screenshot tour of every screen
tools/build.sh                                     # probe, export Linux/Windows/Web, self-test the export, zip
```

`tools/build.sh` writes `build/GunshipAce-<version>-{linux,windows,web}.zip`. Each zip includes the player README and the Godot and font license notices.

## Layout

```
game/
  core/       rules.gd (every number and pure rule), missions.gd (campaign data),
              settings, controls (input map, schemes, rebinding), sfx, game (screen flow), art
  world/      world.gd (mission runtime), hind.gd, unit.gd (all enemies and structures), ground.gd (shader floor)
  ui/         hud, minimap, title, briefing, mission (pause and map), result, options, theme, fonts
  test/       probe.gd, balance.gd, shots.gd
  art/        sprites/ (imported PNGs) and the Python painters that make them
  audio/      synthesized WAVs and make_audio.py
art/source/   the original painted source images (keep these: the sprites are built from them)
tools/        build.sh
```

## Art and audio pipelines

* `game/art/install_hind_d.py` and `spin_blades.py` cut the Hind facings and the spinning-rotor frames from `art/source/`.
* `game/art/paint_look.py` cut the jeep, technical, truck, buildings, trees and ground from `art/source/`.
* `game/art/bake_units.py` paints the campaign units (tank, ZSU, AA gun, SAM, radar, soldiers, crew, pickups, wrecks, effects) with the same camera and palette. Run it with plain `python3`.
* `game/audio/make_audio.py` synthesizes every sound effect and both music loops. No samples.

After changing art or audio, run `~/bin/godot --headless --path game --import`.

All rights reserved by the author unless a license is added.

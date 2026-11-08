# Releasing Gunship Ace

## 1. Build

```
tools/build.sh
```

This produces `build/GunshipAce-1.1.0-linux.zip`, `-windows.zip` and `-web.zip`. The script stops if the probe fails, either on the project or inside the exported Linux binary. Store screenshots come from `~/bin/godot --path game -- --shots build/screenshots`.

## 2. Check by hand before uploading

These have not been checked by a person yet:

- [ ] **Windows:** unzip on a real Windows PC. Play the first mission, and check that sound plays and that progress and options persist after a restart. They are saved in `%APPDATA%\Godot\app_userdata\Gunship Ace`. SmartScreen will warn because the exe is unsigned; that is normal for itch games.
- [ ] **Web:** upload as a draft to itch, open it in Chrome and Firefox, and play for two minutes. Audio starts after the first click, which is browser policy.
- [ ] **Gamepad:** fly a mission with an Xbox-style controller.
- [ ] **Playtest:** three people who have not seen the game. Each should finish mission 1 within three tries. Note where they get stuck. The `--balance` report and `core/rules.gd` are where you tune.
- [ ] **Name check:** search "Gunship Ace" on itch.io, Steam and the app stores, plus a USPTO trademark search, before buying anything with the name on it.

## 3. itch.io

1. Create the project at itch.io/game/new.
   * Kind: **Downloadable**, plus an **HTML** upload for the web zip. Tick "This file will be played in the browser" and set the viewport to 1280×720 with the fullscreen button on.
   * Pricing: free, or pay-what-you-want with a $0 minimum, for the first release. It buys feedback.
2. Upload the zips by hand, or with butler:
   ```
   butler push build/GunshipAce-1.1.0-linux.zip   <you>/gunship-ace:linux   --userversion 1.1.0
   butler push build/GunshipAce-1.1.0-windows.zip <you>/gunship-ace:windows --userversion 1.1.0
   butler push build/GunshipAce-1.1.0-web.zip     <you>/gunship-ace:html5   --userversion 1.1.0
   ```
3. Page copy (draft):

   > **Gunship Ace**: *Fly low. Flip jeeps. Bring the crews home.*
   >
   > A top-down attack-helicopter game in the spirit of the early-90s strike games. Fly a Mi-24 Hind through four missions: knock out the radar, stop a supply convoy, rescue downed crew under SAM cover, and take the militia command post.
   >
   > Your rotor wash is a weapon. Come down to the ground, hold still beside a jeep, and the downwash flips it. But down low, everything can shoot you. Climb and the rifles cannot reach you, but the SAMs can.
   >
   > * 4 missions, each with several objectives, plus lives, fuel and ammo pickups
   > * Chin gun, rocket pods and guided missiles
   > * Three flight heights that change what can hit you
   > * Keyboard, mouse or gamepad, with rebindable keys
   > * Windows, Linux and in-browser

   Tags: `helicopter`, `top-down`, `shoot-em-up`, `retro`, `pixel-art`, `arcade`, `military`.
   Screenshots: `06_m1_flipped`, `07_m1_rockets_high`, `15_m2_convoy`, `13_m4_compound`, `12_m3_winch`, `09_m1_map`.
4. **AI disclosure.** The painted sprite sources were generated with AI image tools and then processed. itch.io asks you to tag this ("AI generated: graphics"). Say so on the page. The code, synthesized audio and music were not made from samples.

## 4. Later: Steam

* Steamworks costs US$100 per app, and there is a 30-day wait before the first release.
* The Linux build runs on Steam Deck. The gamepad layout and the 16:9 / 16:10 scaling are already in.
* Steam requires the same AI-content disclosure in the content survey.
* Add a macOS export only with an Apple developer account ($99 a year) for signing and notarization. Unsigned Mac builds are blocked by Gatekeeper.

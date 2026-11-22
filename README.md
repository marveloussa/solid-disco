# Iron Temple

First-person stylized Gym & MMA progression game for **Godot 4.4+** (Forward+ renderer; tested on 4.4.1 and 4.7.2).

**All five steps are in**, and the game is complete: the intro street and a rideable bicycle, a three-storey
gym, first-floor training with stats, levelling, visible muscle growth, a pump multiplier and injuries,
second-floor MMA with first-person striking, heavy bags, a five-fighter ladder and an endless league, a
living gym (regulars who react to your reputation, a supplement bar on the third floor, synthesized sound
and music, saving, a pause menu and particle effects), and fast, technical fights: head and body targeting,
two guards, feints, intercept counters, a chin gauge with knockdowns, the clinch and five opponent styles.
Everything is built from Godot's primitive meshes and `StandardMaterial3D`, and every sound is synthesized
in code, so there are no imported assets of any kind: open `project.godot` in the editor and press **F5**.

## Controls

| Input | On foot | On the bike |
| --- | --- | --- |
| `W` `A` `S` `D` | Move | Accelerate, brake/reverse, steer |
| Mouse | Look | Look around (the bike keeps its heading) |
| `Shift` | Sprint (uses stamina) | Sprint pedalling (uses stamina) |
| `Space` | Jump | |
| `E` | Interact with what the crosshair points at | Dismount (prompt shows at walking pace) |
| `Esc` | Pause menu (leaves a station; in a fight it only frees the mouse, click to take it back) | Pause menu |
| `M` | Mute or unmute the gym speakers | |

The ride from the house to the gym is about 250 m: roughly 18 s sprinting, about 40 s at cruising speed.

### Workout stations

Press `E` on a piece of equipment to use it; the camera eases into position and the mouse still turns your head.
`E` or `Esc` hands control back.

| Station | Controls | Trains |
| --- | --- | --- |
| Warm-up mat | Hold `LMB`/`Space`, release inside the drifting zone. `A`/`D` switches between stretch and push-ups | Stretch: "Warmed Up" for 5 minutes, heals strains faster. Push-ups: torso, arms, max stamina |
| Bench press, squat rack, deadlift | Racked: `A`/`D` or mouse wheel changes the load (20 to 400 kg), `LMB`/`Space` lifts the bar off. Lifting: hold to press, release to lower, tap `A`/`D` to keep the balance gauge centred. `E` racks the bar | Bench: torso, arms. Squat: legs, torso. Deadlift: legs, torso, arms. All: strength |
| Dumbbell bench or rack | `LMB` curls the left arm, `RMB` the right. Alternate in a steady rhythm | Arms, a little strength |
| Treadmill | `W`/`S` sets the belt speed. Above 7 km/h is training pace, below is recovery | Legs, max stamina |

The load is changed with `A`/`D` rather than `Q`/`E`, because `E` leaves the station.

### Fighting (2F)

Walk up to a heavy bag or into the cage and the hands come up with the gloves on. Use the
**Fight Card** terminal beside the cage (`E`) to pick an opponent.

| Input | Action |
| --- | --- |
| `LMB` | Left jab to the head. A second `LMB` straight after a jab is a left hook |
| `RMB` | Right cross to the head. A second `RMB` straight after a cross is a right overhand |
| `Ctrl` (or `C`) + `LMB` / `RMB` | Body shots: liver hook and body cross. Less damage, but they drain the opponent's stamina |
| `F` / middle mouse | Front push kick to the body; a knee when chest to chest. Pushes back and drains stamina |
| `Shift`, or `LMB` + `RMB` held together | High guard: stops head shots for 80% less damage, costs stamina. The body is open |
| `Ctrl` + `Shift` | Body guard: stops body shots the same way. The head is open |
| Tap `Shift` within 0.15 s of starting a punch | Feint: the punch is pulled back and its stamina refunded |
| `A` / `D` / `S` + `Space` | Slip left, right or back (`Space` alone slips back) |
| `Space` / `F` in a clinch | Break the grip: mash, or time one press with the knee coming up |
| `E` at the terminal | Fight Card / Enter Ring |

| Combo | Buttons | Effect |
| --- | --- | --- |
| 1-2 Combo | `LMB` `RMB` | Cross lands for x1.5 |
| Guard Breaker | `LMB` `LMB` `RMB` | Jab, hook, uppercut: shatters a raised guard and staggers |
| KO Finisher | `RMB` `LMB` `RMB` | Cross, jab, overhand for x2 with heavy knockback and a stagger |

Presses chain when they are less than 0.9 s apart; a whiff or taking a clean hit breaks the chain. Body
shots chain like any other press, but only head shots complete the named combos.

| Technique | How | Reward |
| --- | --- | --- |
| Intercept counter | Land a clean punch while the opponent is still winding up | x2.5 damage, his attack is cancelled, a heavy jolt to his chin |
| Perfect counter | Slip within 0.22 s of a strike landing; time slows for a quarter of a second | The next strike does x2 and staggers |
| Level change | A head shot within 1.2 s of a clean body shot | x1.2 damage and x1.6 on his chin gauge |
| Feint | Tap `Shift` as the punch starts | An opponent who bites is stuck with his guard or slip for 0.55 s |
| Punish | Hit a staggered or rocked opponent | x1.25 damage |

Bonuses never stack: the biggest one that applies is the one that counts.

### Supplement bar (3F)

Aim at the bar counter or the bartender and press `E` to open the shop. Each item is drunk the moment it is
bought; `E` or `Esc` closes the shop.

| Item | Price | Effect |
| --- | --- | --- |
| Isotonic Water | $15 | Stamina back to 100%, and an active injury heals in half the time left |
| Whey Protein Shake | $40 | x2 Muscle and XP from every workout rep for 3 minutes |
| Hardcore Pre-Workout | $75 | Stamina regenerates 3.5x as fast, +20% punch speed and lifting power, for 2 minutes |
| Recovery Elixir | $60 | Heals a Strained muscle at once (only sold when you are strained) |

Active buffs show as countdown badges under the profile panel; pre-workout also pulses a faint purple
vignette and makes the forearms steam.

## How progression works

- **Reps pay out** muscle, strength and XP through `PlayerStats.reward_rep()`. Gains scale with the load
  relative to your strength, so light bars build little.
- **Pump** rises with every rep (double for a perfect one), multiplies muscle and XP gains up to x2.5, makes
  every rep cost more stamina and decays after three idle seconds.
- **Perfect reps**: on a barbell, keep the balance marker inside the zone and move the bar without stalling
  or reversing. On curls, alternate arms in tempo. On the mat, release near the centre of the zone.
- **Injury**: each load needs `weight / factor` strength (factor 1.0 bench, 1.25 squat, 1.5 deadlift).
  Above that the strain bar fills while you push, five times slower when warmed up and faster when out
  of stamina. A full strain bar drops the bar and strains a muscle; so does losing balance under a load a
  quarter over your limit, unless you are warmed up and lucky. A strain means camera shake, a red vignette
  and 45 to 60 seconds of slower lifts with 40% less usable strength. Standing still, sitting at a racked
  bar or stretching heals it twice as fast.
- **Levels and ranks**: XP needed per level is `50 * level^1.3`. Titles unlock at levels 1, 3, 6, 9, 13
  and 17 (Skinny Rookie, Gym Regular, Lean Grinder, Shredded Prospect, Cage Ready, Iron Machine), then
  gain a numeral every five levels. One day of gym tenure passes per 45 seconds at a station.
- **Body**: `MuscleArms`, `MuscleTorso` and `MuscleLegs` run 0 to 100 with diminishing returns and drive
  the first-person arms and the mirrored body separately.

## How fighting works

- **Stats carry upstairs.** `Strength` and `MuscleArms` scale punch damage and how fast a guard breaks;
  `MuscleLegs` scales kicks, slip speed and footwork; level, `MuscleTorso` and `MaxStamina` set the health
  bar for a bout (100 for a rookie).
- **Stamina gates everything.** Every strike, slip and second behind the guard costs stamina. Run dry and
  punches come out at 60% speed and 55% power, and the guard drops until a quarter of the bar is back.
- **Strained** fighters (Step 2's injury) hit 40% weaker and 28% slower until the strain heals; the combat
  HUD says so.
- **Heavy bags** take any strike and combo, swing as damped pendulums and pay a little XP, arm or leg
  muscle and max stamina per clean hit. No sign-up needed: just walk up.
- **Opponents telegraph.** Every attack pulls the arm or knee back, pops a `!` over the head (yellow for a
  light strike, red `!!` for a heavy one) and makes the glove glow for the whole wind-up, never shorter
  than 0.28 s. Block it, slip it, or step out of range. A whiffed strike leaves a long recovery.
- **The ladder**: Skinny Sam (Lvl 1), Cardio Carl (Lvl 3), Brawler Boris (Lvl 6), Counter-King Viktor
  (Lvl 10), The Iron Champ (Lvl 15, Gym Boss). Each body matches the tier and each fights differently:
  Sam jabs and backs off, Carl bounces and throws jabs in bunches, Boris walks forward behind heavy hooks
  with slow recoveries, Viktor sits behind a high guard and counters a second blocked punch, the Champ
  feints and mixes everything.
- **Endless Championship League** opens when the Champ falls: a seeded challenger for every level from
  16 up, with a random name, build, colours and one of four styles, and health, damage and purse that
  keep growing.
- **Winning** pays the purse (plus win-streak, flawless and perfect-counter bonuses), large XP and three
  days of tenure, and unlocks the next fighter. Beating someone again pays half. **Losing** pays 15% of the
  XP and one day, and you walk out of the cage free to train and rematch.
- **Feel**: 30 to 60 ms of hit-stop on heavy, combo and counter hits, a directional camera punch, shake, a
  red vignette when hit, floating callouts (`COUNTER x2!`, `GUARD BREAK!`, `KNOCKOUT!`), staggers and a
  slow-motion knockdown.

## The living gym

- **Thirteen regulars** train across the three storeys, plus Joe behind the bar. On the first floor two
  work dumbbells by the mirror, one squats and one stretches; on the second one works a heavy bag (it
  swings, and pays you nothing), one does push-ups and two watch the cage; on the third three stand at the
  bar and the high tables with a shaker; two more walk a lap between the lobby and the bar, up and down both
  flights of stairs. Each has a name tag: `Mike | LVL 4 | 3 Months`.
- **Reputation** follows your level. Walk within a few metres and the nearest regular who has not spoken
  lately comments, and what they say also depends on your arm and torso muscle, your pump and your record.
  - *Levels 1 to 3:* teasing, and only some of the time. "Careful with that bar, stickman!", "First day, huh?"
  - *Levels 4 to 9:* a nod and respect. "Solid pump!", "Nice form, bro.", "Saw your last bout!"
  - *Level 10 and up:* hype. "Make way for the Machine!", "Absolute beast!", "Legend of the gym!" Regulars
    also step out of your way when you walk close, and come to the cage for your fights.
- **The crowd.** The ringside pair watch every bout. From level 10 a further `3 + (level - 10) / 2 +
  win streak` regulars (nine at most) jog to the cage when a bout starts, those from other storeys coming
  up the stairs, and stand around it until you leave. They throw their arms up and roar on heavy clean
  hits, guard breaks and knockouts, louder the more of them there are.
- A walker stops for you if you stand in the way. Regulars are solid: walk around them, unless you are a
  legend.

## Sound and music

There are no audio files. `AudioManager` synthesizes nineteen effects and a four-bar beat on a worker thread
at start-up (about half a second) from sine and triangle pitch drops, filtered noise bursts and ringing
partials, and plays them through two `AudioStreamGenerator` streams.

- **Gym:** plate clanks when a bar is lifted off, racked or dropped, a click per plate when changing the
  load, a tick per rep (two notes for a perfect rep), a crunch and warning buzz on injury and overload, a
  gulp at the bar, a chime on level-up.
- **Fights:** low thuds for hits (deeper and saturated for heavy ones), a sharp snap on counters and guard
  breaks, a muffled impact on blocks, a whoosh on misses and slips, a bass drop as slow motion starts,
  countdown beeps, the ring bell at "FIGHT!" and three strokes at the end, crowd roars.
- **Speakers:** a 128 BPM phonk-style loop (808 kick and sliding sub-bass, claps, hats, a pulsing synth, a
  quiet cowbell line, all low-passed) plays softly inside the gym, leaks faintly through the walls and
  fades out on the street. `M` or the pause menu mutes it.

## Saving and the pause menu

- The career is saved to `user://gym_mma_save.json` after every workout session, fight and bar purchase,
  from the pause menu, and when the window closes. It holds Level, XP, Cash, Strength, MaxStamina, the
  three muscle groups, the FightRecord, GymTenure, ladder and league progress (with the unlocked Endless
  League flag) and the settings. Buffs, pump and injuries are not kept.
- A saved career loads on start-up. Once you have reached the gym, later sessions start at its door
  instead of at the house.
- **Pause menu** (`Esc` on foot or on the bike): Resume, Save Game, Mouse Sensitivity (0.3x to 3x), gym
  speakers and sound effects on or off, Reset Career (asks first, keeps the settings, restarts at the
  house) and Save and Quit.

Fight tuning lives in `MOVES` and the constants at the top of `scripts/combat/combat_controller.gd`,
`MOVES` in `scripts/combat/enemy_fighter.gd` and the fighter definitions in
`scripts/combat/fighter_roster.gd`.

Tuning lives in the constants at the top of `scripts/autoload/player_stats.gd`. A scripted player doing
warm-up, bench, squat, curls, deadlift and treadmill circuits reaches 85 to 90 out of 100 in every muscle
group after about 18 minutes and 100 after about 28. A person plays less efficiently than the script.

## Scene tree

`scenes/main.tscn`

```
Main (Node3D)                              scripts/main.gd
├── WorldEnvironment                       sky, ambient, glow, SSAO, fog
├── Sun (DirectionalLight3D)               soft shadows
├── Neighborhood (Node3D)                  scripts/world/neighborhood.gd
├── Gym (Node3D)                           scripts/world/gym.gd
│   ├── Floor1_WeightRoom (Node3D)         scripts/world/gym_floor_weights.gd
│   │   └── MirrorWall                     instance of scenes/world/mirror.tscn
│   ├── Floor2_FightHall (Node3D)          scripts/world/gym_floor_mma.gd
│   └── Floor3_Lounge (Node3D)             scripts/world/gym_floor_lounge.gd
├── GymBeacon (Node3D)                     scripts/world/beacon.gd
├── Bicycle                                instance of scenes/vehicles/bicycle.tscn
├── Player                                 instance of scenes/player/player.tscn
└── HUD                                    instance of scenes/ui/hud.tscn
```

### Added in Step 2

Autoloads (Project Settings, Autoload):

```
GameState      res://scripts/autoload/game_state.gd      objective and toast messages only
PlayerStats    res://scripts/autoload/player_stats.gd    new: every stat, timer and signal
```

Input Map: `lift` (Space, left mouse), `curl_left` (left mouse), `curl_right` (right mouse).
Physics layer 4 is "Interactables": aimed at by the interact ray, never collided with.

Workout stations are created by `Floor1_WeightRoom` at runtime, one node per piece of equipment:

```
Floor1_WeightRoom
├── BenchPress x3, SquatRack x2, Deadlift  (BarbellStation)   scripts/workouts/barbell_station.gd
│   ├── Body (StaticBody3D) → Interactable
│   └── Barbell (Barbell)                                      scripts/workouts/barbell.gd
├── DumbbellCurls x3                       (CurlStation)       scripts/workouts/curl_station.gd
├── Treadmill x5                           (TreadmillStation)  scripts/workouts/treadmill_station.gd
└── WarmUp x3                              (WarmupStation)     scripts/workouts/warmup_station.gd
```

`scenes/player/player.tscn`: the `Stamina` node is gone (stamina lives in `PlayerStats`) and `InteractRay`
also scans layer 4.

`scenes/world/mirror.tscn`: new `NameTag (Label3D)` showing rank, days and level above the reflection.

`scenes/ui/hud.tscn`

```
HUD (CanvasLayer)                          scripts/ui/hud.gd
└── Root (Control)
    ├── Vignette (ColorRect)                                   new: red injury flash
    ├── LeftColumn (VBoxContainer)
    │   ├── ProfilePanel (PanelContainer) → VBox
    │   │   ├── Header: LevelBadge → LevelLabel, RankLabel
    │   │   ├── XPRow: XPCaption, XPBar, XPLabel               new
    │   │   ├── StaminaRow: StaminaCaption, StaminaBar
    │   │   └── PumpRow: PumpCaption, PumpBar, PumpLabel       new
    │   ├── StatusRow (HBoxContainer)                          new
    │   │   ├── WarmupBadge → WarmupLabel
    │   │   └── InjuryBadge → InjuryLabel
    │   └── ObjectiveLabel
    ├── Crosshair, PromptAnchor → Prompt, ToastLabel, ControlsHint, Waypoint
    ├── WorkoutOverlay                                         new: instance of scenes/ui/workout_overlay.tscn
    └── Popups (Control)                                       new: floating "+Arms", "PERFECT REP!"
```

`scenes/ui/workout_overlay.tscn` (rows appear only while a station uses them)

```
WorkoutOverlay (Control)                   scripts/ui/workout_overlay.gd
├── Danger (Label)                         flashing overload warning
└── Dock (VBoxContainer) → Panel (PanelContainer) → Rows (VBoxContainer)
    ├── Header: Title, Counter
    ├── Selector: PrevKey, SelectorValue, NextKey             weight or exercise
    ├── SelectorDetail
    ├── BalanceRow: BalanceCaption, Balance (GaugeBar)
    ├── RhythmRow: RhythmCaption, Rhythm (GaugeBar)
    ├── ArmsRow: LeftBox → LeftArm (GaugeBar), RightBox → RightArm (GaugeBar)
    ├── SpeedRow: SpeedCaption, Speed (GaugeBar)
    ├── StrainRow: StrainCaption, Strain (GaugeBar)
    └── Hint
```

Other scenes are unchanged from Step 1: `player.tscn` (CollisionShape3D, Head → Camera3D → InteractRay and
Arms, Model), `bicycle.tscn` (FrameCollision, RiderCollision, Interactable, Model) and `mirror.tscn`
(SubViewport → MirrorCamera, Surface).

### Added in Step 3

Input Map: `strike_left` (left mouse), `strike_right` (right mouse), `kick` (F, middle mouse), `block`
(Shift), `dodge` (Space).

`scenes/player/player.tscn`

```
Player (CharacterBody3D)                   scripts/player/player.gd
├── CollisionShape3D, Head → Camera3D → InteractRay, Arms, Model
└── Combat (Node)                          new: scripts/combat/combat_controller.gd
    └── TimeFx (Node)                      new: scripts/combat/time_fx.gd (hit-stop, slow motion)
```

`Arms` gains the gloves, the guard, punch paths and a kicking leg; `Model` gains a fight layer and gloves.

`scenes/ui/hud.tscn`

```
HUD (CanvasLayer)
└── Root (Control)
    ├── LeftColumn → ProfilePanel → VBox
    │   └── FightRow: CashCaption, CashLabel, RecordCaption, RecordLabel   new
    ├── CombatHUD                          new: instance of scenes/ui/combat_hud.tscn
    ├── Popups
    └── FightCard                          new: instance of scenes/ui/fight_card.tscn
```

`scenes/ui/combat_hud.tscn` and `scenes/ui/fight_card.tscn` are a root `Control` with a script; the scripts
build their panels in `_ready()` from `UiKit`:

```
CombatHUD (Control)                        scripts/ui/combat_hud.gd
├── OpponentPanel                          name, LVL | rank | tenure, health, guard, stamina
├── PlayerPanel                            health, stamina, strained / gassed line
├── Streak, ComboName                      hit counter, "GUARD BREAKER"
├── Count, Counter                         "3 2 1 FIGHT!", "COUNTER!" and the screen flash
├── Hint                                   fight controls
└── Result                                 VICTORY / DEFEAT, reward rows, Next Fight / Rematch / Exit Ring

FightCard (Control)                        scripts/ui/fight_card.gd
└── dimmer + panel: header and record, fighter list, detail pane, Close / Enter Ring
```

New scenes, instanced at runtime:

```
scenes/combat/punching_bag.tscn
PunchingBag (Node3D)                       scripts/combat/punching_bag.gd
├── Pivot → Bag                            built in _ready(): bag, straps, chain; swings
├── Body (StaticBody3D)
├── Hurtbox (CombatTarget)                 scripts/combat/combat_target.gd
└── Zone (CombatZone)                      scripts/combat/combat_zone.gd

scenes/combat/enemy_fighter.tscn
EnemyFighter (CharacterBody3D)             scripts/combat/enemy_fighter.gd
├── CollisionShape3D
├── Model (CharacterModel)                 render layer 1, shaped and coloured by the FighterProfile
├── Hurtbox (CombatTarget)
├── NameTag (Label3D, billboard)           "SKINNY SAM / LVL 1 | Skinny Rookie | First Week"
└── Telegraph (Label3D, billboard)         the "!" wind-up cue
```

`Floor2_FightHall` creates the fight content at runtime, the same way the weight room creates its stations:

```
Floor2_FightHall                           scripts/world/gym_floor_mma.gd
├── HeavyBag1 … HeavyBag5                  instances of scenes/combat/punching_bag.tscn
└── RingManager (Node3D)                   scripts/combat/ring_manager.gd, at the octagon's centre
    ├── Zone (CombatZone)                  hands up inside the cage
    ├── Gate + GateBlocker                 swings shut and locks for the bout
    ├── FightCardTerminal (Node3D)         scripts/combat/fight_card_terminal.gd → Body → Interactable
    └── EnemyFighter                       spawned per bout from enemy_fighter.tscn
```

To place any of these by hand instead, instance the scene (or add a `Node3D` with the script) and set its
exports: `PunchingBag.mount_height`, `RingManager.arena_radius`, `platform_height`, `gate_distance`.

`scenes/world/mirror.tscn`: `NameTag` now shows the overhead tag, `LVL 7 | Shredded Prospect | 14 Days`, above
the player's reflection. It is drawn in front of the glass on the sight line to the reflected head, so it
reads the right way round.

Scripts that build geometry add their meshes, colliders and lights as children at runtime, so the street,
the gym and the equipment are visible when the game runs, not in the editor viewport.

### Added in Step 4

Autoloads (Project Settings, Autoload), after the existing two:

```
AudioManager   res://scripts/autoload/audio_manager.gd   procedural sound effects and the gym beat
SaveManager    res://scripts/autoload/save_manager.gd    JSON save, load, settings, career reset
```

Input Map: `toggle_music` (M).

`scenes/main.tscn`

```
Main
└── Gym
    ├── Floor1_WeightRoom, Floor2_FightHall, Floor3_Lounge
    └── GymCrowd (Node3D)                  new: scripts/npc/gym_crowd.gd, NPC spawner and crowd controller
        └── Mike, Dana, … Nora             13 instances of scenes/npc/gym_npc.tscn, spawned at runtime
```

`scenes/npc/gym_npc.tscn`

```
GymNpc (AnimatableBody3D)                  scripts/npc/gym_npc.gd
├── CollisionShape3D
├── Model (CharacterModel)                 render layer 1, coloured and shaped per regular
├── NameTag (Label3D, billboard)           "Mike | LVL 4 | 3 Months"
└── Bubble (Label3D, billboard)            speech bubble
```

The labels are on render layer 2, so mirrors do not show them backwards.

`Floor3_Lounge` creates the bar's working parts at runtime:

```
Floor3_Lounge                              scripts/world/gym_floor_lounge.gd
└── SupplementBar (Node3D)                 scripts/world/supplement_bar.gd, at the middle of the counter
    ├── Counter (StaticBody3D, layer 4) → Interactable    "[E] Supplement Bar"
    └── Bartender                          instance of gym_npc.tscn, activity SERVE
```

`scenes/ui/hud.tscn`

```
HUD (CanvasLayer)
└── Root (Control)
    ├── Vignette, PulseVignette            new: pre-workout pulse
    ├── LeftColumn
    │   └── BuffRow: ProteinBadge → ProteinLabel, PreworkoutBadge → PreworkoutLabel   new
    ├── … CombatHUD, Popups, FightCard
    ├── BarShop                            new: instance of scenes/ui/bar_shop.tscn
    └── PauseMenu                          new: instance of scenes/ui/pause_menu.tscn
```

`bar_shop.tscn` and `pause_menu.tscn` are a root `Control` with a script that builds its panel from `UiKit`,
like the Step 3 menus. `PauseMenu` runs with `process_mode = Always`.

Particle effects are created in code and need no nodes of their own: `CombatFx.burst()` adds a one-shot
`GPUParticles3D` to the scene and frees it; `PlayerArms` owns two `GPUParticles3D` for the forearm aura.

## Scripts

| Path | Role |
| --- | --- |
| `scripts/autoload/player_stats.gd` | Autoload `PlayerStats`: level, XP, strength, stamina, muscles, pump, warm-up, injury, tenure, rank |
| `scripts/autoload/game_state.gd` | Autoload `GameState`: objective and toast messages |
| `scripts/autoload/audio_manager.gd` | Autoload `AudioManager`: mixes sound effects and streams the gym beat through `AudioStreamGenerator` |
| `scripts/autoload/save_manager.gd` | Autoload `SaveManager`: JSON save and load, settings, career reset |
| `scripts/audio/synth.gd`, `sound_bank.gd`, `gym_beat.gd` | Oscillator and noise building blocks; the nineteen effects; the speaker loop |
| `scripts/npc/gym_npc.gd` | `GymNpc`: a regular with a name tag, speech bubble and one looping activity |
| `scripts/npc/gym_crowd.gd`, `reputation.gd` | `GymCrowd`: spawner, remarks, stepping aside, the crowd at the cage. `Reputation`: tier and lines |
| `scripts/world/supplement_bar.gd`, `scripts/core/supplements.gd` | The bartender and shop prompt; the four consumables |
| `scripts/ui/bar_shop.gd`, `pause_menu.gd` | Shop and pause menu |
| `scripts/fx/combat_fx.gd` | `CombatFx`: sweat, spark, shard and confetti bursts, light flashes |
| `scripts/core/build.gd` | `Build`: primitive mesh, collider, wall and stair helpers with cached meshes and materials |
| `scripts/core/interactable.gd` | `Interactable`: component the player's interact ray looks for |
| `scripts/player/player.gd` | `Player`: movement, look, interaction, riding, station seat, camera shake |
| `scripts/player/player_arms.gd` | `PlayerArms`: first-person arms with two-bone IK, grips and physique |
| `scripts/player/character_model.gd` | `CharacterModel`: jointed humanoid with per-group physique and workout poses |
| `scripts/workouts/workout_station.gd` | `WorkoutStation`: base class for usable equipment |
| `scripts/workouts/barbell_station.gd`, `barbell.gd` | Bench, squat and deadlift mini-game; barbell with plates that follow the load |
| `scripts/workouts/curl_station.gd` | Alternating dumbbell curls |
| `scripts/workouts/treadmill_station.gd` | Treadmill with moving belt |
| `scripts/workouts/warmup_station.gd` | Stretch and push-up rhythm game |
| `scripts/ui/hud.gd`, `workout_overlay.gd`, `gauge_bar.gd` | HUD, contextual station gauges, the gauge control |
| `scripts/ui/combat_hud.gd`, `fight_card.gd`, `ui_kit.gd` | Fight overlay and result screen, fight selection menu, shared flat dark UI pieces |
| `scripts/combat/combat_controller.gd` | `CombatController`: stance, strikes, combos, block, slips, perfect counter, the player's health in a bout |
| `scripts/combat/strike.gd`, `combo_tracker.gd` | `Strike`: one blow and its outcome. `ComboTracker`: timed chain detection |
| `scripts/combat/combat_target.gd`, `combat_zone.gd` | `CombatTarget`: hurtbox component. `CombatZone`: where the hands come up |
| `scripts/combat/time_fx.gd`, `combat_popup.gd` | Hit-stop and slow motion; floating 3D callouts |
| `scripts/combat/fight_animator.gd`, `fight_pose.gd`, `fight_gear.gd` | Guard, wind-up, strike, block, stagger and knockdown poses for `CharacterModel`; gloves |
| `scripts/combat/punching_bag.gd` | `PunchingBag`: swinging heavy bag that pays XP and conditioning |
| `scripts/combat/enemy_fighter.gd` | `EnemyFighter`: opponent body, hurtbox, tag and telegraphed AI |
| `scripts/combat/fighter_profile.gd`, `fighter_roster.gd` | Opponent data; the five-fighter ladder and the Endless League generator |
| `scripts/combat/ring_manager.gd`, `fight_card_terminal.gd` | `RingManager`: gate, countdown, bout flow, payout. The kiosk beside the cage |
| `scripts/combat/fight_record.gd` | `FightRecord`: wins, losses, streak |
| `scripts/vehicles/bicycle.gd`, `bicycle_model.gd` | `Bicycle` arcade physics and its `BicycleModel` |
| `scripts/world/mirror.gd` | `Mirror`: planar reflection through a SubViewport, rank tag |
| `scripts/world/beacon.gd` | `Beacon`: waypoint beam, emits `reached` |
| `scripts/world/neighborhood.gd` | `Neighborhood`: seeded street generator |
| `scripts/world/gym.gd`, `gym_floor_*.gd`, `gym_props.gd`, `gym_station.gd` | Gym shell, the three storeys, equipment builders, the `GymStation` marker for props without a mini-game |

Render layers: 1 world (opponents and regulars included), 2 first-person only (arms, gloves, held dumbbells,
the regulars' name tags and speech bubbles), 3 third-person only (the player's body, seen by mirrors and shadows). Physics layers: 1 world, 2 player, 3 vehicles, 4 interactables.

## PlayerStats reference

Read these directly from the `PlayerStats` autoload:

| Property | Meaning |
| --- | --- |
| `cash` | Prize money in dollars. `add_cash(n)`, `can_afford(price)`, `spend_cash(price)` (false if short), `get_cash_text()` gives "$1,250" |
| `level`, `xp`, `rank_title`, `gym_tenure` | Progress; `get_profile_title()` gives "Gym Regular \| 4 Days", `get_overhead_tag()` gives "LVL 3 \| Gym Regular \| 4 Days" |
| `fight_record` | A `FightRecord`: `wins`, `losses`, `win_streak`, `best_streak`, `total()`, `to_text()` gives "3 W - 1 L" |
| `ladder_progress`, `league_wins` | Ladder fighters beaten (0 to 5) and Endless League challengers beaten |
| `strength` | Roughly the safe bench press in kg; `get_effective_strength()` applies strain, fatigue and pre-workout |
| `stamina`, `max_stamina`, `is_exhausted` | `spend_stamina(amount)` returns false when exhausted |
| `muscle_arms`, `muscle_torso`, `muscle_legs` | 0 to 100; `get_muscle_visual(group)` gives 0 to 1 for models |
| `pump_level` | 0 to 100; `get_gain_multiplier()` gives 1.0 to 2.5 |
| `warmup_timer`, `injury_timer` | Seconds left; `is_warmed_up()`, `is_strained()` |
| `protein_timer`, `preworkout_timer` | Seconds of each buff left; `has_protein()`, `has_preworkout()`, `drink_isotonic()`, `drink_protein()`, `drink_preworkout()`, `heal_strain()` |
| `to_save()`, `apply_save(data)`, `reset_career()` | The career as a dictionary, and back |

Signals: `cash_changed`, `fight_record_changed`, `buffs_changed`, `rep_completed`, `profile_reloaded`,
`xp_changed`, `level_up`, `rank_changed`, `tenure_changed`, `strength_changed`, `stamina_changed`, `exhausted`,
`muscle_changed`, `pump_changed`, `status_changed`, `injured`, `popup_requested`.

Extension points:

- **A new consumable**: add an entry to `Supplements.ITEMS` and a branch in `Supplements.buy()`.
- **A new regular**: add a line to `GymCrowd.ROSTER`. A new activity is a value in `GymNpc.Activity` and a
  branch in `GymNpc._animate()`.
- **A new sound**: add a function to `SoundBank` and its name to `render_all()`, then
  `AudioManager.play(&"name")`.
- **A new station**: extend `WorkoutStation`, override `_begin`, `_tick`, `_view` and `handle_input`, and
  place it with `GymProps.workout()`.
- **More opponents**: add a `FighterProfile` to `FighterRoster.ladder()` or a style to
  `league_challenger()`.

## Final checklist

Checked on Godot 4.4.1 and 4.7.2 by scripted play of the real scene:

- [x] **Step 1** Start at the house, mount the bike, ride to the beacon, walk into the three-storey gym.
- [x] **Step 2** Use a station, bank reps into muscle, strength, XP and pump; strain and recover.
- [x] **Step 3** Work a heavy bag; open the fight card, win through the five-fighter ladder into the Endless
  League; lose a bout and walk out; cash, XP, tenure and the record are paid.
- [x] **Step 4** Thirteen regulars and a bartender on three storeys; remarks change with the level tier;
  regulars step aside and gather at the cage from level 10 and cheer; the bar sells and applies all four
  consumables; nineteen synthesized sounds and the gym beat; save, load, autosave and career reset; pause
  menu with sensitivity and audio settings; sweat, sparks, shards, confetti and the arm aura.
- [x] **Together** Stats trained downstairs decide fights upstairs; fight cash buys buffs on the third
  floor that speed up training and fighting; everything survives a restart.
- [x] **No stuck input** Leaving a station, the ring, the fight card, the shop and the pause menu each hand
  back movement and the captured mouse; a career reset reloads the world unpaused at normal speed.

## Windows build

`export_presets.cfg` has a **Windows Desktop** preset that produces a single `IronTemple.exe` with the game
data embedded. In the editor, install the export templates (Editor → Manage Export Templates), then use
Project → Export → Windows Desktop → Export Project. From a shell:

```
godot --headless --path . --export-release "Windows Desktop" build/IronTemple.exe
```

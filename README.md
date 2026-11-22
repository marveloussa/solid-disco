# Iron Temple

First-person stylized Gym & MMA progression game for **Godot 4.4+** (Forward+ renderer; tested on 4.4.1 and 4.7.2).

**Steps 1 to 3 of 4** are in: the intro street, a rideable bicycle, a three-storey gym, full first-floor
training with stats, levelling, visible muscle growth, a pump multiplier and injuries, and second-floor
MMA: first-person striking, heavy bags, a five-fighter ladder in the octagon and an endless league.
Everything is built from Godot's primitive meshes and `StandardMaterial3D`, so there are no imported assets:
open `project.godot` in the editor and press **F5**.

## Controls

| Input | On foot | On the bike |
| --- | --- | --- |
| `W` `A` `S` `D` | Move | Accelerate, brake/reverse, steer |
| Mouse | Look | Look around (the bike keeps its heading) |
| `Shift` | Sprint (uses stamina) | Sprint pedalling (uses stamina) |
| `Space` | Jump | |
| `E` | Interact with what the crosshair points at | Dismount (prompt shows at walking pace) |
| `Esc` / click | Release / recapture the mouse | |

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
| `LMB` | Left jab. A second `LMB` straight after a jab is a left hook |
| `RMB` | Right cross. A second `RMB` straight after a cross is a right overhand |
| `F` / middle mouse | Front push kick; a knee to the body when chest to chest. Pushes back and drains stamina |
| `Shift`, or `LMB` + `RMB` held together | Tight guard: 80% less damage, costs stamina |
| `A` / `D` / `S` + `Space` | Slip left, right or back (`Space` alone slips back) |
| `E` at the terminal | Fight Card / Enter Ring |

| Combo | Buttons | Effect |
| --- | --- | --- |
| 1-2 Combo | `LMB` `RMB` | Cross lands for x1.5 |
| Guard Breaker | `LMB` `LMB` `RMB` | Jab, hook, uppercut: shatters a raised guard and staggers |
| KO Finisher | `RMB` `LMB` `RMB` | Cross, jab, overhand for x2 with heavy knockback and a stagger |

Presses chain when they are less than 0.9 s apart; a whiff or taking a clean hit breaks the chain.
**Perfect counter**: slip within 0.22 s of a strike landing and time slows for a quarter of a second; the
next strike you throw does x2 damage.

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

## Scripts

| Path | Role |
| --- | --- |
| `scripts/autoload/player_stats.gd` | Autoload `PlayerStats`: level, XP, strength, stamina, muscles, pump, warm-up, injury, tenure, rank |
| `scripts/autoload/game_state.gd` | Autoload `GameState`: objective and toast messages |
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

Render layers: 1 world (opponents included), 2 first-person only (arms, gloves, held dumbbells), 3
third-person only (the player's body, seen by mirrors and shadows). Physics layers: 1 world, 2 player, 3 vehicles, 4 interactables.

## PlayerStats for Step 4

Read these directly from the `PlayerStats` autoload:

| Property | Meaning |
| --- | --- |
| `cash` | Prize money in dollars. `add_cash(n)`, `can_afford(price)`, `spend_cash(price)` (false if short), `get_cash_text()` gives "$1,250" |
| `level`, `xp`, `rank_title`, `gym_tenure` | Progress; `get_profile_title()` gives "Gym Regular \| 4 Days", `get_overhead_tag()` gives "LVL 3 \| Gym Regular \| 4 Days" |
| `fight_record` | A `FightRecord`: `wins`, `losses`, `win_streak`, `best_streak`, `total()`, `to_text()` gives "3 W - 1 L" |
| `ladder_progress`, `league_wins` | Ladder fighters beaten (0 to 5) and Endless League challengers beaten |
| `strength` | Roughly the safe bench press in kg; `get_effective_strength()` applies strain and fatigue |
| `stamina`, `max_stamina`, `is_exhausted` | `spend_stamina(amount)` returns false when exhausted |
| `muscle_arms`, `muscle_torso`, `muscle_legs` | 0 to 100; `get_muscle_visual(group)` gives 0 to 1 for models |
| `pump_level` | 0 to 100; `get_gain_multiplier()` gives 1.0 to 2.5 |
| `warmup_timer`, `injury_timer` | Seconds left; `is_warmed_up()`, `is_strained()` |

Signals: `cash_changed`, `fight_record_changed`, `xp_changed`, `level_up`, `rank_changed`, `tenure_changed`,
`strength_changed`, `stamina_changed`, `exhausted`, `muscle_changed`, `pump_changed`, `status_changed`,
`injured`, `popup_requested`. `get_snapshot()` returns every stat, including cash and the record, as a
plain dictionary.

Extension points:

- **The supplement bar**: `if PlayerStats.spend_cash(price):` then apply the buff; listen to `cash_changed`
  for the price tags. The HUD already shows cash and the record.
- **Living gym NPCs**: instance `CharacterModel` with `render_layers = 1`, call `set_physique()` and drive
  `animate()`. Give it a `FightAnimator` (`model.fight_pose = animator.pose`) to shadow-box, or add a
  `CombatTarget` child to make it hittable. `PlayerStats.format_tag(level, rank, tenure)` builds a tag.
- **Audio**: `CombatController` emits `strike_resolved(strike)` (kind, outcome, heavy, counter),
  `damage_taken`, `counter_opened`, `guard_broken` and `knocked_out`; `RingManager` (group `ring`) emits
  `bout_started` and `bout_finished`.
- **A new station**: extend `WorkoutStation`, override `_begin`, `_tick`, `_view` and `handle_input`, and
  place it with `GymProps.workout()`.
- **More opponents**: add a `FighterProfile` to `FighterRoster.ladder()` or a style to
  `league_challenger()`.

## Windows build

`export_presets.cfg` has a **Windows Desktop** preset that produces a single `IronTemple.exe` with the game
data embedded. In the editor, install the export templates (Editor → Manage Export Templates), then use
Project → Export → Windows Desktop → Export Project. From a shell:

```
godot --headless --path . --export-release "Windows Desktop" build/IronTemple.exe
```

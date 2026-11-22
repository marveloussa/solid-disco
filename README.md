# Iron Temple

First-person stylized Gym & MMA progression game for **Godot 4.4+** (Forward+ renderer; tested on 4.4.1 and 4.7.2).

**Steps 1 and 2 of 4** are in: the intro street, a rideable bicycle, a three-storey gym, and full first-floor
training with stats, levelling, visible muscle growth, a pump multiplier and injuries.
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
| `scripts/vehicles/bicycle.gd`, `bicycle_model.gd` | `Bicycle` arcade physics and its `BicycleModel` |
| `scripts/world/mirror.gd` | `Mirror`: planar reflection through a SubViewport, rank tag |
| `scripts/world/beacon.gd` | `Beacon`: waypoint beam, emits `reached` |
| `scripts/world/neighborhood.gd` | `Neighborhood`: seeded street generator |
| `scripts/world/gym.gd`, `gym_floor_*.gd`, `gym_props.gd`, `gym_station.gd` | Gym shell, the three storeys, equipment builders, the `GymStation` marker (heavy bags) |

Render layers: 1 world, 2 first-person only (arms, held dumbbells), 3 third-person only (the player's body,
seen by mirrors and shadows). Physics layers: 1 world, 2 player, 3 vehicles, 4 interactables.

## PlayerStats for Step 3

Read these directly from the `PlayerStats` autoload:

| Property | Meaning |
| --- | --- |
| `level`, `xp`, `rank_title`, `gym_tenure` | Progress; `get_profile_title()` gives "Gym Regular \| 4 Days" |
| `strength` | Roughly the safe bench press in kg; `get_effective_strength()` applies strain and fatigue |
| `stamina`, `max_stamina`, `is_exhausted` | `spend_stamina(amount)` returns false when exhausted |
| `muscle_arms`, `muscle_torso`, `muscle_legs` | 0 to 100; `get_muscle_visual(group)` gives 0 to 1 for models |
| `pump_level` | 0 to 100; `get_gain_multiplier()` gives 1.0 to 2.5 |
| `warmup_timer`, `injury_timer` | Seconds left; `is_warmed_up()`, `is_strained()` |

Signals: `xp_changed`, `level_up`, `rank_changed`, `tenure_changed`, `strength_changed`, `stamina_changed`,
`exhausted`, `muscle_changed`, `pump_changed`, `status_changed`, `injured`, `popup_requested`.
`get_snapshot()` returns every stat as a plain dictionary.

Extension points:

- **A new station**: extend `WorkoutStation`, override `_begin`, `_tick`, `_view` and `handle_input`, and
  place it with `GymProps.workout()`.
- **Fighters and NPCs**: instance `CharacterModel` with `render_layers = 1`, call `set_physique()` and
  drive `animate()`.
- **Damage in fights**: `PlayerStats.apply_strain(severity)` already shakes the camera, flashes the
  vignette and applies the debuff.

## Windows build

`export_presets.cfg` has a **Windows Desktop** preset that produces a single `IronTemple.exe` with the game
data embedded. In the editor, install the export templates (Editor → Manage Export Templates), then use
Project → Export → Windows Desktop → Export Project. From a shell:

```
godot --headless --path . --export-release "Windows Desktop" build/IronTemple.exe
```

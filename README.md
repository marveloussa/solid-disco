# Iron Temple

First-person stylized Gym & MMA progression game for **Godot 4.4+** (Forward+ renderer; tested on 4.4.1 and 4.7.2).

This is **Step 1 of 4**: a playable prototype with the intro street, a rideable bicycle and a three-storey gym.
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

## Windows build

`export_presets.cfg` has a **Windows Desktop** preset that produces a single `IronTemple.exe` with the game
data embedded. In the editor, install the export templates (Editor → Manage Export Templates), then use
Project → Export → Windows Desktop → Export Project. From a shell:

```
godot --headless --path . --export-release "Windows Desktop" build/IronTemple.exe
```

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

`scenes/player/player.tscn`

```
Player (CharacterBody3D)                   scripts/player/player.gd      layer 2, mask 1 + 3
├── CollisionShape3D                       CapsuleShape3D, 1.95 m tall, 0.28 m radius
├── Head (Node3D)                          top-level, physics interpolation off
│   └── Camera3D                           hides render layer 3
│       ├── InteractRay (RayCast3D)        3 m, world + vehicles
│       └── Arms (Node3D)                  scripts/player/player_arms.gd
├── Model (Node3D)                         scripts/player/character_model.gd
└── Stamina (Node)                         scripts/core/stamina.gd
```

`scenes/vehicles/bicycle.tscn`

```
Bicycle (CharacterBody3D)                  scripts/vehicles/bicycle.gd   layer 3, mask 1
├── FrameCollision (CollisionShape3D)      capsule along the frame
├── RiderCollision (CollisionShape3D)      upright capsule
├── Interactable (Node)                    scripts/core/interactable.gd  action_text = "Mount Bike"
└── Model (Node3D)                         scripts/vehicles/bicycle_model.gd
```

`scenes/world/mirror.tscn`

```
Mirror (Node3D)                            scripts/world/mirror.gd
├── SubViewport
│   └── MirrorCamera (Camera3D)            frustum projection, hides render layer 2
└── Surface (MeshInstance3D)               quad showing the SubViewport texture
```

`scenes/ui/hud.tscn`

```
HUD (CanvasLayer)                          scripts/ui/hud.gd
└── Root (Control)
    ├── ProfilePanel (PanelContainer)
    │   └── VBox (VBoxContainer)
    │       ├── Header (HBoxContainer)
    │       │   ├── LevelBadge (PanelContainer) → LevelLabel (Label)     "Lvl 1"
    │       │   └── RankLabel (Label)                                    "Skinny Rookie | 0 Days"
    │       └── StaminaRow (HBoxContainer)
    │           ├── StaminaCaption (Label)
    │           └── StaminaBar (ProgressBar)
    ├── ObjectiveLabel (Label)
    ├── Crosshair (Panel)
    ├── PromptAnchor (CenterContainer)
    │   └── Prompt (PanelContainer)
    │       └── Row (HBoxContainer)
    │           ├── KeyCap (PanelContainer) → PromptKey (Label)          "E"
    │           └── PromptLabel (Label)                                  "Mount Bike"
    ├── ToastLabel (Label)
    ├── ControlsHint (Label)
    └── Waypoint (Control)
        ├── Diamond (Panel)
        └── WaypointLabel (Label)                                        "GYM  250 m"
```

Scripts marked in the trees add their meshes, colliders and lights as children at runtime: the bicycle
model's wheels, crank and steering pivot, the player's arms and body, and all street and gym geometry.
That geometry is therefore visible when the game runs, not in the editor viewport.

## Scripts

| Path | Role |
| --- | --- |
| `scripts/autoload/game_state.gd` | Autoload `GameState`: rank, days, level, `muscle`, objective, toasts |
| `scripts/core/build.gd` | `Build`: primitive mesh, collider, wall and stair helpers with cached meshes and materials |
| `scripts/core/interactable.gd` | `Interactable`: component the player's interact ray looks for |
| `scripts/core/stamina.gd` | `Stamina`: regenerating pool with exhaustion |
| `scripts/player/player.gd` | `Player`: movement, look, interaction, mounting |
| `scripts/player/player_arms.gd` | `PlayerArms`: first-person arms with two-bone IK |
| `scripts/player/character_model.gd` | `CharacterModel`: jointed humanoid for the mirror, shadow and future NPCs |
| `scripts/vehicles/bicycle.gd`, `bicycle_model.gd` | `Bicycle` arcade physics and its `BicycleModel` |
| `scripts/world/mirror.gd` | `Mirror`: planar reflection through a SubViewport |
| `scripts/world/beacon.gd` | `Beacon`: waypoint beam, emits `reached` |
| `scripts/world/neighborhood.gd` | `Neighborhood`: seeded street generator |
| `scripts/world/gym.gd`, `gym_floor_*.gd`, `gym_props.gd`, `gym_station.gd` | Gym shell, the three storeys, equipment builders and the `GymStation` marker |
| `scripts/ui/hud.gd` | `HUD`: profile, stamina, prompt, toast, waypoint |

Render layers: 1 world, 2 first-person only (arms), 3 third-person only (the player's body, seen by mirrors
and shadows). Physics layers: 1 world, 2 player, 3 vehicles.

## Extending in the next steps

- **Workouts**: every station carries a `GymStation` (group `gym_stations`) with a `station_type` such as
  `&"bench_press"`. Connect to its `interacted(player)` signal to start a workout, and set
  `player.controls_enabled = false` while it runs.
- **Muscle growth**: call `GameState.set_muscle(0.0..1.0)`. The first-person arms and the mirror body
  thicken from the same value. `GameState.set_profile(rank, days, level)` updates the HUD.
- **Stamina and injuries**: `Stamina.spend()` is the single gate for effort; add injury modifiers there
  or in `GameState`.
- **NPCs and fighters**: instance `CharacterModel` with `render_layers = 1` and drive `animate()`.
- **New interactions**: add an `Interactable` child to any physics body and set `action_text`.

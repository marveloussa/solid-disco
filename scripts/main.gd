extends Node3D
## Top-level scene script: wires the player to the HUD and steers the player with objectives.

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var beacon: Beacon = $GymBeacon


func _ready() -> void:
	hud.bind_player(player)
	GameState.set_objective("Grab your bike and ride to the gym")
	player.vehicle_changed.connect(_on_vehicle_changed)
	beacon.reached.connect(_on_gym_reached)
	PlayerStats.status_changed.connect(_on_status_changed)


func _on_vehicle_changed(vehicle: Bicycle) -> void:
	if vehicle != null and beacon.active:
		GameState.set_objective("Follow the beacon to the gym")


func _on_gym_reached() -> void:
	GameState.set_objective("Warm up on the mats by the entrance, then hit the weights")


func _on_status_changed() -> void:
	if PlayerStats.is_strained():
		GameState.set_objective("Strained: rest or stretch on the mats to heal faster")
	elif PlayerStats.is_warmed_up():
		GameState.set_objective("Warmed up: lift, curl and run to build your pump")
	elif not beacon.active:
		GameState.set_objective("Warm up on the mats by the entrance, then hit the weights")

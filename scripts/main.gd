extends Node3D
## Top-level scene script: wires the player to the HUD and drives the intro objective.

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var beacon: Beacon = $GymBeacon


func _ready() -> void:
	hud.bind_player(player)
	GameState.set_objective("Grab your bike and ride to the gym")
	player.vehicle_changed.connect(_on_vehicle_changed)
	beacon.reached.connect(_on_gym_reached)


func _on_vehicle_changed(vehicle: Bicycle) -> void:
	if vehicle != null and beacon.active:
		GameState.set_objective("Follow the beacon to the gym")


func _on_gym_reached() -> void:
	GameState.set_objective("Explore the gym: weights, fight hall and lounge")

extends Node3D
## Top-level scene script: wires the player to the HUD and steers the player with objectives.

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var beacon: Beacon = $GymBeacon

# What to do about the fight card, shown whenever the hands come down.
var _fight_objective := ""


func _ready() -> void:
	hud.bind_player(player)
	GameState.set_objective("Grab your bike and ride to the gym")
	player.vehicle_changed.connect(_on_vehicle_changed)
	beacon.reached.connect(_on_gym_reached)
	PlayerStats.status_changed.connect(_on_status_changed)
	PlayerStats.level_up.connect(_on_level_up)
	player.combat.stance_changed.connect(_on_stance_changed)
	var ring := get_tree().get_first_node_in_group(&"ring") as RingManager
	if ring != null:
		ring.bout_started.connect(_on_bout_started)
		ring.bout_finished.connect(_on_bout_finished)


func _on_vehicle_changed(vehicle: Bicycle) -> void:
	if vehicle != null and beacon.active:
		GameState.set_objective("Follow the beacon to the gym")


func _on_gym_reached() -> void:
	GameState.set_objective("Warm up on the mats by the entrance, then hit the weights")


func _on_status_changed() -> void:
	if player.combat.in_bout:
		return
	if PlayerStats.is_strained():
		GameState.set_objective("Strained: rest or stretch on the mats to heal faster")
	elif PlayerStats.is_warmed_up():
		GameState.set_objective("Warmed up: lift, curl and run to build your pump")
	elif not beacon.active:
		GameState.set_objective("Warm up on the mats by the entrance, then hit the weights")


func _on_level_up(level: int) -> void:
	if level >= 2 and PlayerStats.fight_record.total() == 0 and not player.combat.in_bout:
		GameState.set_objective("Level %d: head up to 2F. Work the heavy bags or take a fight at the cage" % level)


func _on_stance_changed(active: bool) -> void:
	if active and not player.combat.in_bout:
		GameState.set_objective("Hands up: chain jabs and crosses into combos, block and slip")
	elif not active:
		GameState.set_objective(_next_fight_text() if _fight_objective.is_empty() else _fight_objective)


func _on_bout_started(profile: FighterProfile) -> void:
	GameState.set_objective("Knock out %s" % profile.fighter_name)


func _on_bout_finished(profile: FighterProfile, won: bool) -> void:
	_fight_objective = _next_fight_text() if won else "Train downstairs, then rematch %s" % profile.fighter_name
	GameState.set_objective(_fight_objective)


## Who is next on the fight card.
func _next_fight_text() -> String:
	if FighterRoster.is_league_open():
		return "Endless League: challenger Lvl %d is waiting at the cage" % FighterRoster.next_league_level()
	var next := FighterRoster.ladder()[PlayerStats.ladder_progress]
	return "Next fight: %s (Lvl %d). Fight Card terminal by the 2F cage" % [next.fighter_name, next.level]

extends Node
## Global progression state (autoload `GameState`).
## The HUD and player listen to these signals; later steps add workouts, injuries and fight records here.

signal profile_changed
signal physique_changed(muscle: float)
signal objective_changed(text: String)
signal toast_requested(text: String)

var rank_title := "Skinny Rookie"
var days := 0
var level := 1
var experience := 0.0
## 0 = lanky beginner, 1 = fully built. Drives arm and body girth.
var muscle := 0.0
var objective := ""


func get_profile_title() -> String:
	return "%s | %d %s" % [rank_title, days, "Day" if days == 1 else "Days"]


func set_profile(new_rank: String, new_days: int, new_level: int) -> void:
	rank_title = new_rank
	days = new_days
	level = new_level
	profile_changed.emit()


func set_muscle(value: float) -> void:
	muscle = clampf(value, 0.0, 1.0)
	physique_changed.emit(muscle)


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


## Shows a short message on the HUD.
func notify(text: String) -> void:
	toast_requested.emit(text)

class_name Stamina
extends Node
## Regenerating stamina pool. Sprinting and bike boosts spend it; workouts and fights will too.

signal changed(current: float, maximum: float)
signal exhausted

@export var maximum := 100.0
@export var regen_per_second := 16.0
## Seconds without spending before regeneration starts.
@export var regen_delay := 0.9
## After running dry, stamina must climb back to this before it can be spent again.
@export var recover_threshold := 25.0

var current := 100.0
var is_exhausted := false

var _regen_timer := 0.0


func _ready() -> void:
	current = maximum


## Spends `amount` and returns true, or returns false when exhausted.
func spend(amount: float) -> bool:
	if is_exhausted or current <= 0.0:
		return false
	current = maxf(current - amount, 0.0)
	_regen_timer = regen_delay
	if current <= 0.0:
		is_exhausted = true
		exhausted.emit()
	changed.emit(current, maximum)
	return true


func _physics_process(delta: float) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return
	if current < maximum:
		current = minf(current + regen_per_second * delta, maximum)
		if is_exhausted and current >= recover_threshold:
			is_exhausted = false
		changed.emit(current, maximum)

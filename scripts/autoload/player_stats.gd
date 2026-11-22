extends Node
## Autoload `PlayerStats`: the single source of truth for the fighter's progression and condition.
## Workout stations pay out through `reward_rep()`; the HUD, the player rig and the fight system
## read the properties and listen to the signals.
##
## Tuned to run about ten times faster than real life: roughly half an hour of training takes a
## skinny rookie to a lean, shredded build.

signal xp_changed(xp: float, xp_to_next: float)
signal level_up(new_level: int)
signal rank_changed(title: String)
signal tenure_changed(days: int)
signal strength_changed(strength: float)
signal stamina_changed(current: float, maximum: float)
signal exhausted
## Any of the three muscle groups changed.
signal muscle_changed
signal pump_changed(pump_level: float)
## The warm-up or injury state changed.
signal status_changed
signal injured(duration: float)
## Floating HUD text. `kind` is &"gain", &"perfect", &"level", &"status" or &"warning".
signal popup_requested(text: String, kind: StringName)

const MUSCLE_MAX := 100.0
const PUMP_MAX := 100.0
const MAX_PUMP_MULTIPLIER := 2.5
const WARMUP_DURATION := 300.0
const MIN_STRAIN_DURATION := 45.0
const MAX_STRAIN_DURATION := 60.0

## Titles unlock at these levels; past the last one a numeral is added every PRESTIGE_LEVELS.
const RANKS: Array[Dictionary] = [
	{"level": 1, "title": "Skinny Rookie"},
	{"level": 3, "title": "Gym Regular"},
	{"level": 6, "title": "Lean Grinder"},
	{"level": 9, "title": "Shredded Prospect"},
	{"level": 13, "title": "Cage Ready"},
	{"level": 17, "title": "Iron Machine"},
]
const PRESTIGE_LEVELS := 5
const MUSCLE_LABELS := {&"arms": "Arms", &"torso": "Torso", &"legs": "Legs"}

# Progression tuning.
const XP_BASE := 50.0
const XP_CURVE := 1.3
const XP_PER_REP := 12.0
const MUSCLE_PER_REP := 0.5
const STRENGTH_PER_REP := 0.2
const STAMINA_PER_LEVEL := 2.0
## Training time that counts as one day of gym tenure.
const DAY_SECONDS := 45.0

# Pump.
const PUMP_PER_REP := 6.0
const PUMP_GRACE := 3.0
const PUMP_DECAY := 3.0
## Extra stamina cost of effort at full pump.
const PUMP_STAMINA_DRAIN := 0.6

# Stamina.
const STAMINA_REGEN := 0.16
const STAMINA_REGEN_DELAY := 0.9
## After running dry, stamina must climb back to this share before it can be spent again.
const EXHAUSTION_RECOVERY := 0.25
## Below this share of stamina the lifter starts losing strength.
const FATIGUE_THRESHOLD := 0.25
const FATIGUE_STRENGTH_FACTOR := 0.75

# Injury.
const STRAIN_STRENGTH_FACTOR := 0.6
const STRAIN_SPEED_FACTOR := 0.6
const REST_RECOVERY_FACTOR := 2.0
const WARMUP_RISK_FACTOR := 0.2
const TIRED_RISK_FACTOR := 1.6

var level := 1
var xp := 0.0
## Roughly the bench press, in kilograms, the fighter handles safely.
var strength := 20.0
var max_stamina := 100.0
var stamina := 100.0
## Muscle development per group, 0 to MUSCLE_MAX.
var muscle_arms := 0.0
var muscle_torso := 0.0
var muscle_legs := 0.0
## 0 to PUMP_MAX. Multiplies muscle and XP gains up to MAX_PUMP_MULTIPLIER.
var pump_level := 0.0
## Seconds of the "Warmed Up" buff left.
var warmup_timer := 0.0
## Progress towards the next warm-up buff, 0 to 1.
var warmup_progress := 0.0
## Seconds of the "Strained" debuff left.
var injury_timer := 0.0
## Days of training, as a fraction. Use `get_days()` for display.
var gym_tenure := 0.0
var rank_title := "Skinny Rookie"
var is_exhausted := false
## Set every physics tick by the player: resting doubles injury recovery, training adds tenure.
var resting := false
var training := false

var _regen_delay := 0.0
var _pump_grace := 0.0


func _physics_process(delta: float) -> void:
	_tick_stamina(delta)
	_tick_pump(delta)
	_tick_status(delta)
	if training:
		var days := get_days()
		gym_tenure += delta / DAY_SECONDS
		if get_days() != days:
			tenure_changed.emit(get_days())


# --- Profile ---------------------------------------------------------------------------------

func get_days() -> int:
	return floori(gym_tenure)


## "Skinny Rookie | 0 Days"
func get_profile_title() -> String:
	var days := get_days()
	return "%s | %d %s" % [rank_title, days, "Day" if days == 1 else "Days"]


func get_rank_for(target_level: int) -> String:
	var title: String = RANKS[0]["title"]
	var top_level := 1
	for rank in RANKS:
		top_level = rank["level"]
		if target_level >= top_level:
			title = rank["title"]
	var prestige := floori((target_level - top_level) / float(PRESTIGE_LEVELS))
	if prestige > 0:
		title += " " + _roman(prestige + 1)
	return title


func xp_to_next() -> float:
	return roundf(XP_BASE * pow(level, XP_CURVE))


func add_xp(amount: float) -> void:
	xp += amount
	var leveled := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_stamina += STAMINA_PER_LEVEL
		leveled = true
		level_up.emit(level)
		popup_requested.emit("LEVEL UP!  Lvl %d" % level, &"level")
	if leveled:
		# A level-up is a second wind.
		stamina = max_stamina
		is_exhausted = false
		stamina_changed.emit(stamina, max_stamina)
		var title := get_rank_for(level)
		if title != rank_title:
			rank_title = title
			rank_changed.emit(rank_title)
	xp_changed.emit(xp, xp_to_next())


# --- Training --------------------------------------------------------------------------------

## Pays out one successful rep. `focus` weights the groups worked, e.g. {&"torso": 1.0, &"arms": 0.5}.
## `intensity` scales every gain (load relative to what the lifter can handle), `strength_weight`
## and `stamina_growth` add Strength and MaxStamina. A perfect rep doubles pump and XP.
func reward_rep(focus: Dictionary, intensity: float = 1.0, perfect: bool = false, strength_weight: float = 0.0, stamina_growth: float = 0.0) -> void:
	var multiplier := get_gain_multiplier()
	var labels := PackedStringArray()
	for group: StringName in focus:
		var weight: float = focus[group]
		if add_muscle(group, MUSCLE_PER_REP * weight * intensity * multiplier) > 0.0:
			labels.append("+" + String(MUSCLE_LABELS[group]))
	if strength_weight > 0.0:
		add_strength(STRENGTH_PER_REP * strength_weight * intensity * multiplier)
		labels.append("+Strength")
	if stamina_growth > 0.0:
		add_max_stamina(stamina_growth * multiplier)
		labels.append("+Stamina")
	if not labels.is_empty():
		popup_requested.emit("  ".join(labels), &"gain")
	var bonus := 2.0 if perfect else 1.0
	if perfect:
		popup_requested.emit("PERFECT REP!", &"perfect")
	add_pump(PUMP_PER_REP * bonus)
	add_xp(XP_PER_REP * intensity * multiplier * bonus)


func get_muscle(group: StringName) -> float:
	match group:
		&"arms":
			return muscle_arms
		&"torso":
			return muscle_torso
		&"legs":
			return muscle_legs
	return 0.0


func set_muscle(group: StringName, value: float) -> void:
	var clamped := clampf(value, 0.0, MUSCLE_MAX)
	match group:
		&"arms":
			muscle_arms = clamped
		&"torso":
			muscle_torso = clamped
		&"legs":
			muscle_legs = clamped
	muscle_changed.emit()


## Adds growth with diminishing returns near the cap and returns what was actually gained.
func add_muscle(group: StringName, amount: float) -> float:
	var current := get_muscle(group)
	var room := 1.0 - 0.85 * pow(current / MUSCLE_MAX, 1.5)
	var updated := minf(current + amount * room, MUSCLE_MAX)
	set_muscle(group, updated)
	return updated - current


## Girth of a muscle group for the 3D models, 0 (lanky) to 1 (shredded). Early gains show most.
func get_muscle_visual(group: StringName) -> float:
	return pow(get_muscle(group) / MUSCLE_MAX, 0.75)


func add_strength(amount: float) -> void:
	strength += amount
	strength_changed.emit(strength)


func add_max_stamina(amount: float) -> void:
	max_stamina += amount
	stamina_changed.emit(stamina, max_stamina)


# --- Pump ------------------------------------------------------------------------------------

func add_pump(amount: float) -> void:
	pump_level = clampf(pump_level + amount, 0.0, PUMP_MAX)
	if amount > 0.0:
		_pump_grace = PUMP_GRACE
	pump_changed.emit(pump_level)


## Muscle and XP multiplier from the pump, 1.0 to MAX_PUMP_MULTIPLIER.
func get_gain_multiplier() -> float:
	return 1.0 + (MAX_PUMP_MULTIPLIER - 1.0) * pump_level / PUMP_MAX


# --- Stamina ---------------------------------------------------------------------------------

## Spends `amount` and returns true, or returns false when exhausted.
func spend_stamina(amount: float) -> bool:
	if is_exhausted or stamina <= 0.0:
		return false
	stamina = maxf(stamina - amount, 0.0)
	_regen_delay = STAMINA_REGEN_DELAY
	if stamina <= 0.0:
		is_exhausted = true
		exhausted.emit()
	stamina_changed.emit(stamina, max_stamina)
	return true


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, max_stamina)
	if is_exhausted and stamina >= max_stamina * EXHAUSTION_RECOVERY:
		is_exhausted = false
	stamina_changed.emit(stamina, max_stamina)


## Stamina cost of a rep: the pump makes every effort cost more.
func get_effort_cost(base_cost: float) -> float:
	return base_cost * (1.0 + PUMP_STAMINA_DRAIN * pump_level / PUMP_MAX)


func get_stamina_ratio() -> float:
	return stamina / max_stamina


# --- Warm-up and injury ----------------------------------------------------------------------

func is_warmed_up() -> bool:
	return warmup_timer > 0.0


func is_strained() -> bool:
	return injury_timer > 0.0


## Adds warm-up progress (0 to 1). A full bar grants the "Warmed Up" buff for WARMUP_DURATION.
func warm_up(amount: float) -> void:
	warmup_progress += amount
	if warmup_progress >= 1.0:
		warmup_progress = 0.0
		if not is_warmed_up():
			popup_requested.emit("WARMED UP!", &"status")
		warmup_timer = WARMUP_DURATION
	status_changed.emit()


## Applies a muscle strain. `severity` 0 to 1 picks a duration between the two limits.
func apply_strain(severity: float) -> void:
	var duration := lerpf(MIN_STRAIN_DURATION, MAX_STRAIN_DURATION, clampf(severity, 0.0, 1.0))
	injury_timer = maxf(injury_timer, duration)
	add_pump(-pump_level * 0.7)
	if not is_exhausted:
		spend_stamina(max_stamina * 0.2)
	popup_requested.emit("MUSCLE STRAIN!", &"warning")
	injured.emit(injury_timer)
	status_changed.emit()


## Strength available right now: a strain and deep fatigue both take some away.
func get_effective_strength() -> float:
	var value := strength
	if is_strained():
		value *= STRAIN_STRENGTH_FACTOR
	var freshness := clampf(get_stamina_ratio() / FATIGUE_THRESHOLD, 0.0, 1.0)
	return value * lerpf(FATIGUE_STRENGTH_FACTOR, 1.0, freshness)


func get_lift_speed_factor() -> float:
	return STRAIN_SPEED_FACTOR if is_strained() else 1.0


## Multiplier on how fast an overloaded lift turns into an injury.
func get_injury_risk() -> float:
	var risk := 1.0
	if is_warmed_up():
		risk *= WARMUP_RISK_FACTOR
	if get_stamina_ratio() < 0.15:
		risk *= TIRED_RISK_FACTOR
	return risk


## Plain-data copy of every stat, for the fight system and for saving.
func get_snapshot() -> Dictionary:
	return {
		"level": level, "xp": xp, "rank": rank_title, "days": get_days(),
		"strength": strength, "stamina": stamina, "max_stamina": max_stamina,
		"muscle_arms": muscle_arms, "muscle_torso": muscle_torso, "muscle_legs": muscle_legs,
		"pump_level": pump_level, "warmed_up": is_warmed_up(), "strained": is_strained(),
	}


func _tick_stamina(delta: float) -> void:
	if _regen_delay > 0.0:
		_regen_delay -= delta
	elif stamina < max_stamina:
		restore_stamina(max_stamina * STAMINA_REGEN * delta)


func _tick_pump(delta: float) -> void:
	if _pump_grace > 0.0:
		_pump_grace -= delta
	elif pump_level > 0.0:
		pump_level = maxf(pump_level - PUMP_DECAY * delta, 0.0)
		pump_changed.emit(pump_level)


func _tick_status(delta: float) -> void:
	if warmup_timer > 0.0:
		warmup_timer -= delta
		if warmup_timer <= 0.0:
			warmup_timer = 0.0
			popup_requested.emit("Warm-up wore off", &"warning")
			status_changed.emit()
	if injury_timer > 0.0:
		injury_timer -= delta * (REST_RECOVERY_FACTOR if resting else 1.0)
		if injury_timer <= 0.0:
			injury_timer = 0.0
			popup_requested.emit("Strain healed", &"status")
			status_changed.emit()


static func _roman(number: int) -> String:
	var values: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var text := ""
	var rest := number
	for i in values.size():
		while rest >= values[i]:
			text += symbols[i]
			rest -= values[i]
	return text

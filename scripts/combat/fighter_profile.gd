class_name FighterProfile
extends RefCounted
## Everything that makes one opponent: the fight card details, stats, temperament, looks and
## purse. FighterRoster builds the ladder and the Endless League challengers from these.

var id: StringName = &""
var fighter_name := "Fighter"
var level := 1
## Rank title and gym tenure, shown on the overhead tag and the fight card.
var rank := "Skinny Rookie"
var tenure := "First Week"
## One line of scouting for the fight card.
var blurb := ""
## Position on the ladder (0 is the weakest), or -1 for an Endless League challenger.
var ladder_index := -1

# Stats.
var max_health := 70.0
var max_stamina := 100.0
## Damage of a jab; heavier strikes multiply it.
var damage := 5.0
var guard_max := 30.0
## Guard meter restored per second once the fighter has gone a moment without being hit.
var guard_regen := 10.0
## Share of a blocked strike's damage that the guard stops.
var block_power := 0.75
## Damage one strike needs to knock this fighter out of a wind-up.
var poise := 4.0
## Seconds after shaking off a stagger in which the fighter cannot be staggered or interrupted
## again. Stops endless stun-locks: the better the fighter, the sooner they hit back.
var composure := 0.5

# Temperament.
var move_speed := 1.6
## Distance the fighter likes to keep.
var preferred_range := 1.55
## Seconds between attacks (min, max).
var attack_delay := Vector2(1.8, 2.8)
## Multiplier on every wind-up: above 1 is slow and easy to read.
var telegraph := 1.0
## Multiplier on the recovery after a strike: above 1 leaves a counter opening.
var recovery := 1.0
## Strikes this fighter throws. Repeat a kind to make it more likely.
var moves: Array[StringName] = [Strike.JAB]
## Strikes per attack (min, max).
var combo_size := Vector2i(1, 1)
## Share of the time spent behind a raised guard.
var guard_uptime := 0.0
## Chance to cover up after taking a clean hit.
var block_reaction := 0.1
## Chance to answer a second blocked punch with a fast counter.
var counter_chance := 0.0
## Chance to sell one wind-up and throw something else.
var feint_chance := 0.0
## Sideways footwork, 0 (flat-footed) to 1.
var circling := 0.0
## Chance to back away after attacking.
var retreat := 0.0
## Keeps walking forward instead of holding range.
var pressure := false
## Shaky hands and a low guard, 0 to 1.
var nerves := 0.0
## Bounce in the step, 0 to 1.
var bounce := 0.0

# Looks.
## Height multiplier of the body.
var height := 1.0
## Arm, torso and leg girth, each 0 (lanky) to 1 (shredded).
var build := Vector3.ZERO
var skin := Color(0.96, 0.76, 0.62)
var hair := Color(0.26, 0.16, 0.1)
var shorts := Color(0.13, 0.15, 0.22)
## Worn unless `bare_chest`.
var shirt := Color(0.85, 0.86, 0.9)
var bare_chest := true
var gloves := Color(0.85, 0.15, 0.15)

# Purse for a first win.
var cash := 50
var xp := 100.0


## "LVL 3 | Gym Regular | 2 Months"
func get_tag() -> String:
	return PlayerStats.format_tag(level, rank, tenure)


func is_league() -> bool:
	return ladder_index < 0

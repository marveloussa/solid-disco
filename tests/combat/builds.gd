extends RefCounted
## Career builds for bout simulations: the stats a player has once training (paid out through
## the game's own `PlayerStats.reward_rep`) and the earlier ladder wins carry them to `level`.

## Focus, strength weight and stamina growth of a rep on the bench, squat rack, deadlift
## platform, dumbbells, treadmill and push-up mat, as the stations pay them.
const CIRCUIT := [
	[{&"torso": 1.0, &"arms": 0.5}, 1.0, 0.0],
	[{&"legs": 1.0, &"torso": 0.3}, 1.0, 0.0],
	[{&"legs": 0.6, &"torso": 0.6, &"arms": 0.2}, 1.2, 0.0],
	[{&"arms": 0.6}, 0.2, 0.0],
	[{&"legs": 0.5}, 0.0, 0.3],
	[{&"torso": 0.45, &"arms": 0.35}, 0.3, 0.15],
]
const SET_SIZE := 8
## A modest pump and load, one perfect rep in four.
const PUMP := 40.0
const INTENSITY := 0.9


## Trains a fresh career to `level` after `wins` ladder wins and returns the resulting stats.
static func train_to(level: int, wins: int) -> Dictionary:
	PlayerStats.reset_career()
	var ladder := FighterRoster.ladder()
	for i in mini(wins, ladder.size()):
		PlayerStats.add_xp(ladder[i].xp)
	var rep := 0
	while PlayerStats.level < level and rep < 50000:
		var row: Array = CIRCUIT[(rep / SET_SIZE) % CIRCUIT.size()]
		PlayerStats.pump_level = PUMP
		PlayerStats.reward_rep(row[0], INTENSITY, rep % 4 == 0, row[1], row[2])
		rep += 1
	return {
		"level": maxi(PlayerStats.level, level),
		"reps": rep,
		"strength": PlayerStats.strength,
		"max_stamina": PlayerStats.max_stamina,
		"arms": PlayerStats.muscle_arms,
		"torso": PlayerStats.muscle_torso,
		"legs": PlayerStats.muscle_legs,
	}


## Puts the career back on `build`, rested, before a bout.
static func apply(build: Dictionary, wins: int) -> void:
	PlayerStats.reset_career()
	PlayerStats.level = build["level"]
	PlayerStats.strength = build["strength"]
	PlayerStats.max_stamina = build["max_stamina"]
	PlayerStats.stamina = PlayerStats.max_stamina
	PlayerStats.set_muscle(&"arms", build["arms"])
	PlayerStats.set_muscle(&"torso", build["torso"])
	PlayerStats.set_muscle(&"legs", build["legs"])
	PlayerStats.ladder_progress = mini(wins, FighterRoster.LADDER_SIZE)

class_name FighterRoster
extends RefCounted
## The opponents. Five ladder fighters from weakest to strongest, each with a body and a
## temperament that match the tier, then the Endless Championship League: a new, seeded
## challenger for every level from 16 up, with scaling stats and purses.
##
## Progress lives in PlayerStats (`ladder_progress`, `league_wins`).

const LADDER_SIZE := 5
const BOSS_LEVEL := 15
const LEAGUE_START_LEVEL := 16
## Share of the purse and XP paid for beating someone again.
const REMATCH_SHARE := 0.5

const _PREFIXES := [
	["Rapid", "Flash", "Turbo", "Whirlwind", "Buzzsaw"],
	["Granite", "Hammer", "Big", "Sledge", "Bulldozer"],
	["Slick", "Cold", "Patient", "Sly", "Shadow"],
	["Golden", "Savage", "Royal", "Prime", "Iron"],
]
const _NAMES := ["Rico", "Greg", "Sven", "Dante", "Hugo", "Malik", "Yuri", "Tomas", "Kenji", "Andre", "Luca", "Omar", "Felix", "Diego", "Niko", "Bruno"]
const _STYLE_BLURBS := [
	"Swarmer. Non-stop volume: weather the flurry, then answer.",
	"Slugger. Heavy hands and a slow recovery: slip one and counter.",
	"Counter-striker. Lives behind a high guard: bring the Guard Breaker.",
	"Technician. Feints and mixed combinations, no easy openings.",
]


static func ladder() -> Array[FighterProfile]:
	return [_sam(), _carl(), _boris(), _viktor(), _champ()]


static func is_league_open() -> bool:
	return PlayerStats.ladder_progress >= LADDER_SIZE


## Level of the next Endless League challenger.
static func next_league_level() -> int:
	return LEAGUE_START_LEVEL + PlayerStats.league_wins


## The player may fight this opponent now.
static func is_unlocked(profile: FighterProfile) -> bool:
	if profile.is_league():
		return is_league_open() and profile.level <= next_league_level()
	return profile.ladder_index <= PlayerStats.ladder_progress


## The player has already beaten this opponent.
static func is_beaten(profile: FighterProfile) -> bool:
	if profile.is_league():
		return profile.level < next_league_level()
	return profile.ladder_index < PlayerStats.ladder_progress


## Who comes after `profile` once it is beaten, or null if nobody is unlocked yet.
static func next_after(profile: FighterProfile) -> FighterProfile:
	if not profile.is_league() and profile.ladder_index + 1 < LADDER_SIZE:
		var next := ladder()[profile.ladder_index + 1]
		return next if is_unlocked(next) else null
	return league_challenger(next_league_level()) if is_league_open() else null


## Endless League challenger for `level` (16 and up). The same level always gives the same
## fighter, so a rematch is against the opponent who beat you.
static func league_challenger(level: int) -> FighterProfile:
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * level + 7919
	var tier := maxi(level - BOSS_LEVEL, 1)
	var style := rng.randi_range(0, 3)
	var fighter := FighterProfile.new()
	fighter.id = StringName("league_%d" % level)
	var prefixes: Array = _PREFIXES[style]
	fighter.fighter_name = "%s %s" % [prefixes[rng.randi_range(0, prefixes.size() - 1)], _NAMES[rng.randi_range(0, _NAMES.size() - 1)]]
	fighter.level = level
	fighter.rank = "League Contender" if tier < 5 else PlayerStats.get_rank_for(level)
	fighter.tenure = "%d Years" % (3 + tier / 2)
	fighter.blurb = _STYLE_BLURBS[style]

	fighter.max_health = 820.0 + 80.0 * tier
	fighter.max_stamina = 220.0 + 10.0 * tier
	fighter.damage = 12.5 + 0.85 * tier
	fighter.guard_max = 90.0 + 6.0 * tier
	fighter.guard_regen = 18.0
	fighter.block_power = 0.82
	fighter.poise = 14.0 + tier
	fighter.composure = minf(2.0 + 0.04 * tier, 2.8)
	# Wind-ups tighten with the level but never below what a player can read.
	fighter.telegraph = maxf(0.66, 0.9 - 0.012 * tier)
	fighter.preferred_range = 1.5
	match style:
		0:
			fighter.max_health *= 0.9
			fighter.damage *= 0.85
			fighter.move_speed = 2.8
			fighter.attack_delay = Vector2(0.6, 1.1)
			fighter.moves = [Strike.JAB, Strike.JAB, Strike.CROSS, Strike.HOOK]
			fighter.combo_size = Vector2i(2, 4)
			fighter.guard_uptime = 0.1
			fighter.block_reaction = 0.2
			fighter.recovery = 0.9
			fighter.circling = 0.9
			fighter.bounce = 1.0
		1:
			fighter.max_health *= 1.15
			fighter.damage *= 1.15
			fighter.poise += 8.0
			fighter.telegraph += 0.25
			fighter.move_speed = 1.6
			fighter.preferred_range = 1.35
			fighter.attack_delay = Vector2(0.8, 1.4)
			fighter.moves = [Strike.HOOK, Strike.OVERHAND, Strike.CROSS, Strike.UPPERCUT]
			fighter.combo_size = Vector2i(1, 2)
			fighter.recovery = 1.7
			fighter.pressure = true
		2:
			fighter.guard_max *= 1.4
			fighter.guard_regen = 30.0
			fighter.block_power = 0.88
			fighter.move_speed = 1.9
			fighter.attack_delay = Vector2(1.8, 2.8)
			fighter.moves = [Strike.CROSS, Strike.JAB, Strike.UPPERCUT]
			fighter.combo_size = Vector2i(1, 2)
			fighter.guard_uptime = 0.9
			fighter.block_reaction = 0.9
			fighter.counter_chance = 0.8
			fighter.circling = 0.35
		_:
			fighter.move_speed = 2.4
			fighter.attack_delay = Vector2(0.7, 1.3)
			fighter.moves = [Strike.JAB, Strike.JAB, Strike.CROSS, Strike.HOOK, Strike.UPPERCUT, Strike.KICK]
			fighter.combo_size = Vector2i(2, 4)
			fighter.guard_uptime = 0.5
			fighter.block_reaction = 0.55
			fighter.counter_chance = 0.35
			fighter.feint_chance = 0.35
			fighter.circling = 0.55
			fighter.bounce = 0.5

	# Sluggers are thick, swarmers lean; everyone at this level is built.
	var bulk := 0.85 if style == 1 else (0.55 if style == 0 else 0.7)
	fighter.build = Vector3(clampf(bulk + rng.randf_range(-0.1, 0.15), 0.0, 1.0), clampf(bulk + rng.randf_range(-0.1, 0.15), 0.0, 1.0), clampf(bulk + rng.randf_range(-0.15, 0.1), 0.0, 1.0))
	fighter.height = rng.randf_range(0.96, 1.12)
	fighter.skin = Color(0.98, 0.84, 0.74).lerp(Color(0.42, 0.28, 0.2), rng.randf())
	fighter.hair = Color.from_hsv(rng.randf_range(0.02, 0.12), rng.randf_range(0.2, 0.8), rng.randf_range(0.05, 0.6))
	var hue := rng.randf()
	fighter.shorts = Color.from_hsv(hue, 0.75, 0.85)
	fighter.gloves = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 0.9)

	fighter.cash = 1200 + 160 * tier
	fighter.xp = 2400.0 + 280.0 * tier
	return fighter


static func _sam() -> FighterProfile:
	var fighter := FighterProfile.new()
	fighter.id = &"sam"
	fighter.ladder_index = 0
	fighter.fighter_name = "Skinny Sam"
	fighter.level = 1
	fighter.rank = "Skinny Rookie"
	fighter.tenure = "First Week"
	fighter.blurb = "Nervous. Slow, telegraphed single jabs, then he backs off."
	fighter.max_health = 150.0
	fighter.max_stamina = 70.0
	fighter.damage = 5.0
	fighter.guard_max = 25.0
	fighter.guard_regen = 8.0
	fighter.block_power = 0.7
	fighter.poise = 0.0
	fighter.composure = 0.3
	fighter.move_speed = 1.3
	fighter.preferred_range = 1.6
	fighter.attack_delay = Vector2(1.9, 3.0)
	fighter.telegraph = 1.7
	fighter.recovery = 1.5
	fighter.moves = [Strike.JAB]
	fighter.guard_uptime = 0.05
	fighter.block_reaction = 0.15
	fighter.retreat = 0.7
	fighter.nerves = 1.0
	fighter.height = 1.07
	fighter.build = Vector3(0.02, 0.03, 0.04)
	fighter.skin = Color(0.98, 0.84, 0.74)
	fighter.hair = Color(0.78, 0.45, 0.18)
	fighter.shorts = Color(0.25, 0.4, 0.75)
	fighter.bare_chest = false
	fighter.gloves = Color(0.9, 0.2, 0.2)
	fighter.cash = 60
	fighter.xp = 110.0
	return fighter


static func _carl() -> FighterProfile:
	var fighter := FighterProfile.new()
	fighter.id = &"carl"
	fighter.ladder_index = 1
	fighter.fighter_name = "Cardio Carl"
	fighter.level = 3
	fighter.rank = "Gym Regular"
	fighter.tenure = "2 Months"
	fighter.blurb = "Light on his feet. Rapid jabs in bunches, rarely blocks."
	fighter.max_health = 260.0
	fighter.max_stamina = 160.0
	fighter.damage = 5.5
	fighter.guard_max = 30.0
	fighter.block_power = 0.7
	fighter.poise = 5.0
	fighter.composure = 0.8
	fighter.move_speed = 2.7
	fighter.preferred_range = 1.6
	fighter.attack_delay = Vector2(0.8, 1.5)
	fighter.telegraph = 0.82
	fighter.recovery = 0.9
	fighter.moves = [Strike.JAB, Strike.JAB, Strike.JAB, Strike.CROSS]
	fighter.combo_size = Vector2i(2, 3)
	fighter.guard_uptime = 0.05
	fighter.block_reaction = 0.1
	fighter.circling = 0.9
	fighter.retreat = 0.35
	fighter.bounce = 1.0
	fighter.build = Vector3(0.22, 0.2, 0.45)
	fighter.skin = Color(0.82, 0.62, 0.46)
	fighter.hair = Color(0.1, 0.1, 0.1)
	fighter.shorts = Color(0.2, 0.85, 0.5)
	fighter.gloves = Color(0.2, 0.85, 0.5)
	fighter.cash = 130
	fighter.xp = 260.0
	return fighter


static func _boris() -> FighterProfile:
	var fighter := FighterProfile.new()
	fighter.id = &"boris"
	fighter.ladder_index = 2
	fighter.fighter_name = "Brawler Boris"
	fighter.level = 6
	fighter.rank = "Lean Grinder"
	fighter.tenure = "6 Months"
	fighter.blurb = "Walks you down with heavy hooks. Slip one and punish the opening."
	fighter.max_health = 430.0
	fighter.max_stamina = 120.0
	fighter.damage = 8.5
	fighter.guard_max = 45.0
	fighter.guard_regen = 8.0
	fighter.block_power = 0.7
	fighter.poise = 16.0
	fighter.composure = 1.2
	fighter.move_speed = 1.45
	fighter.preferred_range = 1.35
	fighter.attack_delay = Vector2(0.9, 1.6)
	fighter.telegraph = 1.25
	fighter.recovery = 1.9
	fighter.moves = [Strike.HOOK, Strike.HOOK, Strike.OVERHAND, Strike.CROSS]
	fighter.combo_size = Vector2i(1, 2)
	fighter.block_reaction = 0.12
	fighter.pressure = true
	fighter.height = 0.98
	fighter.build = Vector3(0.62, 0.78, 0.55)
	fighter.skin = Color(0.9, 0.68, 0.55)
	fighter.hair = Color(0.35, 0.2, 0.1)
	fighter.shorts = Color(0.75, 0.12, 0.12)
	fighter.gloves = Color(0.1, 0.1, 0.12)
	fighter.cash = 280
	fighter.xp = 560.0
	return fighter


static func _viktor() -> FighterProfile:
	var fighter := FighterProfile.new()
	fighter.id = &"viktor"
	fighter.ladder_index = 3
	fighter.fighter_name = "Counter-King Viktor"
	fighter.level = 10
	fighter.rank = "Shredded Prospect"
	fighter.tenure = "1 Year"
	fighter.blurb = "Tight high guard, punishes spam. Break it with Jab, Jab, Cross."
	fighter.max_health = 560.0
	fighter.max_stamina = 170.0
	fighter.damage = 10.5
	fighter.guard_max = 120.0
	fighter.guard_regen = 30.0
	fighter.block_power = 0.88
	fighter.poise = 11.0
	fighter.composure = 1.6
	fighter.move_speed = 1.9
	fighter.preferred_range = 1.5
	fighter.attack_delay = Vector2(2.2, 3.4)
	fighter.telegraph = 0.95
	fighter.moves = [Strike.CROSS, Strike.JAB, Strike.UPPERCUT]
	fighter.combo_size = Vector2i(1, 2)
	fighter.guard_uptime = 0.92
	fighter.block_reaction = 0.9
	fighter.counter_chance = 0.8
	fighter.circling = 0.35
	fighter.height = 1.03
	fighter.build = Vector3(0.72, 0.72, 0.68)
	fighter.skin = Color(0.72, 0.52, 0.38)
	fighter.hair = Color(0.05, 0.05, 0.07)
	fighter.shorts = Color(0.08, 0.08, 0.1)
	fighter.gloves = Color(0.95, 0.75, 0.15)
	fighter.cash = 550
	fighter.xp = 1100.0
	return fighter


static func _champ() -> FighterProfile:
	var fighter := FighterProfile.new()
	fighter.id = &"champ"
	fighter.ladder_index = 4
	fighter.fighter_name = "The Iron Champ"
	fighter.level = BOSS_LEVEL
	fighter.rank = "Gym Boss"
	fighter.tenure = "3 Years"
	fighter.blurb = "Feints, fast combinations, deep gas tank. Everything at once."
	fighter.max_health = 820.0
	fighter.max_stamina = 240.0
	fighter.damage = 12.5
	fighter.guard_max = 95.0
	fighter.guard_regen = 18.0
	fighter.block_power = 0.82
	fighter.poise = 20.0
	fighter.composure = 2.0
	fighter.move_speed = 2.4
	fighter.preferred_range = 1.5
	fighter.attack_delay = Vector2(0.7, 1.4)
	fighter.telegraph = 0.85
	fighter.recovery = 0.95
	fighter.moves = [Strike.JAB, Strike.JAB, Strike.CROSS, Strike.HOOK, Strike.UPPERCUT, Strike.KICK]
	fighter.combo_size = Vector2i(2, 4)
	fighter.guard_uptime = 0.5
	fighter.block_reaction = 0.55
	fighter.counter_chance = 0.35
	fighter.feint_chance = 0.3
	fighter.circling = 0.55
	fighter.bounce = 0.5
	fighter.height = 1.1
	fighter.build = Vector3(1.0, 1.0, 0.95)
	fighter.skin = Color(0.6, 0.42, 0.3)
	fighter.hair = Color(0.06, 0.05, 0.05)
	fighter.shorts = Color(0.95, 0.78, 0.2)
	fighter.gloves = Color(0.07, 0.07, 0.08)
	fighter.cash = 1200
	fighter.xp = 2400.0
	return fighter

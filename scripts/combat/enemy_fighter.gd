class_name EnemyFighter
extends CharacterBody3D
## An opponent in the cage: a CharacterModel body shaped by its FighterProfile, a hurtbox the
## player strikes, an overhead tag and a small state machine for the AI.
##
## Every attack is readable: the fighter pulls the arm or knee back, a "!" pops over the head
## and the glove glows for the whole wind-up before the blow is thrown, so blocking and
## slipping are fair. Temperament (pressure, counters, feints, nerves) comes from the profile.

signal health_changed(current: float, maximum: float)
signal guard_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal defeated

enum State { IDLE, FOOTWORK, WINDUP, STRIKE, RECOVER, STAGGER, DOWN, VICTORY }

## `power` multiplies the profile's damage. `windup` (before the profile's telegraph factor),
## `strike` and `recover` are seconds; `reach` is centre to centre.
const MOVES := {
	Strike.JAB: {"power": 1.0, "windup": 0.42, "strike": 0.09, "recover": 0.34, "reach": 1.8, "cost": 5.0, "knockback": 0.6, "heavy": false},
	Strike.CROSS: {"power": 1.6, "windup": 0.55, "strike": 0.1, "recover": 0.45, "reach": 1.85, "cost": 8.0, "knockback": 1.4, "heavy": true},
	Strike.HOOK: {"power": 2.0, "windup": 0.66, "strike": 0.11, "recover": 0.55, "reach": 1.65, "cost": 10.0, "knockback": 1.8, "heavy": true},
	Strike.UPPERCUT: {"power": 1.8, "windup": 0.6, "strike": 0.1, "recover": 0.5, "reach": 1.5, "cost": 9.0, "knockback": 1.0, "heavy": true},
	Strike.OVERHAND: {"power": 2.4, "windup": 0.8, "strike": 0.12, "recover": 0.7, "reach": 1.8, "cost": 12.0, "knockback": 2.2, "heavy": true},
	Strike.KICK: {"power": 1.5, "windup": 0.7, "strike": 0.12, "recover": 0.6, "reach": 2.15, "cost": 11.0, "knockback": 5.0, "heavy": true},
}
## No wind-up is ever shorter than this, whatever the profile says.
const MIN_WINDUP := 0.28
## Half-angle in front of the fighter that a strike covers.
const STRIKE_CONE := 0.7
const TURN_SPEED := 7.0
const STAMINA_REGEN := 9.0
## Below this share of stamina the fighter is gassed: slower, weaker, guard down.
const TIRED := 0.2
const GUARD_BREAK_STAGGER := 1.5
const FALL_TIME := 0.55
const LIGHT_CUE := Color(1.0, 0.86, 0.3)
const HEAVY_CUE := Color(1.0, 0.32, 0.25)
## Size of the "!" cue (it keeps the same size on screen at any distance).
const CUE_SIZE := 0.0011

var profile: FighterProfile
var state := State.IDLE
var health := 1.0
var guard := 1.0
var stamina := 1.0
var target: Player = null

var _animator := FightAnimator.new()
var _glove_materials: Array[StandardMaterial3D] = []
var _state_time := 0.0
var _centre := Vector3.ZERO
var _radius := 0.0
var _knock := Vector3.ZERO
var _stride := 0.0
var _move_amount := 0.0
var _attack_timer := 1.0
var _combo_left := 0
var _move: Dictionary = {}
var _move_kind: StringName = Strike.JAB
var _move_side := 0
var _windup_time := 0.5
var _recover_time := 0.4
var _feint := false
var _stagger_time := 0.0
var _composure_left := 0.0
var _guard_up := false
var _guard_timer := 0.0
var _since_hit := 10.0
var _blocked_recently := 0
var _blocked_timer := 0.0
var _retreat_time := 0.0
var _strafe_time := 0.0
var _strafe_direction := 1.0
var _cue_tween: Tween

@onready var model: CharacterModel = $Model
@onready var hurtbox: CombatTarget = $Hurtbox
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var name_tag: Label3D = $NameTag
@onready var telegraph: Label3D = $Telegraph


## Call before adding the fighter to the tree: the body takes its colours when it is built.
func setup(fighter: FighterProfile) -> void:
	profile = fighter
	health = fighter.max_health
	guard = fighter.guard_max
	stamina = fighter.max_stamina
	var body: CharacterModel = $Model
	body.render_layers = 1
	body.skin_color = fighter.skin
	body.shirt_color = fighter.skin if fighter.bare_chest else fighter.shirt
	body.shorts_color = fighter.shorts
	# Barefoot, like everyone in the cage.
	body.shoe_color = fighter.skin
	body.hair_color = fighter.hair
	body.scale = Vector3(1.0, fighter.height, 1.0)
	body.set_physique(fighter.build.x, fighter.build.y, fighter.build.z)


func _ready() -> void:
	if profile == null:
		setup(FighterProfile.new())
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	model.fight_pose = _animator.pose
	model.fight_blend = 1.0
	_animator.nerves = profile.nerves
	_animator.bounce = profile.bounce
	for i in 2:
		# Each glove has its own material so it can glow through a wind-up.
		var material := StandardMaterial3D.new()
		material.albedo_color = profile.gloves
		material.roughness = 0.5
		material.emission_enabled = true
		material.emission = HEAVY_CUE
		material.emission_energy_multiplier = 0.0
		FightGear.glove(model.get_hand(i), material, Color(0.95, 0.95, 0.97))
		_glove_materials.append(material)
	name_tag.text = "%s\n%s" % [profile.fighter_name.to_upper(), profile.get_tag()]
	name_tag.position.y = 1.95 * profile.height + 0.42
	telegraph.position.y = 1.95 * profile.height + 0.16
	telegraph.visible = false
	hurtbox.struck.connect(_on_struck)
	_attack_timer = randf_range(profile.attack_delay.x, profile.attack_delay.y) * 0.5


## Keeps the fighter inside a circular arena: `arena_centre` is in world space, on the canvas.
func set_arena(arena_centre: Vector3, arena_radius: float) -> void:
	_centre = arena_centre
	_radius = arena_radius


## Starts fighting `opponent`. Until then the fighter stands in its guard.
func begin(opponent: Player) -> void:
	target = opponent
	_enter(State.FOOTWORK)


## The opponent is down: stop fighting and raise the arms.
func celebrate() -> void:
	if state == State.DOWN:
		return
	_end_attack()
	_enter(State.VICTORY)


func is_guarding() -> bool:
	return _guard_up and state == State.FOOTWORK and guard > 0.0


## Turns to face a world position at once.
func face(point: Vector3) -> void:
	var toward := point - global_position
	if Vector2(toward.x, toward.z).length() > 0.01:
		rotation.y = atan2(-toward.x, -toward.z)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_tick_meters(delta)
	var move := Vector3.ZERO
	match state:
		State.FOOTWORK:
			move = _footwork(delta)
		State.WINDUP:
			move = _wind_up(delta)
		State.STRIKE:
			move = _throw()
		State.RECOVER:
			_recover()
		State.STAGGER:
			if _state_time >= _stagger_time:
				_shake_it_off()
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))
	velocity = move + _knock
	move_and_slide()
	_confine()
	_animate(delta)


# --- Footwork --------------------------------------------------------------------------------

func _footwork(delta: float) -> Vector3:
	var offset := _to_target()
	var distance := offset.length()
	var toward := offset / maxf(distance, 0.001)
	_turn(toward, delta)
	_think_guard(delta)

	var speed := profile.move_speed * (0.6 if _is_tired() else 1.0)
	var hold := profile.preferred_range
	var move := Vector3.ZERO
	if _retreat_time > 0.0:
		_retreat_time -= delta
		move -= toward * speed
	elif distance > hold + 0.15:
		move += toward * speed
	elif distance < hold - 0.35 and not profile.pressure:
		move -= toward * speed * 0.7
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = randf_range(0.9, 2.2)
		if randf() < 0.6:
			_strafe_direction = -_strafe_direction
	if profile.circling > 0.0 and distance < hold + 1.0:
		move += toward.cross(Vector3.UP) * _strafe_direction * speed * 0.6 * profile.circling
	if _guard_up:
		move *= 0.6

	if distance <= hold + 0.45:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_combo_left = randi_range(profile.combo_size.x, profile.combo_size.y)
			_begin_windup(_pick_move(), 1.0)
	return move


func _think_guard(delta: float) -> void:
	_guard_timer -= delta
	if _guard_timer > 0.0:
		return
	_guard_timer = randf_range(0.8, 1.6)
	var uptime := profile.guard_uptime * (0.4 if _is_tired() else 1.0)
	# A broken guard has to rebuild before it goes back up.
	_guard_up = guard > profile.guard_max * 0.25 and randf() < uptime


func _pick_move() -> StringName:
	var kind: StringName = profile.moves.pick_random()
	return kind


# --- Attacking -------------------------------------------------------------------------------

## Starts the telegraphed wind-up of `kind`. `haste` below 1 shortens it (follow-ups, counters).
func _begin_windup(kind: StringName, haste: float) -> void:
	_move_kind = kind
	_move = MOVES[kind]
	_move_side = 0 if kind == Strike.JAB or kind == Strike.HOOK else 1
	var windup: float = _move["windup"]
	windup *= profile.telegraph * haste
	if _is_tired():
		windup *= 1.3
	_windup_time = maxf(windup, MIN_WINDUP)
	_feint = haste >= 1.0 and randf() < profile.feint_chance
	_guard_up = false
	var cost: float = _move["cost"]
	_set_stamina(stamina - cost)
	_show_cue(_move["heavy"])
	_enter(State.WINDUP)


func _wind_up(delta: float) -> Vector3:
	var offset := _to_target()
	var distance := offset.length()
	var toward := offset / maxf(distance, 0.001)
	var progress := _state_time / _windup_time
	# Tracks the target until the blow is committed; a late sidestep makes it miss.
	if progress < 0.7:
		_turn(toward, delta)
	_animator.set_strike(_move_kind, _move_side, progress / 0.6, 0.0)
	_glow(_move_side, clampf(progress * 1.5, 0.0, 1.0))
	if _feint and progress >= 0.55:
		# Sold the wind-up; now throw something else.
		var other := _pick_move()
		if other == _move_kind:
			other = Strike.CROSS if _move_kind != Strike.CROSS else Strike.JAB
		_glow(_move_side, 0.0)
		_begin_windup(other, 0.85)
		return Vector3.ZERO
	if progress >= 1.0:
		_enter(State.STRIKE)
	var reach: float = _move["reach"]
	return toward * profile.move_speed * 0.5 if distance > reach - 0.25 else Vector3.ZERO


func _throw() -> Vector3:
	var duration: float = _move["strike"]
	var progress := _state_time / duration
	_animator.set_strike(_move_kind, _move_side, 1.0, progress)
	if progress >= 1.0:
		_land()
	# Steps into the blow.
	return -global_transform.basis.z * 1.6


## The moment of impact: hands the strike to the player and reads back what happened.
func _land() -> void:
	var offset := _to_target()
	var distance := offset.length()
	var toward := offset / maxf(distance, 0.001)
	var power: float = _move["power"]
	var reach: float = _move["reach"]
	var strike := Strike.new()
	strike.kind = _move_kind
	strike.side = _move_side
	strike.attacker = self
	strike.damage = profile.damage * power * randf_range(0.92, 1.08) * (0.75 if _is_tired() else 1.0)
	strike.heavy = _move["heavy"]
	strike.knockback = _move["knockback"]
	strike.direction = toward
	var in_reach := distance <= reach and (-global_transform.basis.z).angle_to(toward) <= STRIKE_CONE
	target.combat.receive_strike(strike, in_reach)

	_combo_left -= 1
	var recover: float = _move["recover"]
	recover *= profile.recovery
	match strike.outcome:
		Strike.Outcome.MISS, Strike.Outcome.DODGED:
			# A whiff hangs the arm out: the counter opening.
			recover = recover * 1.35 + (0.3 if strike.perfect else 0.0)
			_combo_left = 0
		Strike.Outcome.BLOCKED:
			pass
		_:
			recover *= 0.85
	if _combo_left > 0:
		recover = 0.16
	_recover_time = recover
	_hide_cue()
	_enter(State.RECOVER)


func _recover() -> void:
	_animator.set_strike(_move_kind, _move_side, 0.0, 1.0 - _state_time / _recover_time)
	if _state_time < _recover_time:
		return
	_animator.clear_strike()
	if _combo_left > 0:
		_begin_windup(_pick_move(), 0.7)
		return
	_attack_timer = randf_range(profile.attack_delay.x, profile.attack_delay.y) * (1.4 if _is_tired() else 1.0)
	if randf() < profile.retreat:
		_retreat_time = 0.7
	_enter(State.FOOTWORK)


func _end_attack() -> void:
	_animator.clear_strike()
	_combo_left = 0
	_feint = false
	_hide_cue()


# --- Getting hit -----------------------------------------------------------------------------

func _on_struck(strike: Strike) -> void:
	if state == State.DOWN or state == State.IDLE or state == State.VICTORY:
		return
	_since_hit = 0.0
	var open := state == State.STAGGER
	# Just out of a stagger: takes the damage but will not be rocked or interrupted again yet.
	var steady := _composure_left > 0.0
	var broke := false
	if is_guarding():
		_blocked_recently += 1
		_blocked_timer = 1.2
		if strike.guard_breaker and not steady:
			guard = 0.0
		else:
			guard = maxf(guard - strike.guard_damage * (2.0 if strike.guard_breaker else 1.0), 0.0)
		guard_changed.emit(guard, profile.guard_max)
		if guard <= 0.0:
			broke = true
			strike.outcome = Strike.Outcome.GUARD_BREAK
			strike.dealt = strike.damage * 0.6
		else:
			strike.outcome = Strike.Outcome.BLOCKED
			strike.dealt = strike.damage * (1.0 - profile.block_power)
	else:
		strike.outcome = Strike.Outcome.HIT
		strike.dealt = strike.damage * (1.25 if open else 1.0)

	var blocked := strike.outcome == Strike.Outcome.BLOCKED
	health = maxf(health - strike.dealt, 0.0)
	health_changed.emit(health, profile.max_health)
	if strike.stamina_drain > 0.0:
		_set_stamina(stamina - strike.stamina_drain * (0.5 if blocked else 1.0))
	_knock += strike.direction * strike.knockback * (0.35 if blocked else 1.0)
	if health <= 0.0:
		strike.outcome = Strike.Outcome.KNOCKOUT
		_go_down(strike)
		return

	# The player's left hand lands on this fighter's right side.
	var across := 1.0 if strike.side == 0 else -1.0
	if broke:
		_stagger(GUARD_BREAK_STAGGER)
	elif blocked:
		_animator.flinch(0.25)
		# Punishes a second punch thrown into the guard.
		if _blocked_recently >= 2 and randf() < profile.counter_chance:
			_blocked_recently = 0
			_combo_left = 1
			_begin_windup(Strike.CROSS, 0.62)
	else:
		_animator.flinch(clampf(0.4 + strike.dealt / 25.0, 0.0, 1.0), across)
		if steady:
			pass
		elif strike.counter or strike.combo == Strike.KO_FINISHER:
			_stagger(0.7)
		elif strike.guard_breaker:
			_stagger(0.6)
		elif state == State.WINDUP and strike.dealt >= profile.poise:
			# Beaten to the punch.
			_stagger(0.35)
		elif state == State.FOOTWORK and guard > 0.0 and not _is_tired() and randf() < profile.block_reaction:
			_guard_up = true
			_guard_timer = 1.2


## Back in the fight after a stagger: steady for a moment, guard rebuilt, and looking to hit back.
func _shake_it_off() -> void:
	_composure_left = profile.composure
	_attack_timer = randf_range(0.2, 0.6)
	if guard < profile.guard_max * 0.6:
		guard = profile.guard_max * 0.6
		guard_changed.emit(guard, profile.guard_max)
	_enter(State.FOOTWORK)


func _stagger(seconds: float) -> void:
	var left := _stagger_time - _state_time if state == State.STAGGER else 0.0
	_end_attack()
	_guard_up = false
	_stagger_time = maxf(seconds, left)
	_enter(State.STAGGER)


func _go_down(strike: Strike) -> void:
	_end_attack()
	_guard_up = false
	# Falls away from the blow that finished it.
	face(global_position - strike.direction)
	_knock += strike.direction * 2.5
	hurtbox.enabled = false
	collision_shape.set_deferred(&"disabled", true)
	_enter(State.DOWN)
	defeated.emit()


# --- Helpers ---------------------------------------------------------------------------------

func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


func _to_target() -> Vector3:
	if target == null:
		return -global_transform.basis.z
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset


func _turn(toward: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-toward.x, -toward.z), 1.0 - exp(-TURN_SPEED * delta))


func _is_tired() -> bool:
	return stamina < profile.max_stamina * TIRED


func _set_stamina(value: float) -> void:
	value = clampf(value, 0.0, profile.max_stamina)
	if not is_equal_approx(value, stamina):
		stamina = value
		stamina_changed.emit(stamina, profile.max_stamina)


func _tick_meters(delta: float) -> void:
	if state == State.DOWN or state == State.IDLE:
		return
	_since_hit += delta
	_composure_left = maxf(_composure_left - delta, 0.0)
	_set_stamina(stamina + STAMINA_REGEN * delta)
	if _since_hit > 1.0 and state != State.STAGGER and guard < profile.guard_max:
		guard = minf(guard + profile.guard_regen * (0.5 if _is_tired() else 1.0) * delta, profile.guard_max)
		guard_changed.emit(guard, profile.guard_max)
	if _blocked_timer > 0.0:
		_blocked_timer -= delta
		if _blocked_timer <= 0.0:
			_blocked_recently = 0


## Keeps the fighter on the canvas, inside the fence.
func _confine() -> void:
	if _radius <= 0.0:
		return
	var offset := global_position - _centre
	offset.y = 0.0
	var limit := maxf(_radius - 0.4, 0.1)
	if offset.length() > limit:
		offset = offset.normalized() * limit
	global_position = Vector3(_centre.x + offset.x, _centre.y, _centre.z + offset.z)


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_move_amount = lerpf(_move_amount, clampf(speed / 2.0, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_stride = fmod(_stride + delta * TAU * 1.3 * _move_amount, TAU)
	_animator.stride_phase = _stride
	_animator.move_amount = _move_amount
	_animator.block = move_toward(_animator.block, 1.0 if is_guarding() else 0.0, delta * 9.0)
	_animator.stagger = move_toward(_animator.stagger, 1.0 if state == State.STAGGER else 0.0, delta * 7.0)
	_animator.victory = move_toward(_animator.victory, 1.0 if state == State.VICTORY else 0.0, delta * 3.0)
	_animator.knockdown = minf(_state_time / FALL_TIME, 1.0) if state == State.DOWN else 0.0
	_animator.update(delta)
	model.animate(delta, _stride, 0.0, 0.0, false)


## The telegraph: a "!" over the head, yellow for a light strike and red for a heavy one.
func _show_cue(heavy: bool) -> void:
	telegraph.text = "!!" if heavy else "!"
	telegraph.modulate = HEAVY_CUE if heavy else LIGHT_CUE
	telegraph.visible = true
	telegraph.pixel_size = CUE_SIZE * 0.4
	if _cue_tween != null:
		_cue_tween.kill()
	_cue_tween = create_tween()
	_cue_tween.tween_property(telegraph, "pixel_size", CUE_SIZE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_cue() -> void:
	telegraph.visible = false
	for i in 2:
		_glow(i, 0.0)


func _glow(side: int, amount: float) -> void:
	_glove_materials[side].emission_energy_multiplier = 2.5 * amount

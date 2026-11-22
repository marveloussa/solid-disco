class_name CombatController
extends Node
## First-person striking for the Player: the fight stance, punches and kicks, timed combo chains,
## the block, slips and the perfect counter. Lives at `Player/Combat`.
##
## Targets are CombatTarget nodes (heavy bags, opponents). Opponents hit back through
## `receive_strike`. The stance comes up inside any CombatZone and for the length of a bout;
## damage, speed and footwork all scale with `PlayerStats`.

signal stance_changed(active: bool)
signal bout_changed(active: bool)
signal health_changed(current: float, maximum: float)
## Consecutive strikes landed without being hit; 0 when the run ends.
signal streak_changed(hits: int)
## A named combo or a counter connected, e.g. "GUARD BREAKER".
signal combo_landed(label: String)
signal strike_resolved(strike: Strike)
signal damage_taken(amount: float, blocked: bool)
## A perfect dodge opened the counter window for `seconds` of real time.
signal counter_opened(seconds: float)
signal guard_broken
signal knocked_out

## Timings are seconds at full speed: `startup` from the button to the impact, `recovery` back to
## the guard, `cancel` how soon after the impact the next strike may start. `reach` is measured
## to the target's surface. `weight` (0 to 1) drives hit-stop, shake and camera punch.
const MOVES := {
	Strike.JAB: {"damage": 6.0, "guard": 7.0, "cost": 4.0, "startup": 0.08, "recovery": 0.22, "cancel": 0.09, "reach": 1.55, "knockback": 0.5, "drain": 0.0, "weight": 0.2, "heavy": false},
	Strike.HOOK: {"damage": 10.0, "guard": 12.0, "cost": 6.0, "startup": 0.12, "recovery": 0.3, "cancel": 0.13, "reach": 1.4, "knockback": 0.9, "drain": 0.0, "weight": 0.45, "heavy": false},
	Strike.CROSS: {"damage": 12.0, "guard": 14.0, "cost": 7.0, "startup": 0.14, "recovery": 0.34, "cancel": 0.15, "reach": 1.65, "knockback": 1.1, "drain": 0.0, "weight": 0.55, "heavy": true},
	Strike.OVERHAND: {"damage": 17.0, "guard": 20.0, "cost": 10.0, "startup": 0.19, "recovery": 0.42, "cancel": 0.2, "reach": 1.55, "knockback": 1.8, "drain": 0.0, "weight": 0.8, "heavy": true},
	Strike.UPPERCUT: {"damage": 15.0, "guard": 18.0, "cost": 9.0, "startup": 0.16, "recovery": 0.38, "cancel": 0.18, "reach": 1.35, "knockback": 1.2, "drain": 0.0, "weight": 0.7, "heavy": true},
	Strike.KICK: {"damage": 9.0, "guard": 10.0, "cost": 11.0, "startup": 0.22, "recovery": 0.46, "cancel": 0.28, "reach": 1.9, "knockback": 3.2, "drain": 16.0, "weight": 0.6, "heavy": true},
	Strike.KNEE: {"damage": 12.0, "guard": 12.0, "cost": 10.0, "startup": 0.16, "recovery": 0.42, "cancel": 0.26, "reach": 1.0, "knockback": 1.6, "drain": 24.0, "weight": 0.65, "heavy": true},
}
## Inside this distance the kick button throws a knee instead.
const KNEE_RANGE := 0.7
## Half-angle of the cone in front of the view a strike can land in.
const AIM_CONE := 0.66
## A press this long before the fighter is free still comes out.
const BUFFER_TIME := 0.28
## Power left in a strike thrown with an empty stamina bar.
const GASSED_POWER := 0.55

const BLOCK_REDUCTION := 0.8
## Stamina per second with the guard up, and per point of damage absorbed.
const BLOCK_DRAIN := 3.0
const BLOCK_COST_PER_DAMAGE := 0.45
const GUARD_BREAK_STUN := 0.6

const DODGE_COST := 9.0
const DASH_TIME := 0.16
## Slip speed for untrained and fully trained legs. Short enough to counter from where it ends.
const DASH_SPEED := Vector2(4.4, 6.0)
## Seconds after a slip starts during which strikes pass through.
const IFRAME_TIME := 0.32
## Slipping this close to the impact is a perfect dodge.
const PERFECT_WINDOW := 0.22
const SLIP_ROLL := 0.13

const COUNTER_SLOWMO := 0.25
const COUNTER_SLOWMO_SCALE := 0.3
## Real seconds after the slow motion ends in which the counter strike can still be thrown.
const COUNTER_GRACE := 0.4
const COUNTER_MULTIPLIER := 2.0

const ONE_TWO_BONUS := 1.5
const GUARD_BREAKER_BONUS := 1.25
const KO_FINISHER_BONUS := 2.0

const STREAK_TIMEOUT := 2.2
## The hands stay up this long after leaving a combat zone.
const STANCE_LINGER := 0.4

var player: Player
## Hands up, gloves on.
var stance := false
## A bout is running: opponents can hurt the fighter.
var in_bout := false
## Stance without strikes or steps (countdown, result screen).
var locked := false
var blocking := false
var health := 100.0
var max_health := 100.0
var hit_streak := 0
var tracker := ComboTracker.new()

## Read by Player for the view: slip tilt (radians) and the knockdown (0 standing, 1 on the floor).
var view_roll := 0.0
var view_drop := 0.0
## Velocity of the slip in progress; valid while `is_dashing()`.
var dash_velocity := Vector3.ZERO

# Totals for the current bout, for the result screen.
var bout_damage_dealt := 0.0
var bout_damage_taken := 0.0
var bout_hits := 0
var bout_counters := 0
var bout_best_streak := 0

var _strike: Strike = null
var _strike_time := 0.0
var _resolved := false
var _startup := 0.1
var _recovery := 0.2
var _cancel := 0.1
var _reach := 1.5
var _weight := 0.2
var _buffer := ""
var _buffer_age := 0.0
var _stun := 0.0
var _dodge_time := 99.0
var _dash_left := 0.0
var _dodge_cooldown := 0.0
var _slip_roll := 0.0
var _slip_lean := 0.0
var _counter_time := 0.0
var _streak_time := 0.0
var _stance_linger := 0.0
var _work_time := 0.0
var _down := false
var _body := FightAnimator.new()
var _body_gloves: Array[Node3D] = []

@onready var time_fx: TimeFx = $TimeFx


func _ready() -> void:
	set_process(false)


## Called by the Player once its rig is ready.
func bind(owner_player: Player) -> void:
	player = owner_player
	max_health = PlayerStats.get_max_health()
	health = max_health
	player.model.fight_pose = _body.pose
	var padding := Build.mat(player.arms.glove_color, 0.5)
	for i in 2:
		var glove := FightGear.glove(player.model.get_hand(i), padding, player.arms.glove_trim_color, player.model.render_layers)
		glove.visible = false
		_body_gloves.append(glove)
	set_process(true)


func _process(delta: float) -> void:
	var real := minf(delta / time_fx.frame_scale, 0.1)
	# In slow motion the fighter keeps their own pace; during hit-stop they freeze with the world.
	var slowed := time_fx.is_slowed() and not time_fx.is_frozen()
	var own := real if slowed else delta
	player.arms.fight_time_scale = own / delta if delta > 0.0 else 1.0

	_update_stance(real)
	tracker.tick(real)
	_tick_timers(own, real)
	_tick_block(own)
	_tick_strike(own)
	var slipping := _dodge_time < DASH_TIME + 0.1
	view_roll = lerpf(view_roll, _slip_roll if slipping else 0.0, 1.0 - exp(-24.0 * delta))
	view_drop = move_toward(view_drop, 1.0 if _down else 0.0, delta * 2.4)
	player.arms.fight_stance = stance
	player.arms.blocking = blocking


# --- Input -----------------------------------------------------------------------------------

## True while the fighter can throw, block and slip.
func can_act() -> bool:
	return stance and not locked and not _down and player.controls_enabled


## Receives the player's unhandled input while the stance is up.
func handle_input(event: InputEvent) -> void:
	if not can_act():
		return
	if event.is_action_pressed(&"strike_left"):
		_press("L")
	elif event.is_action_pressed(&"strike_right"):
		_press("R")
	elif event.is_action_pressed(&"kick"):
		_press("K")
	elif event.is_action_pressed(&"dodge"):
		_try_dodge()


func is_dashing() -> bool:
	return _dash_left > 0.0


## Walking speed multiplier in the stance: leg muscle is footwork, a raised guard is slow.
func get_move_factor() -> float:
	if not stance:
		return 1.0
	var factor := lerpf(0.8, 1.08, PlayerStats.get_footwork())
	if blocking:
		factor *= 0.55
	elif _strike != null and not _resolved:
		factor *= 0.7
	return factor


## True shortly after landing a strike; bag and ring work both count as training.
func is_working() -> bool:
	return _work_time > 0.0


## True while the next strike will be a counter.
func is_counter_ready() -> bool:
	return _counter_time > 0.0


func _press(key: String) -> void:
	# Both punch buttons together is the guard, not a strike.
	if key != "K" and _both_buttons():
		_abort_startup()
		_buffer = ""
		return
	_buffer = key
	_buffer_age = 0.0


func _both_buttons() -> bool:
	return Input.is_action_pressed(&"strike_left") and Input.is_action_pressed(&"strike_right")


# --- Stance and bouts ------------------------------------------------------------------------

## Starts a bout: full health, hands up, frozen until `set_locked(false)`.
func begin_bout() -> void:
	in_bout = true
	locked = true
	_down = false
	max_health = PlayerStats.get_max_health()
	health = max_health
	bout_damage_dealt = 0.0
	bout_damage_taken = 0.0
	bout_hits = 0
	bout_counters = 0
	bout_best_streak = 0
	_reset_action()
	_set_streak(0)
	time_fx.clear()
	health_changed.emit(health, max_health)
	bout_changed.emit(true)


func set_locked(value: bool) -> void:
	locked = value
	if locked:
		_reset_action()


func end_bout() -> void:
	in_bout = false
	locked = false
	_down = false
	_reset_action()
	_set_streak(0)
	time_fx.clear()
	bout_changed.emit(false)


func _update_stance(real: float) -> void:
	var wanted := in_bout
	if not wanted and player.vehicle == null and player.station == null:
		var spot := player.global_position
		for node in get_tree().get_nodes_in_group(&"combat_zones"):
			var zone := node as CombatZone
			if zone != null and zone.contains(spot):
				wanted = true
				break
	if wanted:
		_stance_linger = STANCE_LINGER
	else:
		_stance_linger -= real
		wanted = stance and _stance_linger > 0.0
	if wanted == stance:
		return
	stance = wanted
	if not stance:
		_reset_action()
		_set_streak(0)
	stance_changed.emit(stance)


func _reset_action() -> void:
	_strike = null
	_buffer = ""
	blocking = false
	_stun = 0.0
	_dash_left = 0.0
	_counter_time = 0.0
	tracker.clear()
	if player != null:
		player.arms.cancel_strikes()


func _tick_timers(own: float, real: float) -> void:
	_dodge_time += own
	_dash_left = maxf(_dash_left - own, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - own, 0.0)
	_stun = maxf(_stun - own, 0.0)
	_work_time = maxf(_work_time - real, 0.0)
	_counter_time = maxf(_counter_time - real, 0.0)
	if hit_streak > 0:
		_streak_time -= own
		if _streak_time <= 0.0:
			_set_streak(0)


# --- Striking --------------------------------------------------------------------------------

func _tick_strike(own: float) -> void:
	if not _buffer.is_empty():
		_buffer_age += own
		if _buffer_age > BUFFER_TIME:
			_buffer = ""
	if _strike != null:
		_strike_time += own
		if not _resolved and _strike_time >= _startup:
			_resolve()
		if _strike_time >= _startup + _recovery:
			_strike = null
	if not _buffer.is_empty() and _can_start():
		var key := _buffer
		_buffer = ""
		_start(key)


func _can_start() -> bool:
	if not can_act() or blocking or _stun > 0.0 or is_dashing():
		return false
	return _strike == null or (_resolved and _strike_time >= _startup + _cancel)


func _start(key: String) -> void:
	var kind: StringName
	var combo: StringName = &""
	if key == "K":
		var kick_reach: float = MOVES[Strike.KICK]["reach"]
		var target := _find_target(kick_reach)
		kind = Strike.KNEE if target != null and _distance_to(target) < KNEE_RANGE else Strike.KICK
	else:
		kind = tracker.next_kind(key)
		combo = tracker.push(key)
	var move: Dictionary = MOVES[kind]
	var kicking := kind == Strike.KICK or kind == Strike.KNEE
	var power := PlayerStats.get_kick_power() if kicking else PlayerStats.get_punch_power()
	# An empty tank still throws, but slowly and without much behind it.
	var cost: float = move["cost"]
	if not PlayerStats.spend_stamina(cost):
		power *= GASSED_POWER

	var strike := Strike.new()
	var base_damage: float = move["damage"]
	var base_guard: float = move["guard"]
	var base_knockback: float = move["knockback"]
	var base_drain: float = move["drain"]
	strike.kind = kind
	strike.side = 0 if kind == Strike.JAB or kind == Strike.HOOK else 1
	strike.damage = base_damage * power * randf_range(0.94, 1.06)
	strike.guard_damage = base_guard * PlayerStats.get_guard_break_power()
	strike.knockback = base_knockback * (PlayerStats.get_kick_power() if kicking else 1.0)
	strike.stamina_drain = base_drain * (PlayerStats.get_kick_power() if kicking else 1.0)
	strike.heavy = move["heavy"]
	strike.combo = combo
	strike.attacker = player
	if _counter_time > 0.0:
		strike.counter = true
		strike.damage *= COUNTER_MULTIPLIER
		_counter_time = 0.0

	var speed := PlayerStats.get_fight_speed()
	var startup: float = move["startup"]
	var recovery: float = move["recovery"]
	var cancel: float = move["cancel"]
	_strike = strike
	_strike_time = 0.0
	_resolved = false
	_startup = startup / speed
	_recovery = recovery / speed
	_cancel = cancel / speed
	_reach = move["reach"]
	_weight = move["weight"]
	if kicking:
		player.arms.play_kick(kind, _startup, _recovery)
	else:
		player.arms.play_strike(kind, strike.side, _startup, _recovery)


## The moment of impact: finds what is in front of the fist and lands on it.
func _resolve() -> void:
	_resolved = true
	var strike := _strike
	var target := _find_target(_reach)
	if target == null:
		# A whiff breaks the chain.
		tracker.clear()
		strike_resolved.emit(strike)
		return
	var flat := target.global_position - player.global_position
	flat.y = 0.0
	strike.direction = flat.normalized() if flat.length() > 0.01 else _view_forward()
	match strike.combo:
		Strike.ONE_TWO:
			strike.damage *= ONE_TWO_BONUS
		Strike.GUARD_BREAKER:
			strike.guard_breaker = true
			strike.damage *= GUARD_BREAKER_BONUS
		Strike.KO_FINISHER:
			strike.damage *= KO_FINISHER_BONUS
			strike.knockback = strike.knockback * 2.0 + 3.0
			strike.heavy = true
	target.receive(strike)
	if strike.connected():
		_on_connected(strike, target)
	else:
		tracker.clear()
	strike_resolved.emit(strike)


func _on_connected(strike: Strike, target: CombatTarget) -> void:
	_work_time = 3.0
	bout_hits += 1
	bout_damage_dealt += strike.dealt
	_set_streak(hit_streak + 1)

	var blocked := strike.outcome == Strike.Outcome.BLOCKED
	var knockout := strike.outcome == Strike.Outcome.KNOCKOUT
	var weight := _weight
	if strike.counter or knockout or strike.combo == Strike.KO_FINISHER:
		weight = 1.0
	elif strike.combo != &"":
		weight = maxf(weight, 0.75)
	if blocked:
		weight *= 0.5
	elif strike.heavy or strike.counter or strike.combo != &"":
		time_fx.hit_stop(lerpf(0.03, 0.06, weight))
	player.add_shake(0.12 + 0.6 * weight)
	var across := -1.0 if strike.side == 0 else 1.0
	player.add_view_punch(Vector2(-0.006 - 0.022 * weight, -across * 0.014 * weight))

	var host := get_tree().current_scene
	var at := target.global_position + Vector3.UP * 0.45
	if strike.counter:
		bout_counters += 1
		combo_landed.emit("COUNTER x2")
	elif strike.combo != &"":
		combo_landed.emit(ComboTracker.LABELS[strike.combo])
	if knockout:
		CombatPopup.spawn(host, "KNOCKOUT!", at, CombatPopup.WARN, 0.42, 1.8)
	elif strike.counter:
		CombatPopup.spawn(host, "COUNTER x2!", at + Vector3.UP * 0.2, CombatPopup.HOT, 0.3, 1.1)
	elif strike.outcome == Strike.Outcome.GUARD_BREAK:
		CombatPopup.spawn(host, "GUARD BREAK!", at + Vector3.UP * 0.2, CombatPopup.ACCENT, 0.3, 1.1)
	elif strike.combo == Strike.KO_FINISHER:
		CombatPopup.spawn(host, "KO FINISHER!", at + Vector3.UP * 0.2, CombatPopup.WARN, 0.3, 1.1)
	elif strike.combo == Strike.ONE_TWO and not blocked:
		CombatPopup.spawn(host, "1-2!", at + Vector3.UP * 0.2, CombatPopup.ACCENT, 0.22)
	if blocked:
		CombatPopup.spawn(host, "BLOCKED", at, CombatPopup.MUTED, 0.13, 0.7)
	else:
		CombatPopup.spawn(host, str(maxi(roundi(strike.dealt), 1)), at, CombatPopup.WHITE, 0.13 + 0.09 * weight, 0.8)


## The nearest enabled target inside `reach` and the aim cone, or null.
func _find_target(reach: float) -> CombatTarget:
	var forward := _view_forward()
	var best: CombatTarget = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"combat_targets"):
		var target := node as CombatTarget
		if target == null or not target.enabled or not target.is_visible_in_tree():
			continue
		var offset := target.global_position - player.global_position
		# The aim point is at chest height; anything else is on another storey.
		if offset.y < -0.4 or offset.y > 2.6:
			continue
		var flat := Vector3(offset.x, 0.0, offset.z)
		var distance := flat.length() - target.radius
		if distance > reach:
			continue
		var angle := forward.angle_to(flat) if flat.length() > 0.05 else 0.0
		# Up close the target fills the view, so the cone opens up.
		if angle > AIM_CONE * (1.7 if distance < 0.6 else 1.0):
			continue
		var score := angle + maxf(distance, 0.0) * 0.25
		if score < best_score:
			best_score = score
			best = target
	return best


func _distance_to(target: CombatTarget) -> float:
	var offset := target.global_position - player.global_position
	return Vector2(offset.x, offset.z).length() - target.radius


func _view_forward() -> Vector3:
	var forward := -player.head.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.05:
		forward = -player.global_transform.basis.z
	return forward.normalized()


func _abort_startup() -> void:
	if _strike != null and not _resolved:
		_strike = null
		player.arms.cancel_strikes()


func _set_streak(hits: int) -> void:
	if hits == hit_streak:
		if hits > 0:
			_streak_time = STREAK_TIMEOUT
		return
	hit_streak = hits
	_streak_time = STREAK_TIMEOUT
	bout_best_streak = maxi(bout_best_streak, hits)
	streak_changed.emit(hits)


# --- Defence ---------------------------------------------------------------------------------

func _tick_block(own: float) -> void:
	var held := Input.is_action_pressed(&"block") or _both_buttons()
	var wanted := held and can_act() and _stun <= 0.0 and not is_dashing() and not PlayerStats.is_exhausted
	if wanted and _strike != null:
		if _resolved:
			# The guard comes straight back up after a punch has landed.
			_strike = null
			player.arms.cancel_strikes()
		elif _both_buttons():
			_abort_startup()
		else:
			wanted = false
	if blocking and held and PlayerStats.is_exhausted:
		# Ran out of stamina with the guard up.
		_break_guard()
	blocking = wanted
	if blocking:
		PlayerStats.spend_stamina(BLOCK_DRAIN * own)


func _try_dodge() -> void:
	if _dodge_cooldown > 0.0 or _stun > 0.0 or not player.is_on_floor():
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := Vector3.ZERO
	if absf(input.x) > 0.3 and absf(input.x) >= absf(input.y):
		direction.x = signf(input.x)
	elif input.y > -0.3:
		# Back, or no direction at all: slip straight out of range.
		direction.z = 1.0
	else:
		return
	# With an empty tank the slip still comes out, slower and less often.
	var tired := 1.0 if PlayerStats.spend_stamina(DODGE_COST) else 0.7
	_abort_startup()
	_buffer = ""
	var footwork := PlayerStats.get_footwork()
	dash_velocity = player.global_transform.basis * direction * lerpf(DASH_SPEED.x, DASH_SPEED.y, footwork) * tired
	_dash_left = DASH_TIME
	_dodge_time = 0.0
	_dodge_cooldown = lerpf(0.55, 0.38, footwork) / tired
	_slip_roll = -direction.x * SLIP_ROLL
	_slip_lean = direction.x
	if direction.z > 0.0:
		player.add_view_punch(Vector2(0.035, 0.0))


## An opponent's strike arrives. `in_reach` is whether it would connect with a fighter who
## stood still. Writes the outcome into `strike`.
func receive_strike(strike: Strike, in_reach: bool) -> void:
	strike.outcome = Strike.Outcome.MISS
	strike.dealt = 0.0
	if not in_bout or _down:
		return
	if _dodge_time < IFRAME_TIME:
		strike.outcome = Strike.Outcome.DODGED
		if _dodge_time <= PERFECT_WINDOW:
			strike.perfect = true
			_open_counter()
		return
	if not in_reach:
		return

	var facing := _view_forward().dot(-strike.direction) > 0.1
	if blocking and facing:
		strike.outcome = Strike.Outcome.BLOCKED
		strike.dealt = strike.damage * (1.0 - BLOCK_REDUCTION)
		var cost := strike.damage * BLOCK_COST_PER_DAMAGE
		if not PlayerStats.spend_stamina(cost) or PlayerStats.is_exhausted:
			# The guard gives way under the blow.
			strike.outcome = Strike.Outcome.GUARD_BREAK
			strike.dealt = strike.damage * 0.5
			_break_guard()
	else:
		strike.outcome = Strike.Outcome.HIT
		strike.dealt = strike.damage
	_take_damage(strike)


func _open_counter() -> void:
	_counter_time = COUNTER_SLOWMO + COUNTER_GRACE
	time_fx.slow_motion(COUNTER_SLOWMO, COUNTER_SLOWMO_SCALE)
	PlayerStats.popup_requested.emit("PERFECT DODGE!", &"perfect")
	counter_opened.emit(_counter_time)


func _break_guard() -> void:
	blocking = false
	_stun = GUARD_BREAK_STUN
	_reset_strike_only()
	PlayerStats.popup_requested.emit("GUARD BROKEN!", &"warning")
	guard_broken.emit()


func _reset_strike_only() -> void:
	_strike = null
	_buffer = ""
	player.arms.cancel_strikes()


func _take_damage(strike: Strike) -> void:
	var blocked := strike.outcome == Strike.Outcome.BLOCKED
	health = maxf(health - strike.dealt, 0.0)
	bout_damage_taken += strike.dealt
	if not blocked:
		_set_streak(0)
		tracker.clear()

	# The view is thrown away from the blow: an opponent's right hand comes from our left.
	var weight := clampf(strike.dealt / maxf(max_health * 0.2, 1.0), 0.15, 1.0)
	var across := -1.0 if strike.side == 1 else 1.0
	if strike.is_kick():
		player.add_view_punch(Vector2(0.05 * weight, 0.0))
	else:
		player.add_view_punch(Vector2(0.02 * weight, across * 0.06 * weight))
	player.add_shake(0.25 + 0.7 * weight)
	player.arms.flinch(0.4 + 0.6 * weight)
	_body.flinch(weight, across)
	if strike.knockback > 0.0:
		player.apply_impulse(strike.direction * strike.knockback * (0.4 if blocked else 1.0))
	if not blocked and strike.heavy:
		time_fx.hit_stop(0.04)

	health_changed.emit(health, max_health)
	damage_taken.emit(strike.dealt, blocked)
	if health <= 0.0:
		strike.outcome = Strike.Outcome.KNOCKOUT
		_down = true
		_reset_action()
		knocked_out.emit()


# --- Third-person body -----------------------------------------------------------------------

## Poses the player's own body (mirror, shadow) to match the fight. Called by the Player every
## physics tick, before it animates the model.
func pose_body(delta: float, stride_phase: float, move_amount: float) -> void:
	var model := player.model
	model.fight_blend = move_toward(model.fight_blend, 1.0 if stance else 0.0, delta * 5.0)
	for glove in _body_gloves:
		glove.visible = model.fight_blend > 0.05
	if model.fight_blend <= 0.0:
		return
	_body.stride_phase = stride_phase
	_body.move_amount = move_amount
	_body.block = move_toward(_body.block, 1.0 if blocking else 0.0, delta * 10.0)
	_body.knockdown = view_drop
	_body.lean = _slip_lean if _dodge_time < DASH_TIME + 0.1 else 0.0
	if _strike == null:
		_body.clear_strike()
	elif _resolved:
		_body.set_strike(_strike.kind, _strike.side, 0.0, 1.0 - (_strike_time - _startup) / _recovery)
	else:
		var progress := _strike_time / _startup
		_body.set_strike(_strike.kind, _strike.side, progress * 2.5, (progress - 0.4) / 0.6)
	_body.update(delta)

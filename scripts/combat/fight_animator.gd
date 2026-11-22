class_name FightAnimator
extends RefCounted
## Fight choreography for a CharacterModel: the guard stance, wind-ups, strikes, the block,
## staggers and the knockdown, written as joint targets into `pose`. The owner sets the inputs
## every physics tick, calls `update` and lets the model blend `pose` in through its fight layer.
## The stance is orthodox: left side leads.

## Arm strikes. `wind` and `hit` are (arm_x, arm_z, elbow) at the top of the wind-up and at full
## extension; `twist`, `lean` and `dip` are the torso twist, torso lean and hip height at those
## two moments (x for the wind-up, y for the hit).
const ARM_MOVES := {
	Strike.JAB: {"wind": Vector3(0.72, -0.05, 2.45), "hit": Vector3(1.5, -0.08, 0.06), "twist": Vector2(0.12, 0.32), "lean": Vector2(0.03, -0.1), "dip": Vector2.ZERO},
	Strike.CROSS: {"wind": Vector3(0.3, 0.32, 2.35), "hit": Vector3(1.52, -0.1, 0.05), "twist": Vector2(0.5, 0.62), "lean": Vector2(0.05, -0.2), "dip": Vector2(0.0, -0.02)},
	# The arm is carried out to the side, so the bent elbow swings the fist across.
	Strike.HOOK: {"wind": Vector3(-0.15, 1.2, 1.25), "hit": Vector3(0.1, 1.25, 1.8), "twist": Vector2(0.6, 0.85), "lean": Vector2(0.04, -0.12), "dip": Vector2(-0.02, -0.03)},
	Strike.OVERHAND: {"wind": Vector3(-0.45, 0.85, 1.9), "hit": Vector3(1.8, 0.1, 0.5), "twist": Vector2(0.62, 0.62), "lean": Vector2(0.14, -0.4), "dip": Vector2(0.0, -0.05)},
	Strike.UPPERCUT: {"wind": Vector3(0.1, 0.12, 1.35), "hit": Vector3(1.25, -0.12, 2.0), "twist": Vector2(0.32, 0.45), "lean": Vector2(-0.3, 0.12), "dip": Vector2(-0.11, 0.03)},
}
const BLOCK_ARM := Vector3(1.3, -0.22, 2.5)

var pose := FightPose.new()
## Walk cycle of the fighter, so the feet shuffle while the hands stay up.
var stride_phase := 0.0
var move_amount := 0.0
## Inputs, 0 to 1 unless noted.
var block := 0.0
var stagger := 0.0
var knockdown := 0.0
var victory := 0.0
## Side slip, -1 (left) to 1 (right).
var lean := 0.0
## Shaky hands and a low guard.
var nerves := 0.0
## Bounce in the footwork.
var bounce := 0.0
## The strike in progress, or &"". `windup` pulls the limb back, `extend` throws it.
var strike_kind: StringName = &""
var strike_side := 0
var windup := 0.0
var extend := 0.0

var _time := 0.0
var _flinch := 0.0
var _flinch_side := 0.0


func set_strike(kind: StringName, side: int, windup_amount: float, extend_amount: float) -> void:
	strike_kind = kind
	strike_side = side
	windup = clampf(windup_amount, 0.0, 1.0)
	extend = clampf(extend_amount, 0.0, 1.0)


func clear_strike() -> void:
	strike_kind = &""
	windup = 0.0
	extend = 0.0


## Snaps the head and shoulders back from a hit. `side` -1 or 1 turns them away from it.
func flinch(strength: float = 1.0, side: float = 0.0) -> void:
	_flinch = clampf(maxf(_flinch, strength), 0.0, 1.0)
	_flinch_side = side


func update(delta: float) -> void:
	_time += delta
	_flinch = move_toward(_flinch, 0.0, delta * 3.5)
	var p := pose
	var lowered := 0.3 * nerves
	for i in 2:
		var lead := i == 0
		var step := sin(stride_phase + (PI if i == 1 else 0.0)) * 0.24 * move_amount
		p.leg[i] = (0.35 if lead else -0.3) + step
		p.knee[i] = (-0.55 if lead else -0.1) - maxf(-step, 0.0) * 0.7
		p.arm_x[i] = (1.05 if lead else 0.92) - lowered + sin(_time * 29.0 + i * 2.1) * 0.035 * nerves
		p.arm_z[i] = -0.1
		p.elbow[i] = (1.95 if lead else 2.2) - lowered * 0.6
	p.torso = Vector3(-0.1, -0.22, 0.0)
	p.head = 0.05
	p.root_pos = Vector3(0.0, -0.045 + absf(sin(_time * 6.5)) * 0.028 * bounce, 0.0)
	p.root_rot = Vector3.ZERO

	if strike_kind != &"":
		_layer_strike(p)
	if block > 0.0:
		var guard := smoothstep(0.0, 1.0, block)
		for i in 2:
			_blend_arm(p, i, BLOCK_ARM, guard)
		p.head = lerpf(p.head, -0.2, guard)
		p.torso.x = lerpf(p.torso.x, -0.2, guard)
		p.torso.y = lerpf(p.torso.y, -0.08, guard)
	if _flinch > 0.0:
		p.torso.x += 0.25 * _flinch
		p.torso.y += 0.35 * _flinch * _flinch_side
		p.head += 0.4 * _flinch
	if lean != 0.0:
		p.root_rot.z -= lean * 0.22
		p.torso.z -= lean * 0.2
	if stagger > 0.0:
		_layer_stagger(p, smoothstep(0.0, 1.0, stagger))
	if victory > 0.0:
		_layer_victory(p, smoothstep(0.0, 1.0, victory))
	if knockdown > 0.0:
		_layer_knockdown(p, clampf(knockdown, 0.0, 1.0))


func _layer_strike(p: FightPose) -> void:
	var i := strike_side
	var side := -1.0 if i == 0 else 1.0
	var thrown := extend
	var wound := smoothstep(0.0, 1.0, windup) * (1.0 - thrown)
	if ARM_MOVES.has(strike_kind):
		var move: Dictionary = ARM_MOVES[strike_kind]
		var twist: Vector2 = move["twist"]
		var torso_lean: Vector2 = move["lean"]
		var dip: Vector2 = move["dip"]
		_blend_arm(p, i, move["wind"], wound)
		_blend_arm(p, i, move["hit"], thrown)
		p.torso.y += side * (twist.y * thrown - twist.x * wound)
		p.torso.x += torso_lean.x * wound + torso_lean.y * thrown
		p.root_pos.y += dip.x * wound + dip.y * thrown
		return
	# Kicks: chamber the knee, then thrust. x is the thigh, y the knee.
	var knee_strike := strike_kind == Strike.KNEE
	var chamber := Vector2(0.45, -1.3) if knee_strike else Vector2(1.0, -1.75)
	var thrust := Vector2(1.55, -2.0) if knee_strike else Vector2(1.4, -0.12)
	p.leg[i] = lerpf(lerpf(p.leg[i], chamber.x, wound), thrust.x, thrown)
	p.knee[i] = lerpf(lerpf(p.knee[i], chamber.y, wound), thrust.y, thrown)
	# Stand tall on the other leg.
	var planted := maxf(wound, thrown)
	var other := 1 - i
	p.leg[other] = lerpf(p.leg[other], 0.0, planted)
	p.knee[other] = lerpf(p.knee[other], -0.08, planted)
	p.torso.x += (-0.25 if knee_strike else 0.28) * thrown + 0.08 * wound
	p.root_pos.y += 0.03 * planted


func _layer_stagger(p: FightPose, amount: float) -> void:
	var wobble := sin(_time * 11.0)
	for i in 2:
		_blend_arm(p, i, Vector3(0.35 + 0.15 * wobble, 0.45, 0.9), amount)
		p.leg[i] = lerpf(p.leg[i], 0.12 if i == 0 else -0.25, amount)
		p.knee[i] = lerpf(p.knee[i], -0.35, amount)
	p.torso = p.torso.lerp(Vector3(0.36, 0.0, 0.1 * wobble), amount)
	p.head = lerpf(p.head, 0.45, amount)
	p.root_rot.z += 0.07 * wobble * amount
	p.root_pos.y = lerpf(p.root_pos.y, -0.06, amount)


func _layer_victory(p: FightPose, amount: float) -> void:
	for i in 2:
		_blend_arm(p, i, Vector3(2.75, 0.35, 0.3 + 0.15 * sin(_time * 6.0 + i)), amount)
		p.leg[i] = lerpf(p.leg[i], 0.0, amount)
		p.knee[i] = lerpf(p.knee[i], -0.05, amount)
	p.torso = p.torso.lerp(Vector3(0.08, 0.0, 0.0), amount)
	p.head = lerpf(p.head, 0.25, amount)
	p.root_pos.y = lerpf(p.root_pos.y, absf(sin(_time * 5.0)) * 0.05, amount)


## Falls straight back, pivoting on the heels, and ends flat on the canvas.
func _layer_knockdown(p: FightPose, amount: float) -> void:
	var fall := amount * amount
	for i in 2:
		_blend_arm(p, i, Vector3(0.1, 1.15, 0.35), amount)
		p.leg[i] = lerpf(p.leg[i], 0.12 + 0.1 * i, amount)
		p.knee[i] = lerpf(p.knee[i], -0.3 - 0.25 * i, amount)
	p.torso = p.torso.lerp(Vector3(0.05, 0.0, 0.0), amount)
	p.head = lerpf(p.head, 0.2, amount)
	p.root_rot = Vector3(PI * 0.5 * fall, 0.0, 0.0)
	p.root_pos = Vector3(0.0, 0.13 * fall, 0.0)


## Moves one arm towards `target` (arm_x, arm_z, elbow).
func _blend_arm(p: FightPose, i: int, target: Vector3, weight: float) -> void:
	p.arm_x[i] = lerpf(p.arm_x[i], target.x, weight)
	p.arm_z[i] = lerpf(p.arm_z[i], target.y, weight)
	p.elbow[i] = lerpf(p.elbow[i], target.z, weight)

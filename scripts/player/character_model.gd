class_name CharacterModel
extends Node3D
## Stylized low-poly humanoid built from primitives on a simple joint hierarchy.
## The player uses it for the mirror reflection and shadow; NPCs can reuse it on the world layer.
## `muscle` (0..1) scales limb and torso girth. Faces local -Z.

const HIP_HEIGHT := 1.0
const THIGH := 0.5
const SHIN := 0.44
const UPPER_ARM := 0.34
const FOREARM := 0.31
## Hip position while seated on the bicycle, relative to the rider root.
const RIDE_HIP := Vector3(0.0, 0.97, 0.27)

@export_range(0.0, 1.0) var muscle := 0.0: set = set_muscle
## Layer 3 keeps the body out of the first-person camera; use layer 1 for NPCs.
@export_flags_3d_render var render_layers := 4
@export var skin_color := Color(0.96, 0.76, 0.62)
@export var shirt_color := Color(0.16, 0.62, 0.86)
@export var shorts_color := Color(0.13, 0.15, 0.22)
@export var shoe_color := Color(0.93, 0.25, 0.2)
@export var hair_color := Color(0.26, 0.16, 0.1)

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _ride_blend := 0.0
var _time := 0.0


func _ready() -> void:
	_build()


func set_muscle(value: float) -> void:
	muscle = clampf(value, 0.0, 1.0)
	if is_node_ready():
		_build()


## Call once per physics tick. `stride_phase` advances with distance walked, `pedal_phase` with
## the bicycle crank; `lean` rolls the body with the bike.
func animate(delta: float, stride_phase: float, move_amount: float, look_pitch: float, riding: bool, pedal_phase: float = 0.0, lean: float = 0.0) -> void:
	_time += delta
	_ride_blend = move_toward(_ride_blend, 1.0 if riding else 0.0, delta * 5.0)
	var ride := smoothstep(0.0, 1.0, _ride_blend)
	var swing := sin(stride_phase) * 0.6 * move_amount
	var breath := sin(_time * 1.6) * 0.012
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var step := swing * side
		var pedal := pedal_phase + (PI if i == 1 else 0.0)
		_legs[i].rotation.x = lerpf(step, 1.28 + 0.3 * sin(pedal), ride)
		_knees[i].rotation.x = -lerpf(maxf(-step, 0.0) * 1.1 + 0.05, 1.45 - 0.3 * cos(pedal), ride)
		_shoulders[i].rotation.x = lerpf(-step * 0.8, 1.25, ride)
		_shoulders[i].rotation.z = side * lerpf(0.07 + breath, 0.12, ride)
		_elbows[i].rotation.x = lerpf(0.12 + absf(step) * 0.5, 0.35, ride)
	_torso.rotation.x = lerpf(-0.05 * move_amount + breath, -0.3, ride)
	_head.rotation.x = lerpf(look_pitch * 0.6, 0.3 + look_pitch * 0.4, ride)
	var bob := absf(sin(stride_phase)) * 0.03 * move_amount * (1.0 - ride)
	position = Vector3(0.0, bob, 0.0).lerp(RIDE_HIP - Vector3(0.0, HIP_HEIGHT, 0.0), ride)
	rotation.z = lean * ride


func _build() -> void:
	for child in get_children():
		child.free()
	_shoulders.clear()
	_elbows.clear()
	_legs.clear()
	_knees.clear()

	var skin := Build.mat(skin_color, 0.7)
	var shirt := Build.mat(shirt_color, 0.8)
	var shorts := Build.mat(shorts_color, 0.8)
	var shoes := Build.mat(shoe_color, 0.6)
	var hair := Build.mat(hair_color, 0.9)
	var torso_width := lerpf(0.27, 0.46, muscle)
	var torso_depth := lerpf(0.14, 0.25, muscle)
	var arm_radius := lerpf(0.03, 0.062, muscle)
	var leg_radius := lerpf(0.045, 0.08, muscle)

	_hips = _pivot(self, Vector3(0.0, HIP_HEIGHT, 0.0))
	Build.box(_hips, Vector3(torso_width - 0.01, 0.2, torso_depth + 0.01), Vector3(0.0, 0.07, 0.0), shorts)

	_torso = _pivot(_hips, Vector3(0.0, 0.14, 0.0))
	Build.box(_torso, Vector3(torso_width, 0.46, torso_depth), Vector3(0.0, 0.25, 0.0), shirt)
	Build.cyl(_torso, 0.04 + 0.02 * muscle, 0.1, Vector3(0.0, 0.52, 0.0), skin)

	_head = _pivot(_torso, Vector3(0.0, 0.555, 0.0))
	Build.ball(_head, 0.115, Vector3(0.0, 0.115, 0.0), skin, Vector3(0.9, 1.08, 1.0))
	Build.ball(_head, 0.12, Vector3(0.0, 0.155, 0.022), hair, Vector3(0.94, 0.86, 1.0))
	var eyes := Build.mat(Color(0.1, 0.1, 0.12), 0.4)
	for side: float in [-1.0, 1.0]:
		Build.ball(_head, 0.014, Vector3(side * 0.04, 0.125, -0.103), eyes)
		Build.box(_head, Vector3(0.04, 0.008, 0.01), Vector3(side * 0.04, 0.152, -0.105), hair)
	Build.box(_head, Vector3(0.02, 0.03, 0.03), Vector3(0.0, 0.1, -0.115), skin)

	for side: float in [-1.0, 1.0]:
		var shoulder := _pivot(_torso, Vector3(side * (torso_width * 0.5 + arm_radius), 0.43, 0.0))
		Build.tube(shoulder, Vector3.ZERO, Vector3(0.0, -UPPER_ARM, 0.0), arm_radius, skin)
		Build.tube(shoulder, Vector3(0.0, 0.03, 0.0), Vector3(0.0, -0.13, 0.0), arm_radius * 1.4, shirt)
		var elbow := _pivot(shoulder, Vector3(0.0, -UPPER_ARM, 0.0))
		Build.ball(elbow, arm_radius, Vector3.ZERO, skin, Vector3.ONE, 8)
		Build.tube(elbow, Vector3.ZERO, Vector3(0.0, -FOREARM, 0.0), arm_radius * 0.85, skin)
		Build.box(elbow, Vector3(0.045, 0.1, 0.07), Vector3(0.0, -FOREARM - 0.045, 0.0), skin)
		_shoulders.append(shoulder)
		_elbows.append(elbow)

		var leg := _pivot(_hips, Vector3(side * (torso_width * 0.5 - leg_radius - 0.01), 0.0, 0.0))
		Build.tube(leg, Vector3.ZERO, Vector3(0.0, -THIGH, 0.0), leg_radius, skin)
		Build.tube(leg, Vector3(0.0, 0.02, 0.0), Vector3(0.0, -0.24, 0.0), leg_radius * 1.35, shorts)
		var knee := _pivot(leg, Vector3(0.0, -THIGH, 0.0))
		Build.ball(knee, leg_radius, Vector3.ZERO, skin, Vector3.ONE, 8)
		Build.tube(knee, Vector3.ZERO, Vector3(0.0, -SHIN, 0.0), leg_radius * 0.8, skin)
		Build.box(knee, Vector3(0.09, 0.07, 0.25), Vector3(0.0, -SHIN - 0.025, -0.055), shoes)
		_legs.append(leg)
		_knees.append(knee)

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.layers = render_layers


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	return node

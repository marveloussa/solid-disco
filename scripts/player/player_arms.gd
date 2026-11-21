class_name PlayerArms
extends Node3D
## Procedural first-person arms. A two-bone IK solve keeps each hand on an animated target
## (idle breathing, walk and sprint swing) or on a vehicle's grips, so a new pose only needs
## hand targets. `muscle` thickens the arms as the player grows.

const UPPER_LENGTH := 0.36
const FOREARM_LENGTH := 0.34
## Render layer 2: seen by the player camera, hidden from mirror cameras.
const FIRST_PERSON_LAYER := 2
const DEPTH_PULL := 0.9

## Pulls the view model towards the near plane so the arms never clip into nearby walls.
const VIEWMODEL_SHADER := """
shader_type spatial;
uniform vec3 albedo : source_color = vec3(1.0);
uniform float depth_pull = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.z, POSITION.w, depth_pull);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 0.8;
}
"""

@export_range(0.0, 1.0) var muscle := 0.0: set = set_muscle
@export var skin_color := Color(0.96, 0.76, 0.62)
@export var sleeve_color := Color(0.16, 0.62, 0.86)


class Arm:
	var side := 1.0
	var upper: MeshInstance3D
	var fore: MeshInstance3D
	var hand: Node3D
	var grip: Node3D
	# Last grip pose in arm space, kept so the hand eases off after letting go.
	var held_hand := Vector3.ZERO
	var held_shoulder := Vector3.ZERO
	var held_pole := Vector3.DOWN


var _arms: Array[Arm] = []
var _materials: Array[ShaderMaterial] = []
var _grip_blend := 0.0
var _air_blend := 0.0
var _breath := 0.0
var _sway := Vector2.ZERO


func _ready() -> void:
	var shader := Shader.new()
	shader.code = VIEWMODEL_SHADER
	var skin := _material(shader, skin_color)
	var sleeve := _material(shader, sleeve_color)
	for side: float in [-1.0, 1.0]:
		var arm := Arm.new()
		arm.side = side
		arm.upper = _segment(UPPER_LENGTH, skin)
		var cuff := _segment(UPPER_LENGTH * 0.45, sleeve)
		cuff.position.y = -UPPER_LENGTH * 0.3
		cuff.scale = Vector3(1.35, 1.0, 1.35)
		remove_child(cuff)
		arm.upper.add_child(cuff)
		arm.fore = _segment(FOREARM_LENGTH, skin)
		arm.hand = _hand(side, skin)
		_arms.append(arm)
	set_muscle(muscle)


func set_muscle(value: float) -> void:
	muscle = clampf(value, 0.0, 1.0)
	for arm in _arms:
		_resize(arm.upper, lerpf(0.03, 0.062, muscle), UPPER_LENGTH)
		_resize(arm.upper.get_child(0) as MeshInstance3D, lerpf(0.03, 0.062, muscle), UPPER_LENGTH * 0.45)
		_resize(arm.fore, lerpf(0.025, 0.05, muscle), FOREARM_LENGTH)
		arm.hand.scale = Vector3.ONE * lerpf(1.0, 1.25, muscle)


## Hands hold these nodes (e.g. handlebar grips) until called again with nulls.
func set_grips(left: Node3D, right: Node3D) -> void:
	_arms[0].grip = left
	_arms[1].grip = right


## Mouse movement makes the hands trail slightly behind the view.
func add_sway(mouse_delta: Vector2) -> void:
	_sway = (_sway + Vector2(-mouse_delta.x, mouse_delta.y) * 0.00012).limit_length(0.03)


## Call every rendered frame. `torso` is the rider's eye-level frame while holding grips.
func animate(delta: float, stride_phase: float, move_amount: float, sprint_amount: float, airborne: bool, torso: Transform3D) -> void:
	_breath += delta
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	_air_blend = move_toward(_air_blend, 1.0 if airborne else 0.0, delta * 6.0)
	var gripping := _arms[0].grip != null
	_grip_blend = move_toward(_grip_blend, 1.0 if gripping else 0.0, delta * 4.0)
	# Holding real geometry needs true depth so hands and handlebars sort correctly.
	var pull := 0.0 if _grip_blend > 0.0 else DEPTH_PULL
	for material in _materials:
		material.set_shader_parameter("depth_pull", pull)

	var blend := smoothstep(0.0, 1.0, _grip_blend)
	for arm in _arms:
		var side := arm.side
		if arm.grip != null:
			arm.held_hand = to_local(arm.grip.get_global_transform_interpolated().origin)
			arm.held_shoulder = to_local(torso * Vector3(0.2 * side, -0.25, -0.05))
			arm.held_pole = global_transform.basis.inverse() * (torso.basis * Vector3(0.6 * side, -1.0, 0.25))
		var shoulder := Vector3(0.21 * side, -0.27, 0.1).lerp(arm.held_shoulder, blend)
		var hand := _free_hand(side, stride_phase, move_amount, sprint_amount).lerp(arm.held_hand, blend)
		var pole := Vector3(0.55 * side, -1.0, 0.1).lerp(arm.held_pole, blend)
		_solve(arm, shoulder, hand, pole, side * deg_to_rad(75.0) * (1.0 - blend))


func _free_hand(side: float, phase: float, move: float, sprint: float) -> Vector3:
	var target := Vector3(0.24 * side, -0.27, -0.5)
	# Idle breathing.
	target.y += sin(_breath * 1.6) * 0.006
	target.z += sin(_breath * 0.8 + side) * 0.004
	# Arms swing opposite each other while walking and pump harder in a sprint.
	var swing := sin(phase + (PI if side > 0.0 else 0.0))
	target.z += swing * (0.035 * move + 0.07 * sprint)
	target.y += -swing * (0.012 * move + 0.05 * sprint) + absf(cos(phase)) * 0.012 * move + 0.03 * sprint
	target.x += _sway.x + side * (0.02 * sprint + 0.04 * _air_blend)
	target.y += _sway.y + 0.05 * _air_blend
	return target


func _solve(arm: Arm, shoulder: Vector3, hand: Vector3, pole: Vector3, roll: float) -> void:
	var reach := hand - shoulder
	var distance := clampf(reach.length(), 0.05, UPPER_LENGTH + FOREARM_LENGTH - 0.005)
	var direction := reach.normalized()
	hand = shoulder + direction * distance
	var along := (UPPER_LENGTH * UPPER_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2.0 * distance)
	var out := sqrt(maxf(UPPER_LENGTH * UPPER_LENGTH - along * along, 0.0))
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var elbow := shoulder + direction * along + bend * out
	arm.upper.transform = Transform3D(Build.basis_along(elbow - shoulder), (shoulder + elbow) * 0.5)
	arm.fore.transform = Transform3D(Build.basis_along(hand - elbow), (elbow + hand) * 0.5)
	arm.hand.transform = Transform3D(Build.basis_along(hand - elbow) * Basis(Vector3.UP, roll), hand)


func _material(shader: Shader, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo", color)
	_materials.append(material)
	return material


func _segment(length: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.03
	mesh.height = length + 0.06
	mesh.radial_segments = 10
	mesh.rings = 4
	return _part(self, mesh, material)


func _hand(side: float, material: Material) -> Node3D:
	var wrist := Node3D.new()
	add_child(wrist)
	# A loose fist: back of the hand, curled fingers and thumb. Local +Z is the back of the hand.
	var palm := BoxMesh.new()
	palm.size = Vector3(0.078, 0.085, 0.046)
	_part(wrist, palm, material).position = Vector3(0.0, 0.043, 0.0)
	var fingers := BoxMesh.new()
	fingers.size = Vector3(0.076, 0.05, 0.05)
	_part(wrist, fingers, material).position = Vector3(0.0, 0.098, -0.014)
	var thumb := BoxMesh.new()
	thumb.size = Vector3(0.026, 0.06, 0.03)
	_part(wrist, thumb, material).position = Vector3(-side * 0.048, 0.06, -0.012)
	return wrist


func _part(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.layers = FIRST_PERSON_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _resize(segment: MeshInstance3D, radius: float, length: float) -> void:
	var mesh := segment.mesh as CapsuleMesh
	mesh.radius = radius
	mesh.height = length + radius * 2.0

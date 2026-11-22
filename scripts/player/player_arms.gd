class_name PlayerArms
extends Node3D
## Procedural first-person arms. A two-bone IK solve keeps each hand on an animated target
## (idle breathing, walk and sprint swing) or on grips supplied by a vehicle or workout station,
## so a new pose only needs hand targets. `set_physique` thickens the arms as the player grows.

const UPPER_LENGTH := 0.36
const FOREARM_LENGTH := 0.34
## Render layer 2: seen by the player camera, hidden from mirror cameras.
const FIRST_PERSON_LAYER := 2
const DEPTH_PULL := 0.9
## Shoulder position and elbow direction for the right arm in the torso frame; x mirrors for the left.
const DEFAULT_SHOULDER := Vector3(0.2, -0.25, -0.05)
const DEFAULT_POLE := Vector3(0.6, -1.0, 0.25)
## Distance from the wrist to the middle of the fist, so a held bar sits in the palm.
const PALM_OFFSET := 0.055

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

@export var skin_color := Color(0.96, 0.76, 0.62)
@export var sleeve_color := Color(0.16, 0.62, 0.86)


class Arm:
	var side := 1.0
	var upper: MeshInstance3D
	var cuff: MeshInstance3D
	var bulge: MeshInstance3D
	var fore: MeshInstance3D
	var elbow: MeshInstance3D
	var hand: Node3D
	var grip: Node3D
	var wrist := Vector3.ZERO
	# Last grip pose in arm space, kept so the hand eases off after letting go.
	var held_hand := Vector3.ZERO
	var held_axis := Vector3.RIGHT
	var held_shoulder := Vector3.ZERO
	var held_pole := Vector3.DOWN


var _arms: Array[Arm] = []
var _materials: Array[ShaderMaterial] = []
var _shoulder := DEFAULT_SHOULDER
var _pole := DEFAULT_POLE
var _girth := 0.0
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
		arm.upper = _part(self, CapsuleMesh.new(), skin)
		arm.cuff = _part(arm.upper, CapsuleMesh.new(), sleeve)
		arm.cuff.position.y = -UPPER_LENGTH * 0.3
		arm.bulge = _part(arm.upper, _sphere(), skin)
		arm.bulge.position.y = 0.02
		arm.fore = _part(self, CylinderMesh.new(), skin)
		arm.elbow = _part(arm.fore, _sphere(), skin)
		arm.elbow.position.y = -FOREARM_LENGTH * 0.5
		arm.hand = _hand(side, skin)
		_arms.append(arm)
	set_physique(0.0, 0.0)


## `arms` 0 (lanky) to 1 (shredded) sets the girth; `pump` 0 to 1 adds a temporary swell.
func set_physique(arms: float, pump: float = 0.0) -> void:
	_girth = clampf(arms, 0.0, 1.0)
	var swell := 1.0 + 0.1 * clampf(pump, 0.0, 1.0)
	var upper_radius := lerpf(0.03, 0.05, _girth) * swell
	var elbow_radius := lerpf(0.026, 0.044, _girth) * swell
	var wrist_radius := lerpf(0.022, 0.03, _girth)
	# Thicker than the arm itself once trained, so the biceps and triceps read as a belly.
	var belly := upper_radius * lerpf(0.9, 1.24, _girth)
	for arm in _arms:
		_capsule(arm.upper, upper_radius, UPPER_LENGTH)
		_capsule(arm.cuff, upper_radius * 1.3, UPPER_LENGTH * 0.45)
		arm.bulge.scale = Vector3(belly, belly * 2.6, belly)
		var fore := arm.fore.mesh as CylinderMesh
		fore.height = FOREARM_LENGTH
		fore.bottom_radius = elbow_radius
		fore.top_radius = wrist_radius
		fore.radial_segments = 10
		fore.rings = 1
		arm.elbow.scale = Vector3.ONE * elbow_radius
		arm.hand.scale = Vector3.ONE * lerpf(1.0, 1.15, _girth)


## Hands hold these nodes (handlebar grips, a barbell, dumbbells) until called again with nulls.
## Each grip's local X axis is the bar the fist wraps around. `shoulder` and `pole` place the
## right shoulder and aim the elbow in the torso frame passed to `animate`.
func set_grips(left: Node3D, right: Node3D, shoulder: Vector3 = DEFAULT_SHOULDER, pole: Vector3 = DEFAULT_POLE) -> void:
	_arms[0].grip = left
	_arms[1].grip = right
	if left != null or right != null:
		_shoulder = shoulder
		_pole = pole


## Mouse movement makes the hands trail slightly behind the view.
func add_sway(mouse_delta: Vector2) -> void:
	_sway = (_sway + Vector2(-mouse_delta.x, mouse_delta.y) * 0.00012).limit_length(0.03)


## Call every rendered frame. `torso` is the eye-level body frame used while holding grips.
func animate(delta: float, stride_phase: float, move_amount: float, sprint_amount: float, airborne: bool, torso: Transform3D) -> void:
	_breath += delta
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	_air_blend = move_toward(_air_blend, 1.0 if airborne else 0.0, delta * 6.0)
	var gripping := _arms[0].grip != null or _arms[1].grip != null
	_grip_blend = move_toward(_grip_blend, 1.0 if gripping else 0.0, delta * 4.0)
	# Holding real geometry needs true depth so hands and equipment sort correctly.
	var pull := 0.0 if _grip_blend > 0.0 else DEPTH_PULL
	for material in _materials:
		material.set_shader_parameter("depth_pull", pull)

	var blend := smoothstep(0.0, 1.0, _grip_blend)
	var to_arm_space := global_transform.basis.inverse()
	for arm in _arms:
		var side := arm.side
		if arm.grip != null:
			var grip := arm.grip.get_global_transform_interpolated()
			arm.held_hand = to_local(grip.origin)
			arm.held_axis = (to_arm_space * grip.basis.x).normalized()
			arm.held_shoulder = to_local(torso * Vector3(_shoulder.x * side, _shoulder.y, _shoulder.z))
			arm.held_pole = to_arm_space * (torso.basis * Vector3(_pole.x * side, _pole.y, _pole.z))
		var shoulder := Vector3(0.21 * side, -0.27, 0.1).lerp(arm.held_shoulder, blend)
		var hand := _free_hand(side, stride_phase, move_amount, sprint_amount).lerp(arm.held_hand, blend)
		var pole := Vector3(0.55 * side, -1.0, 0.1).lerp(arm.held_pole, blend)
		_solve(arm, shoulder, hand, pole, side * deg_to_rad(75.0) * (1.0 - blend), blend)


func _free_hand(side: float, phase: float, move: float, sprint: float) -> Vector3:
	# A trained fighter carries the hands a little higher and steadier.
	var steady := 1.0 - 0.45 * _girth
	var target := Vector3(0.24 * side, -0.27 + 0.02 * _girth, -0.5)
	# Idle breathing.
	target.y += sin(_breath * 1.6) * 0.006 * steady
	target.z += sin(_breath * 0.8 + side) * 0.004 * steady
	# Arms swing opposite each other while walking and pump harder in a sprint.
	var swing := sin(phase + (PI if side > 0.0 else 0.0))
	target.z += swing * (0.035 * move + 0.07 * sprint)
	target.y += -swing * (0.012 * move + 0.05 * sprint) + absf(cos(phase)) * 0.012 * move + 0.03 * sprint
	target.x += _sway.x * steady + side * (0.02 * sprint + 0.04 * _air_blend)
	target.y += _sway.y * steady + 0.05 * _air_blend
	return target


func _solve(arm: Arm, shoulder: Vector3, target: Vector3, pole: Vector3, roll: float, hold: float) -> void:
	var forearm := _place(arm, shoulder, target, pole)
	if hold > 0.0:
		# Second pass: back the wrist off so the grip sits in the palm.
		forearm = _place(arm, shoulder, target - forearm * PALM_OFFSET * hold, pole)
	var orientation := Build.basis_along(forearm) * Basis(Vector3.UP, roll)
	var across := arm.held_axis - forearm * arm.held_axis.dot(forearm)
	if hold > 0.0 and across.length_squared() > 0.001:
		# Wrap the fist around the held bar; keep the thumb on the inside.
		across = across.normalized() * (1.0 if across.x >= 0.0 else -1.0)
		orientation = orientation.slerp(Basis(across, forearm, across.cross(forearm)), hold)
	arm.hand.transform = Transform3D(orientation, arm.wrist)


## Positions the upper arm and forearm so the wrist reaches `target`; returns the forearm direction.
func _place(arm: Arm, shoulder: Vector3, target: Vector3, pole: Vector3) -> Vector3:
	var reach := target - shoulder
	var distance := clampf(reach.length(), 0.05, UPPER_LENGTH + FOREARM_LENGTH - 0.005)
	var direction := reach.normalized()
	arm.wrist = shoulder + direction * distance
	var along := (UPPER_LENGTH * UPPER_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2.0 * distance)
	var out := sqrt(maxf(UPPER_LENGTH * UPPER_LENGTH - along * along, 0.0))
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var elbow := shoulder + direction * along + bend * out
	var forearm := (arm.wrist - elbow).normalized()
	arm.upper.transform = Transform3D(Build.basis_along(elbow - shoulder), (shoulder + elbow) * 0.5)
	arm.fore.transform = Transform3D(Build.basis_along(forearm), (elbow + arm.wrist) * 0.5)
	return forearm


func _material(shader: Shader, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo", color)
	_materials.append(material)
	return material


func _sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh


func _capsule(segment: MeshInstance3D, radius: float, length: float) -> void:
	var mesh := segment.mesh as CapsuleMesh
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 4


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

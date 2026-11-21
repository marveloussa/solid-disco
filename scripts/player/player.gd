class_name Player
extends CharacterBody3D
## First-person controller: walking, sprinting, jumping, mouse look, interaction and riding.
##
## The body moves on the physics tick. `Head` is top-level with physics interpolation off: every
## rendered frame it follows the body's interpolated position and takes mouse rotation directly,
## which keeps the view smooth at any refresh rate.

signal interact_prompt_changed(text: String)
signal vehicle_changed(vehicle: Bicycle)

const RIDE_PITCH := -0.14
const VIEW_BLEND_TIME := 0.3
const DISMOUNT_PROMPT_SPEED := 2.5

@export_group("Movement")
@export var walk_speed := 4.2
@export var sprint_speed := 7.2
@export var ground_acceleration := 10.0
@export var air_acceleration := 2.5
@export var jump_velocity := 5.8
@export var gravity := 16.0
@export var sprint_stamina_cost := 18.0

@export_group("View")
@export var mouse_sensitivity := 0.0022
@export var eye_height := 1.78
@export var base_fov := 80.0
@export var speed_fov_boost := 7.0
## Share of the bike's lean that rolls the camera.
@export_range(0.0, 1.0) var ride_camera_lean := 0.6

## The bicycle currently ridden, or null on foot.
var vehicle: Bicycle = null
## Set false to freeze input (cutscenes, workout minigames).
var controls_enabled := true
var is_sprinting := false

var _yaw := 0.0
var _pitch := 0.0
var _ride_look := 0.0
var _stride := 0.0
var _move_amount := 0.0
var _sprint_amount := 0.0
var _camera_roll := 0.0
var _prompt := ""
var _focus: Interactable = null
var _view_blend := 1.0
var _view_from := Transform3D.IDENTITY

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var arms: PlayerArms = $Head/Camera3D/Arms
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var model: CharacterModel = $Model
@onready var stamina: Stamina = $Stamina
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"player")
	_yaw = rotation.y
	interact_ray.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.physique_changed.connect(_apply_physique)
	_apply_physique(GameState.muscle)
	head.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), global_position + Vector3.UP * eye_height)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"interact"):
		_interact()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		_move_on_foot(delta)
		model.animate(delta, _stride, _move_amount, _pitch, false)
	else:
		# The bicycle carries this body; see Bicycle._physics_process.
		model.animate(delta, _stride, 0.0, _pitch, true, vehicle.model.pedal_phase, vehicle.lean)
	_update_focus()


func _process(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() if vehicle == null else 0.0
	var grounded := vehicle == null and is_on_floor()
	_move_amount = lerpf(_move_amount, clampf(speed / walk_speed, 0.0, 1.0) if grounded else 0.0, 1.0 - exp(-10.0 * delta))
	_sprint_amount = lerpf(_sprint_amount, 1.0 if is_sprinting and grounded else 0.0, 1.0 - exp(-8.0 * delta))
	_stride = fmod(_stride + delta * TAU * lerpf(0.95, 1.4, _sprint_amount) * _move_amount, TAU)

	var seat := Transform3D.IDENTITY
	var view: Transform3D
	var roll := 0.0
	var fast := _sprint_amount
	if vehicle != null:
		seat = vehicle.get_seat_transform()
		view = Transform3D(seat.basis * Basis.from_euler(Vector3(_pitch, _ride_look, 0.0)), seat.origin)
		roll = vehicle.lean * ride_camera_lean
		fast = clampf((vehicle.speed - vehicle.cruise_speed) / (vehicle.boost_speed - vehicle.cruise_speed), 0.0, 1.0)
	else:
		var look := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
		var bob := Vector3.UP * sin(_stride * 2.0) * 0.032 + look.x * cos(_stride) * 0.018
		view = Transform3D(look, get_global_transform_interpolated().origin + Vector3.UP * eye_height + bob * _move_amount)

	# Ease the view between standing and seated positions when mounting or dismounting.
	if _view_blend < 1.0:
		_view_blend = minf(_view_blend + delta / VIEW_BLEND_TIME, 1.0)
		view = _view_from.interpolate_with(view, smoothstep(0.0, 1.0, _view_blend))
	head.global_transform = view

	_camera_roll = lerpf(_camera_roll, roll, 1.0 - exp(-8.0 * delta))
	camera.rotation.z = _camera_roll
	camera.fov = lerpf(camera.fov, base_fov + speed_fov_boost * fast, 1.0 - exp(-6.0 * delta))
	arms.animate(delta, _stride, _move_amount, _sprint_amount, vehicle == null and not is_on_floor(), seat)


## Called by a vehicle when the player mounts it.
func enter_vehicle(target: Bicycle) -> void:
	_begin_view_blend()
	vehicle = target
	velocity = Vector3.ZERO
	is_sprinting = false
	collision_shape.set_deferred(&"disabled", true)
	_ride_look = 0.0
	_pitch = RIDE_PITCH
	arms.set_grips(target.model.grip_left, target.model.grip_right)
	global_transform = target.global_transform
	reset_physics_interpolation()
	vehicle_changed.emit(vehicle)


## Called by the vehicle on dismount with the spot to stand on.
func exit_vehicle(exit_position: Vector3) -> void:
	_begin_view_blend()
	_yaw = wrapf(vehicle.global_rotation.y + _ride_look, -PI, PI)
	vehicle = null
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), exit_position)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	collision_shape.set_deferred(&"disabled", false)
	arms.set_grips(null, null)
	vehicle_changed.emit(null)


func _look(relative: Vector2) -> void:
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -1.45, 1.45)
	if vehicle != null:
		_ride_look = clampf(_ride_look - relative.x * mouse_sensitivity, -1.9, 1.9)
	else:
		_yaw = wrapf(_yaw - relative.x * mouse_sensitivity, -PI, PI)
	arms.add_sway(relative)


func _move_on_foot(delta: float) -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	var input := Vector2.ZERO
	var wants_sprint := false
	var wants_jump := false
	if controls_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		wants_sprint = Input.is_action_pressed(&"sprint") and input.y < -0.1
		wants_jump = Input.is_action_just_pressed(&"jump")

	# Sprinting only costs stamina while actually covering ground.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	is_sprinting = wants_sprint and (not moving or stamina.spend(sprint_stamina_cost * delta))
	var target := transform.basis * Vector3(input.x, 0.0, input.y) * (sprint_speed if is_sprinting else walk_speed)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	var planar := Vector3(velocity.x, 0.0, velocity.z).lerp(target, 1.0 - exp(-acceleration * delta))
	velocity.x = planar.x
	velocity.z = planar.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif wants_jump:
		velocity.y = jump_velocity
	move_and_slide()


func _interact() -> void:
	if not controls_enabled:
		return
	if vehicle != null:
		vehicle.dismount()
	elif _focus != null:
		_focus.interact(self)


func _update_focus() -> void:
	var prompt := ""
	_focus = null
	if vehicle != null:
		# Only offered at walking pace, so the prompt stays out of the way while riding.
		if absf(vehicle.speed) < DISMOUNT_PROMPT_SPEED:
			prompt = vehicle.dismount_text
	elif controls_enabled and interact_ray.is_colliding():
		_focus = Interactable.find_for(interact_ray.get_collider())
		if _focus != null:
			prompt = _focus.action_text
	if prompt != _prompt:
		_prompt = prompt
		interact_prompt_changed.emit(prompt)


func _begin_view_blend() -> void:
	_view_from = head.global_transform
	_view_blend = 0.0


func _apply_physique(muscle: float) -> void:
	arms.muscle = muscle
	model.muscle = muscle

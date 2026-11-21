class_name HUD
extends CanvasLayer
## Minimal dark HUD: profile (rank, days, level), stamina, objective, interaction prompt,
## toast messages and a waypoint marker. Driven by GameState signals and the bound player.

const STAMINA_COLOR := Color(1.0, 0.62, 0.15)
const STAMINA_LOW_COLOR := Color(0.95, 0.27, 0.25)
const WAYPOINT_MARGIN := 60.0

var _prompt_tween: Tween
var _toast_tween: Tween
var _stamina_fill: StyleBoxFlat

@onready var root: Control = $Root
@onready var rank_label: Label = %RankLabel
@onready var level_label: Label = %LevelLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt: Control = %Prompt
@onready var prompt_key: Label = %PromptKey
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel
@onready var waypoint: Control = %Waypoint
@onready var waypoint_label: Label = %WaypointLabel
@onready var controls_hint: Label = %ControlsHint


func _ready() -> void:
	_stamina_fill = stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	prompt.modulate.a = 0.0
	toast_label.modulate.a = 0.0
	waypoint.visible = false
	prompt_key.text = _key_name(&"interact")

	GameState.profile_changed.connect(_refresh_profile)
	GameState.objective_changed.connect(_set_objective)
	GameState.toast_requested.connect(show_toast)
	_refresh_profile()
	_set_objective(GameState.objective)

	var fade := create_tween()
	fade.tween_interval(14.0)
	fade.tween_property(controls_hint, "modulate:a", 0.0, 1.5)


## Hooks the HUD to a player's prompt and stamina signals.
func bind_player(player: Player) -> void:
	player.interact_prompt_changed.connect(set_prompt)
	player.stamina.changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina.current, player.stamina.maximum)


## Shows "[key] text" under the crosshair, or hides the prompt when `text` is empty.
func set_prompt(text: String) -> void:
	if not text.is_empty():
		prompt_label.text = text
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(prompt, "modulate:a", 0.0 if text.is_empty() else 1.0, 0.12)


func show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	_update_waypoint()


func _update_waypoint() -> void:
	var target := get_tree().get_first_node_in_group(&"waypoint") as Beacon
	var camera := get_viewport().get_camera_3d()
	if target == null or camera == null or not target.active:
		waypoint.visible = false
		return
	var point := target.global_position + Vector3.UP * target.marker_height
	var view := root.size
	var screen := camera.unproject_position(point)
	if camera.is_position_behind(point):
		# Pin the marker to the screen edge on the side the target lies.
		var side := (camera.global_transform.affine_inverse() * point).x
		screen = Vector2(view.x if side > 0.0 else 0.0, view.y * 0.5)
	var margin := Vector2(WAYPOINT_MARGIN, WAYPOINT_MARGIN)
	waypoint.position = screen.clamp(margin, view - margin)
	waypoint.visible = true
	waypoint_label.text = "%s  %d m" % [target.title, roundi(camera.global_position.distance_to(point))]


func _refresh_profile() -> void:
	rank_label.text = GameState.get_profile_title()
	level_label.text = "Lvl %d" % GameState.level


func _set_objective(text: String) -> void:
	objective_label.text = text
	objective_label.visible = not text.is_empty()


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	if _stamina_fill != null:
		_stamina_fill.bg_color = STAMINA_LOW_COLOR.lerp(STAMINA_COLOR, clampf(current / maximum * 2.5, 0.0, 1.0))


## Display name of the first key bound to `action`, so prompts follow rebinds.
func _key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "?"

extends Node
## Shared base for the walkthrough runners. Each area script extends this file, implements
## `run()` and is started as the scene `res://tests/walkthrough/<area>.tscn`.
##
## The real `res://scenes/main.tscn` is instanced under the root and made the current scene (so
## `reload_current_scene()`, used by Reset Career, behaves as in the shipped game). The runner
## stays alive next to it and drives it with input events.
##
## Headless caveat: the headless display server cannot capture the mouse, so `Input.mouse_mode`
## stays VISIBLE and the Player swallows mouse-button events as "click to recapture". Keyboard
## events and polled actions therefore use real key events; the mouse-only actions
## (strike_left / strike_right, curl) are delivered as InputEventAction, which updates the same
## Input state and travels the same `_unhandled_input` path. Mouse look is exercised by calling
## `player._look()` (what a captured mouse-motion event calls) because it is the only way to aim.

const MAIN_SCENE := "res://scenes/main.tscn"
const SAVE_PATH := "user://gym_mma_save.json"
const FPS := 60.0
const SCREEN_CENTER := Vector2(960.0, 540.0)

var area := "area"
var passed := 0
var failed := 0
var main: Node
var player: Player
var hud: HUD
var last_prompt := ""
var _held_keys := {}
var _boot_frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()


func _start() -> void:
	print("== AREA %s ==" % area)
	await run()
	finish()


## Override in the area script.
func run() -> void:
	pass


func finish() -> void:
	release_all()
	print("RESULT area=%s passed=%d failed=%d" % [area, passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


# --- Reporting -------------------------------------------------------------------------------

func check(check_name: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passed += 1
		print("PASS %s" % check_name)
	else:
		failed += 1
		print("FAIL %s: %s" % [check_name, detail])
	return ok


func note(text: String) -> void:
	print("NOTE %s" % text)


func near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


# --- Booting the game ------------------------------------------------------------------------

## Wipes the career, settings and save file so the next boot is a brand-new install.
func wipe_career() -> void:
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(path)
	PlayerStats.reset_career()
	SaveManager.reached_gym = false
	SaveManager.has_save = false
	SaveManager.settings = SaveManager.DEFAULT_SETTINGS.duplicate()
	SaveManager._apply_settings()


## Instances the real main scene as the current scene. Returns once the player and HUD exist.
func boot() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await frames(2)
	main = load(MAIN_SCENE).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await frames(4)
	_bind_main()
	_boot_frame = Engine.get_physics_frames()


func _bind_main() -> void:
	main = get_tree().current_scene
	player = main.get_node("Player") as Player
	hud = main.get_node("HUD") as HUD


## After `reload_current_scene()` the scene is a brand-new instance.
func rebind_after_reload() -> void:
	await frames(6)
	_bind_main()


## Seconds of simulated time since boot (60 physics ticks per second at --fixed-fps 60).
func sim_time() -> float:
	return float(Engine.get_physics_frames() - _boot_frame) / FPS


# --- Time ------------------------------------------------------------------------------------

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func secs(seconds: float) -> void:
	await frames(maxi(roundi(seconds * FPS), 1))


## Steps until `condition` is true; returns whether it became true within `timeout` seconds.
func until(condition: Callable, timeout: float) -> bool:
	var limit := maxi(roundi(timeout * FPS), 1)
	for i in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


# --- Input -----------------------------------------------------------------------------------

func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.key_label = code
	event.pressed = pressed
	return event


func key_down(code: Key) -> void:
	if _held_keys.has(code):
		return
	_held_keys[code] = true
	Input.parse_input_event(_key_event(code, true))


func key_up(code: Key) -> void:
	if not _held_keys.has(code):
		return
	_held_keys.erase(code)
	Input.parse_input_event(_key_event(code, false))


func set_key(code: Key, down: bool) -> void:
	if down:
		key_down(code)
	else:
		key_up(code)


## Press and release one frame later (a tap).
func tap_key(code: Key, hold_frames: int = 2) -> void:
	key_down(code)
	await frames(hold_frames)
	key_up(code)
	await frames(1)


func release_all() -> void:
	for code: Key in _held_keys.keys():
		key_up(code)
	for action: StringName in [&"strike_left", &"strike_right", &"lift", &"curl_left", &"curl_right"]:
		Input.action_release(action)


## Delivers an action as an event (a stand-in for a mouse button the headless display cannot capture).
func action_down(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)


func action_up(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


func tap_action(action: StringName, hold_frames: int = 2) -> void:
	action_down(action)
	await frames(hold_frames)
	action_up(action)
	await frames(1)


func mouse_button(button: MouseButton, pressed: bool, at: Vector2 = SCREEN_CENTER) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if (pressed and button == MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(event)


## A real mouse click (move, press, release) on a GUI control.
func click_control(control: Control) -> void:
	var rect := control.get_global_rect()
	var at := rect.position + rect.size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frames(2)
	mouse_button(MOUSE_BUTTON_LEFT, true, at)
	await frames(2)
	mouse_button(MOUSE_BUTTON_LEFT, false, at)
	await frames(2)


func press_e() -> void:
	await tap_key(KEY_E)


func press_escape() -> void:
	await tap_key(KEY_ESCAPE)


# --- Player helpers --------------------------------------------------------------------------

func place_player(spot: Vector3, yaw_degrees: float = 0.0) -> void:
	player.place_at(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), spot), true)
	await frames(2)


func yaw() -> float:
	return player._yaw


## Turns the view to `point` with the mouse-look code path. `pitch_too` also tilts the view.
func look_at_point(point: Vector3, pitch_too: bool = true) -> void:
	var eyes := player.head.global_position
	var delta := point - eyes
	var want_yaw := atan2(-delta.x, -delta.z)
	var want_pitch := atan2(delta.y, Vector2(delta.x, delta.z).length()) if pitch_too else 0.0
	var scale := player.mouse_sensitivity * SaveManager.get_mouse_sensitivity()
	var turn := wrapf(want_yaw - player._yaw, -PI, PI)
	player._look(Vector2(-turn / scale, -(want_pitch - player._pitch) / scale))
	await frames(2)


## Walks to each ground waypoint with W, steering by mouse look. Returns false if stuck or late.
func walk_path(points: Array, tolerance: float = 0.9, timeout_each: float = 25.0) -> bool:
	var ok := true
	for point: Vector3 in points:
		if not await _walk_to(point, tolerance, timeout_each):
			ok = false
			break
	key_up(KEY_W)
	return ok


func _walk_to(point: Vector3, tolerance: float, timeout: float) -> bool:
	var limit := roundi(timeout * FPS)
	key_down(KEY_W)
	var last := player.global_position
	var stuck := 0
	for i in limit:
		var offset := point - player.global_position
		offset.y = 0.0
		if offset.length() <= tolerance:
			return true
		var want_yaw := atan2(-offset.x, -offset.z)
		var scale := player.mouse_sensitivity * SaveManager.get_mouse_sensitivity()
		var turn := wrapf(want_yaw - player._yaw, -PI, PI)
		player._look(Vector2(-turn / scale, 0.0))
		await get_tree().physics_frame
		if i % 30 == 29:
			if player.global_position.distance_to(last) < 0.25:
				stuck += 1
				if stuck >= 3:
					return false
			else:
				stuck = 0
			last = player.global_position
	return false


# --- Finding things in the world -------------------------------------------------------------

func stations_of(station_type: StringName) -> Array[WorkoutStation]:
	var found: Array[WorkoutStation] = []
	for node in get_tree().get_nodes_in_group(&"gym_stations"):
		var station := node as WorkoutStation
		if station != null and station.station_type == station_type:
			found.append(station)
	return found


func gym_node() -> Node3D:
	return main.get_node("Gym") as Node3D


## Gym-local (x, z) on storey `floor_index` (0 based) to a world point standing on that floor.
func gym_point(x: float, z: float, floor_index: int = 0) -> Vector3:
	return gym_node().global_transform * Vector3(x, 5.0 * floor_index + 0.05, z)


## Stands in front of `body_node` (any node whose interactable the crosshair should find) and
## aims at `target`. Returns the Interactable under the crosshair, or null.
func aim_and_find(spots: Array, target: Vector3) -> Interactable:
	for spot: Vector3 in spots:
		await place_player(spot, 0.0)
		await look_at_point(target)
		await frames(3)
		if player._focus != null:
			return player._focus
	return null


## The prompt fades with a tween (it keeps its old text), so "shown" means mostly opaque.
func hud_prompt_text() -> String:
	return hud.prompt_label.text if hud.prompt.visible and hud.prompt.modulate.a > 0.5 else ""


# --- Workout stations ------------------------------------------------------------------------

## Candidate standing spots around a station (world), all on its floor.
func station_spots(station: Node3D) -> Array:
	var spots: Array = []
	for offset: Vector3 in [Vector3(0, 0, 1.8), Vector3(0, 0, -1.8), Vector3(1.8, 0, 0), Vector3(-1.8, 0, 0), Vector3(0, 0, 2.4), Vector3(0, 0, -2.4)]:
		var spot: Vector3 = station.global_transform * offset
		spot.y = station.global_position.y + 0.05
		spots.append(spot)
	return spots


func station_aim_point(station: WorkoutStation) -> Vector3:
	return station.global_position + Vector3(0.0, station.collider_lift + station.collider_size.y * 0.5, 0.0)


## Walks up to a station the way a player would: stands near it, aims the crosshair and presses E.
## Returns true once the player is seated at that station.
func use_station(station: WorkoutStation) -> bool:
	var found := await aim_and_find(station_spots(station), station_aim_point(station))
	if found == null or found != station._interactable:
		return false
	await frames(12)
	last_prompt = hud_prompt_text()
	await press_e()
	await frames(3)
	return player.station == station


## Presses `code` (E or Esc) to leave and reports whether control is back.
func leave_station(station: WorkoutStation, code: Key = KEY_E) -> bool:
	await tap_key(code)
	await frames(4)
	return player.station == null and station.user == null


## After leaving: walk directly away from the station for one second and see that the player moved.
func walks_away_from(station: Node3D) -> bool:
	var spot := player.global_position
	var away := spot - station.global_position
	away.y = 0.0
	var forward := -player.head.global_transform.basis.z
	forward.y = 0.0
	var key := KEY_W if forward.dot(away) > 0.0 else KEY_S
	key_down(key)
	await secs(1.0)
	key_up(key)
	await frames(2)
	return player.global_position.distance_to(spot) > 1.5 and player.controls_enabled

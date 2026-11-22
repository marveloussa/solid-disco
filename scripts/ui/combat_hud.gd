class_name CombatHUD
extends Control
## Fight overlay. While the stance is up it shows the hit counter and the fight controls; during
## a bout it adds the fighter's health and stamina, the opponent's name, tag, health, guard and
## stamina, the 3-2-1 countdown, the counter flash and, at the end, the result screen with the
## reward breakdown.
##
## The RingManager opens and closes the bout views; everything else follows the player's
## CombatController.

signal rematch_requested
signal next_requested
signal exit_requested

const CONTROLS := "LMB  Jab     RMB  Cross     F  Kick     Shift  Block     A / D / S + Space  Slip"

var _combat: CombatController
var _combo_tween: Tween
var _count_tween: Tween
var _flash_tween: Tween

var _opponent_panel: Control
var _opponent_name: Label
var _opponent_tag: Label
var _opponent_health: ProgressBar
var _opponent_guard: ProgressBar
var _opponent_stamina: ProgressBar
var _player_panel: Control
var _player_health: ProgressBar
var _player_health_text: Label
var _player_stamina: ProgressBar
var _status: Label
var _streak_box: Control
var _streak_count: Label
var _combo_name: Label
var _count: Label
var _counter: Label
var _flash: ColorRect
var _hint: Label
var _result: Control
var _result_title: Label
var _result_subtitle: Label
var _result_rows: VBoxContainer
var _result_footer: Label
var _next_button: Button


func _ready() -> void:
	add_to_group(&"combat_hud")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_flash()
	_build_opponent_panel()
	_build_player_panel()
	_build_streak()
	_build_centre()
	_build_result()
	for node: Control in [_opponent_panel, _player_panel, _streak_box, _hint, _result]:
		node.visible = false
	_count.modulate.a = 0.0
	_counter.modulate.a = 0.0
	_combo_name.modulate.a = 0.0
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	PlayerStats.status_changed.connect(_refresh_status)
	_on_stamina_changed(PlayerStats.stamina, PlayerStats.max_stamina)


func _process(_delta: float) -> void:
	if _player_panel.visible:
		_refresh_status()


## Follows `player`'s CombatController.
func bind(player: Player) -> void:
	_combat = player.combat
	_combat.stance_changed.connect(_on_stance_changed)
	_combat.health_changed.connect(_on_health_changed)
	_combat.streak_changed.connect(_on_streak_changed)
	_combat.combo_landed.connect(_on_combo_landed)
	_combat.counter_opened.connect(_on_counter_opened)


## Shows the bout views for a fight against `opponent`.
func open_bout(profile: FighterProfile, opponent: EnemyFighter) -> void:
	_result.visible = false
	_opponent_name.text = profile.fighter_name.to_upper()
	_opponent_tag.text = profile.get_tag()
	_set_bar(opponent.health, profile.max_health, _opponent_health)
	_on_opponent_guard_changed(opponent.guard, profile.guard_max)
	_set_bar(opponent.stamina, profile.max_stamina, _opponent_stamina)
	opponent.health_changed.connect(_set_bar.bind(_opponent_health))
	opponent.guard_changed.connect(_on_opponent_guard_changed)
	opponent.stamina_changed.connect(_set_bar.bind(_opponent_stamina))
	_opponent_panel.visible = true
	_player_panel.visible = true
	_on_health_changed(_combat.health, _combat.max_health)
	for node: Control in [_opponent_panel, _player_panel]:
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, 0.25)


func close_bout() -> void:
	_opponent_panel.visible = false
	_player_panel.visible = false
	_result.visible = false


## Big centre-screen countdown text: "3", "2", "1", "FIGHT!".
func show_count(text: String) -> void:
	_count.text = text
	_count.add_theme_color_override(&"font_color", UiKit.ACCENT if text.length() > 1 else UiKit.WHITE)
	_count.pivot_offset = _count.size * 0.5
	_count.scale = Vector2.ONE * 1.7
	_count.modulate.a = 1.0
	if _count_tween != null:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_property(_count, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_tween.tween_interval(0.3)
	_count_tween.tween_property(_count, "modulate:a", 0.0, 0.2)


## Result screen. `summary` comes from RingManager: "won", "title", "subtitle", "rows" (label,
## value, colour), "footer", "has_next".
func show_result(summary: Dictionary) -> void:
	var won: bool = summary["won"]
	_result_title.text = summary["title"]
	_result_title.add_theme_color_override(&"font_color", UiKit.WHITE if won else UiKit.BAD)
	_result_subtitle.text = summary["subtitle"]
	_result_footer.text = summary["footer"]
	for child in _result_rows.get_children():
		child.queue_free()
	var rows: Array = summary["rows"]
	for entry: Array in rows:
		_result_rows.add_child(UiKit.row(entry[0], entry[1], entry[2]))
	_next_button.visible = summary["has_next"]
	_result.visible = true
	_result.modulate.a = 0.0
	create_tween().tween_property(_result, "modulate:a", 1.0, 0.3)


# --- Signals ---------------------------------------------------------------------------------

func _on_stance_changed(active: bool) -> void:
	_hint.visible = active
	if not active:
		_streak_box.visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	_set_bar(current, maximum, _player_health)
	_player_health_text.text = "%d / %d" % [ceili(current), roundi(maximum)]
	UiKit.fill_of(_player_health).bg_color = UiKit.BAD.lerp(UiKit.GOOD, clampf(current / maximum * 1.6, 0.0, 1.0))


func _on_stamina_changed(current: float, maximum: float) -> void:
	_set_bar(current, maximum, _player_stamina)
	UiKit.fill_of(_player_stamina).bg_color = UiKit.BAD.lerp(UiKit.WHITE, clampf(current / maximum * 2.5, 0.0, 1.0))


func _on_opponent_guard_changed(current: float, maximum: float) -> void:
	_set_bar(current, maximum, _opponent_guard)
	UiKit.fill_of(_opponent_guard).bg_color = UiKit.BAD if current <= 0.0 else UiKit.ACCENT


func _on_streak_changed(hits: int) -> void:
	_streak_box.visible = hits >= 2
	if hits < 2:
		return
	_streak_count.text = "x%d" % hits
	_streak_count.pivot_offset = _streak_count.size * 0.5
	_streak_count.scale = Vector2.ONE * 1.35
	create_tween().tween_property(_streak_count, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_combo_landed(text: String) -> void:
	if text.begins_with("COUNTER") or text.begins_with("KO"):
		_flash_screen(Color(1.0, 1.0, 1.0, 0.3), 0.22)
	_combo_name.text = text
	_combo_name.modulate.a = 1.0
	if _combo_tween != null:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_interval(0.9)
	_combo_tween.tween_property(_combo_name, "modulate:a", 0.0, 0.35)


## Perfect dodge: flash the screen and call the counter.
func _on_counter_opened(_seconds: float) -> void:
	_flash_screen(Color(0.85, 0.75, 1.0, 0.34), 0.3)
	_counter.modulate.a = 1.0
	_flash_tween.tween_property(_counter, "modulate:a", 0.0, 0.25).set_delay(0.45)


func _flash_screen(color: Color, seconds: float) -> void:
	_flash.color = color
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(_flash, "color:a", 0.0, seconds)


func _refresh_status() -> void:
	if PlayerStats.is_strained():
		_status.text = "STRAINED   slower, weaker strikes"
		_status.add_theme_color_override(&"font_color", UiKit.BAD)
	elif PlayerStats.is_exhausted:
		_status.text = "GASSED   no guard, slow punches"
		_status.add_theme_color_override(&"font_color", UiKit.GOLD)
	else:
		_status.text = ""


func _set_bar(current: float, maximum: float, bar: ProgressBar) -> void:
	bar.max_value = maximum
	bar.value = current


# --- Layout ----------------------------------------------------------------------------------

func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)


func _build_opponent_panel() -> void:
	var panel := UiKit.panel(SIDE_TOP, 16.0)
	panel.name = "OpponentPanel"
	_anchor(panel, 0.5, 0.0, Vector2(-320.0, 26.0), Vector2(640.0, 0.0))
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 7)
	panel.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	_opponent_name = UiKit.label("OPPONENT", 26)
	header.add_child(_opponent_name)
	header.add_child(UiKit.spacer())
	_opponent_tag = UiKit.label("", 16, UiKit.MUTED)
	header.add_child(_opponent_tag)
	_opponent_health = UiKit.bar(UiKit.WHITE, 18.0)
	rows.add_child(_opponent_health)
	var guard_row := HBoxContainer.new()
	guard_row.add_theme_constant_override(&"separation", 10)
	rows.add_child(guard_row)
	var guard_caption := UiKit.label("GUARD", 13, UiKit.MUTED)
	guard_caption.custom_minimum_size.x = 70.0
	guard_row.add_child(guard_caption)
	_opponent_guard = UiKit.bar(UiKit.ACCENT, 10.0)
	guard_row.add_child(_opponent_guard)
	var stamina_row := HBoxContainer.new()
	stamina_row.add_theme_constant_override(&"separation", 10)
	rows.add_child(stamina_row)
	var stamina_caption := UiKit.label("STAMINA", 13, UiKit.MUTED)
	stamina_caption.custom_minimum_size.x = 70.0
	stamina_row.add_child(stamina_caption)
	_opponent_stamina = UiKit.bar(UiKit.GOLD, 6.0)
	stamina_row.add_child(_opponent_stamina)
	_opponent_panel = panel


func _build_player_panel() -> void:
	var panel := UiKit.panel(SIDE_BOTTOM, 14.0)
	panel.name = "PlayerPanel"
	# Bottom left, clear of the gloves.
	_anchor(panel, 0.0, 1.0, Vector2(28.0, -36.0), Vector2(470.0, 0.0))
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 7)
	panel.add_child(rows)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override(&"separation", 10)
	rows.add_child(health_row)
	var health_caption := UiKit.label("HEALTH", 13, UiKit.MUTED)
	health_caption.custom_minimum_size.x = 70.0
	health_row.add_child(health_caption)
	_player_health = UiKit.bar(UiKit.GOOD, 18.0)
	health_row.add_child(_player_health)
	_player_health_text = UiKit.label("100 / 100", 15)
	_player_health_text.custom_minimum_size.x = 86.0
	_player_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_row.add_child(_player_health_text)
	var stamina_row := HBoxContainer.new()
	stamina_row.add_theme_constant_override(&"separation", 10)
	rows.add_child(stamina_row)
	var stamina_caption := UiKit.label("STAMINA", 13, UiKit.MUTED)
	stamina_caption.custom_minimum_size.x = 70.0
	stamina_row.add_child(stamina_caption)
	_player_stamina = UiKit.bar(UiKit.WHITE, 10.0)
	stamina_row.add_child(_player_stamina)
	var pad := Control.new()
	pad.custom_minimum_size.x = 86.0
	stamina_row.add_child(pad)
	_status = UiKit.label("", 14, UiKit.BAD)
	rows.add_child(_status)
	_player_panel = panel


func _build_streak() -> void:
	var box := VBoxContainer.new()
	box.name = "Streak"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchor(box, 1.0, 0.5, Vector2(-300.0, -110.0), Vector2(240.0, 150.0))
	add_child(box)
	_streak_count = UiKit.outline(UiKit.label("x2", 76), 12)
	_streak_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_streak_count)
	var caption := UiKit.outline(UiKit.label("HITS", 18, UiKit.MUTED), 6)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	_streak_box = box


func _build_centre() -> void:
	_count = UiKit.outline(UiKit.label("3", 170), 22)
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anchor(_count, 0.5, 0.5, Vector2(-450.0, -230.0), Vector2(900.0, 240.0))
	add_child(_count)

	_counter = UiKit.outline(UiKit.label("COUNTER!", 54, UiKit.ACCENT_HOT), 12)
	_counter.name = "Counter"
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_counter, 0.5, 0.5, Vector2(-400.0, 90.0), Vector2(800.0, 70.0))
	add_child(_counter)

	_combo_name = UiKit.outline(UiKit.label("", 36, UiKit.ACCENT_HOT), 10)
	_combo_name.name = "ComboName"
	_combo_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_combo_name, 1.0, 0.5, Vector2(-420.0, 44.0), Vector2(480.0, 50.0))
	add_child(_combo_name)

	_hint = UiKit.outline(UiKit.label(CONTROLS, 18, Color(0.9, 0.92, 0.97, 0.9), false), 6)
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_hint, 0.5, 1.0, Vector2(-600.0, -64.0), Vector2(1200.0, 32.0))
	add_child(_hint)


func _build_result() -> void:
	_result = ColorRect.new()
	_result.name = "Result"
	(_result as ColorRect).color = Color(0.02, 0.02, 0.04, 0.62)
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows clicks so the game does not grab the mouse back behind the buttons.
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(centre)
	var panel := UiKit.panel(SIDE_TOP, 30.0, UiKit.PANEL_SOLID)
	panel.custom_minimum_size.x = 580.0
	centre.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 10)
	panel.add_child(rows)
	_result_title = UiKit.label("VICTORY", 64)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_result_title)
	_result_subtitle = UiKit.label("", 20, UiKit.MUTED, false)
	_result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_result_subtitle)
	rows.add_child(_rule())
	_result_rows = VBoxContainer.new()
	_result_rows.add_theme_constant_override(&"separation", 8)
	rows.add_child(_result_rows)
	rows.add_child(_rule())
	_result_footer = UiKit.label("", 17, UiKit.ACCENT)
	_result_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_result_footer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 14)
	rows.add_child(buttons)
	_next_button = UiKit.button("NEXT FIGHT", true)
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	buttons.add_child(_next_button)
	var rematch_button := UiKit.button("REMATCH")
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	buttons.add_child(rematch_button)
	var exit_button := UiKit.button("EXIT RING")
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	buttons.add_child(exit_button)


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1.0, 1.0, 1.0, 0.12)
	line.custom_minimum_size.y = 2.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Pins `node` to a point of the screen (`ax`, `ay` as fractions) with an offset and a size.
func _anchor(node: Control, ax: float, ay: float, offset: Vector2, extent: Vector2) -> void:
	node.anchor_left = ax
	node.anchor_right = ax
	node.anchor_top = ay
	node.anchor_bottom = ay
	node.offset_left = offset.x
	node.offset_top = offset.y
	node.offset_right = offset.x + extent.x
	node.offset_bottom = offset.y + extent.y
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_END if ay < 1.0 else Control.GROW_DIRECTION_BEGIN

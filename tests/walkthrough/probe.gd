extends Node
func _ready() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for i in 5:
		await get_tree().physics_frame
	var hud: HUD = main.get_node("HUD")
	var root := get_tree().root
	print("root size ", root.size, " visible rect ", root.get_visible_rect(), " content_scale ", root.content_scale_size, " mode ", root.content_scale_mode, " win ", DisplayServer.window_get_size())
	var card: FightCard = hud.fight_card
	var player: Player = main.get_node("Player")
	card.open(player)
	await get_tree().create_timer(0.5).timeout
	var b: Button = card._buttons[2]
	print("button rect ", b.get_global_rect(), " visible ", b.is_visible_in_tree(), " filter ", b.mouse_filter)
	var at := root.get_final_transform() * (b.get_global_rect().position + b.get_global_rect().size * 0.5)
	print("final transform ", root.get_final_transform(), " at ", at)
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("hovered ", root.gui_get_hovered_control(), " ", get_viewport().gui_get_hovered_control())
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("selected ", card._selected)
	get_tree().quit()

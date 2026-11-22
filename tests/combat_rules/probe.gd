extends Node
func _ready() -> void:
	seed(1)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	var t0 := Time.get_ticks_msec()
	for i in 60:
		await get_tree().physics_frame
	print("60 frames ms: ", Time.get_ticks_msec() - t0)
	var ring := get_tree().get_first_node_in_group(&"ring") as RingManager
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var hud := get_tree().get_first_node_in_group(&"combat_hud")
	print("ring ", ring, " player ", player, " hud ", hud)
	print("ring pos ", ring.global_position, " player pos ", player.global_position)
	ring.start_bout(FighterRoster.ladder()[0])
	t0 = Time.get_ticks_msec()
	var n := 0
	while ring.state != RingManager.State.FIGHT and n < 600:
		await get_tree().physics_frame
		n += 1
	print("frames to fight ", n, " ms ", Time.get_ticks_msec() - t0, " state ", ring.state)
	print("player ", player.global_position, " opp ", ring.opponent.global_position, " yaw ", player._yaw)
	print("stamina ", PlayerStats.stamina, " power ", PlayerStats.get_punch_power(), " speed ", PlayerStats.get_fight_speed(), " maxhp ", player.combat.max_health, " chin ", player.combat.chin.maximum)
	print("fps cfg ", Engine.max_fps, " ", Engine.physics_ticks_per_second, " ts ", Engine.time_scale)
	t0 = Time.get_ticks_msec()
	for i in 300:
		await get_tree().physics_frame
	print("300 frames fight ms: ", Time.get_ticks_msec() - t0)
	get_tree().quit()

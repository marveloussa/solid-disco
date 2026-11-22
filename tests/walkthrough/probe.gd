extends Node
func _ready() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().physics_frame
	var gym := main.get_node("Gym") as Node3D
	for fl in ["Floor2_FightHall"]:
		for body in main.get_node("Gym/" + fl).find_children("*", "StaticBody3D", true, false):
			var b := body as StaticBody3D
			var local := gym.to_local(b.global_position)
			if local.x > 4.0 and local.z > -26.0 and local.z < -4.0:
				var cs := b.get_child(0) as CollisionShape3D
				var size := ""
				if cs != null and cs.shape is BoxShape3D: size = str((cs.shape as BoxShape3D).size)
				print(fl, " ", b.get_parent().name, "/", b.name, " local=", local, " size=", size, " yaw=", snappedf(b.global_rotation.y, 0.01))
	get_tree().quit()

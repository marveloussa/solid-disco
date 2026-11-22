extends Node
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().physics_frame
	var gym := main.get_node("Gym") as Node3D
	var space := gym.get_world_3d().direct_space_state
	for z in [-16.5, -18.0, -20.0, -6.0, -3.0]:
		for x in [6.0, 7.0, 8.0, 9.0, 9.8, 10.5]:
			var q := PhysicsShapeQueryParameters3D.new()
			var s := SphereShape3D.new(); s.radius = 0.35
			q.shape = s
			q.collision_mask = 5
			q.transform = Transform3D(Basis.IDENTITY, gym.global_transform * Vector3(x, 5.0 + 1.0, z))
			var hits := space.intersect_shape(q, 4)
			if hits.size() > 0:
				var names := []
				for h in hits:
					var c := h.collider as Node
					names.append("%s/%s@%s" % [c.get_parent().name, c.name, c.get_parent().get("position") if c.get_parent() is Node3D else ""])
				print("2F x=", x, " z=", z, " -> ", names)
	get_tree().quit()

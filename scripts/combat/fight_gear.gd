class_name FightGear
extends RefCounted
## Stylized MMA gear for CharacterModel fighters.


## Builds a glove on a CharacterModel hand attachment (see `CharacterModel.get_hand`) and
## returns it. Pass a material of your own as `padding` to make the glove glow later.
static func glove(hand: Node3D, padding: Material, trim: Color, layers: int = 1) -> Node3D:
	var root := Node3D.new()
	root.name = "Glove"
	hand.add_child(root)
	Build.ball(root, 0.064, Vector3(0.0, -0.004, -0.004), padding, Vector3(0.95, 1.2, 1.08), 10)
	Build.cyl(root, 0.044, 0.05, Vector3(0.0, 0.085, 0.0), Build.mat(trim, 0.5), false, Vector3.ZERO, -1.0, 10)
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = layers
	return root

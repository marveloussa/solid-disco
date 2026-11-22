extends Node
func _ready() -> void:
	for a in InputMap.get_actions():
		if str(a).begins_with("ui_") and str(a) != "ui_cancel": continue
		var parts := []
		for e in InputMap.action_get_events(a):
			parts.append(e.as_text())
		print("ACTION ", a, " : ", ", ".join(parts))
	get_tree().quit()

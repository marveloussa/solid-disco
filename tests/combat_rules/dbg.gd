extends "res://tests/combat_rules/rules_base.gd"
const G := EnemyFighter.Guard
const S := EnemyFighter.State
func open_fight(d: float = 1.4) -> void:
	await fresh(4, true, null, d)
	opp.set_guard(G.NONE)
	await frames(2)
func run() -> void:
	print("level ", PlayerStats.level, " maxst ", PlayerStats.max_stamina, " xp ", PlayerStats.xp)
	await open_fight()
	PlayerStats.stamina = 15.0
	await frames(2)
	opp.start_attack([Strike.JAB])
	await until(func() -> bool: return opp.state == S.STRIKE, 240)
	await button("R")
	for i in 8:
		await frames(1)
		var land := last_landing()
		print(i, " stam ", PlayerStats.stamina, "/", PlayerStats.max_stamina, " ratio ", PlayerStats.get_stamina_ratio(), " spent ", combat.is_spent(), " health ", combat.health, " ko ", count_ev("p_knocked_out"))
		if not land.is_empty():
			var s: Strike = land["strike"]
			print("  strike outcome ", s.outcome, " ch ", s.counter_hit, " dealt ", s.dealt, " dmg ", s.damage)

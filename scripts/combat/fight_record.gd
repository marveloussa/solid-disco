class_name FightRecord
extends RefCounted
## The fighter's ring history: bouts won and lost and the current run of wins.
## Lives in `PlayerStats.fight_record`.

var wins := 0
var losses := 0
## Consecutive wins; a loss resets it.
var win_streak := 0
var best_streak := 0


func total() -> int:
	return wins + losses


func add_result(won: bool) -> void:
	if won:
		wins += 1
		win_streak += 1
		best_streak = maxi(best_streak, win_streak)
	else:
		losses += 1
		win_streak = 0


## "3 W - 1 L"
func to_text() -> String:
	return "%d W - %d L" % [wins, losses]


func to_dictionary() -> Dictionary:
	return {"wins": wins, "losses": losses, "win_streak": win_streak, "best_streak": best_streak}

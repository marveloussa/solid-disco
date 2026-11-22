class_name Strike
extends RefCounted
## One punch or kick in flight. The attacker fills in what was thrown and how hard; whoever it
## reaches writes back what happened (`outcome`, `dealt`). Used in both directions: the player's
## strikes on bags and opponents, and an opponent's strikes on the player.

enum Outcome { MISS, DODGED, BLOCKED, HIT, GUARD_BREAK, KNOCKOUT }

const JAB := &"jab"
const HOOK := &"hook"
const CROSS := &"cross"
const OVERHAND := &"overhand"
const UPPERCUT := &"uppercut"
const KICK := &"kick"
const KNEE := &"knee"

# Combos, detected by ComboTracker.
const ONE_TWO := &"one_two"
const GUARD_BREAKER := &"guard_breaker"
const KO_FINISHER := &"ko_finisher"

var kind: StringName = JAB
## The limb used: 0 left, 1 right.
var side := 0
var damage := 0.0
## Taken off a blocking opponent's guard meter.
var guard_damage := 0.0
## Speed, in m/s, the target is shoved along `direction`.
var knockback := 0.0
var stamina_drain := 0.0
var heavy := false
## Shatters a raised guard outright.
var guard_breaker := false
## Thrown inside a perfect-counter window.
var counter := false
var combo: StringName = &""
var attacker: Node3D = null
## Horizontal unit vector from the attacker to the target.
var direction := Vector3.FORWARD

var outcome := Outcome.MISS
## Damage that got through.
var dealt := 0.0
## The defender slipped it at the last moment, which opens their counter window.
var perfect := false


func is_kick() -> bool:
	return kind == KICK or kind == KNEE


## True when the blow touched the target, blocked or not.
func connected() -> bool:
	return outcome >= Outcome.BLOCKED

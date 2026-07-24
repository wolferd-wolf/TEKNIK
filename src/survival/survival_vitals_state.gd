class_name TeknikSurvivalVitalsState
extends RefCounted

const SCHEMA: int = 1
const MAX_HEALTH: float = 100.0
const MAX_HUNGER: float = 100.0
const MAX_STAMINA: float = 100.0
const HUNGER_DRAIN_PER_SECOND: float = 1.0 / 180.0
const STARVATION_DAMAGE_PER_SECOND: float = 2.0
const REGEN_PER_SECOND: float = 1.0
const REGEN_HUNGER_THRESHOLD: float = 65.0
const STAMINA_DRAIN_PER_SECOND: float = 12.0
const STAMINA_RECOVERY_PER_SECOND: float = 18.0

var health: float = MAX_HEALTH
var hunger: float = MAX_HUNGER
var stamina: float = MAX_STAMINA


func update(delta: float, moving: bool) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	hunger = clampf(hunger - HUNGER_DRAIN_PER_SECOND * safe_delta, 0.0, MAX_HUNGER)
	if moving:
		stamina = clampf(stamina - STAMINA_DRAIN_PER_SECOND * safe_delta, 0.0, MAX_STAMINA)
	else:
		stamina = clampf(stamina + STAMINA_RECOVERY_PER_SECOND * safe_delta, 0.0, MAX_STAMINA)
	if hunger <= 0.0:
		health = clampf(health - STARVATION_DAMAGE_PER_SECOND * safe_delta, 0.0, MAX_HEALTH)
	elif hunger >= REGEN_HUNGER_THRESHOLD and health < MAX_HEALTH:
		health = clampf(health + REGEN_PER_SECOND * safe_delta, 0.0, MAX_HEALTH)


func apply_damage(amount: float) -> void:
	health = clampf(health - maxf(amount, 0.0), 0.0, MAX_HEALTH)


func eat(amount: float) -> void:
	hunger = clampf(hunger + maxf(amount, 0.0), 0.0, MAX_HUNGER)


func encode() -> Dictionary:
	return {
		"schema": SCHEMA,
		"health": health,
		"hunger": hunger,
		"stamina": stamina,
	}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", 0)) != SCHEMA:
		return false
	health = clampf(float(payload.get("health", MAX_HEALTH)), 0.0, MAX_HEALTH)
	hunger = clampf(float(payload.get("hunger", MAX_HUNGER)), 0.0, MAX_HUNGER)
	stamina = clampf(float(payload.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	return true

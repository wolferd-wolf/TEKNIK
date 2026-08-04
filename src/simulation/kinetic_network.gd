extends RefCounted
class_name TeknikKineticNetwork

## Data-only bootstrap for rotational capacity, speed ratios, and stress.
## It deliberately has no scene nodes and only recalculates when requested.
var source_rpm: float = 0.0
var capacity_per_rpm: float = 0.0
var consumers: Dictionary = {}


func configure_source(rpm: float, capacity_rate: float) -> void:
	source_rpm = rpm
	capacity_per_rpm = maxf(capacity_rate, 0.0)


func add_consumer(id: StringName, speed_ratio: float, impact_per_rpm: float) -> void:
	consumers[id] = {
		"ratio": speed_ratio,
		"impact_per_rpm": maxf(impact_per_rpm, 0.0),
	}


func remove_consumer(id: StringName) -> void:
	consumers.erase(id)


func report() -> Dictionary:
	var total_stress: float = 0.0
	var rows: Array[Dictionary] = []
	var sorted_ids: Array = consumers.keys()
	sorted_ids.sort()

	for id: StringName in sorted_ids:
		var consumer: Dictionary = consumers[id]
		var rpm: float = source_rpm * float(consumer.ratio)
		var stress: float = absf(rpm) * float(consumer.impact_per_rpm)
		total_stress += stress
		rows.append({"id": id, "rpm": rpm, "stress": stress})

	var capacity: float = absf(source_rpm) * capacity_per_rpm
	return {
		"source_rpm": source_rpm,
		"capacity": capacity,
		"stress": total_stress,
		"remaining": capacity - total_stress,
		"overstressed": total_stress > capacity,
		"consumers": rows,
	}


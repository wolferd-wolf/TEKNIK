class_name TeknikNativeChunkBackend
extends RefCounted

const NATIVE_CLASS: StringName = &"TeknikNativeChunkBuilder"

var _builder: Object


func _init() -> void:
	if ClassDB.class_exists(NATIVE_CLASS):
		_builder = ClassDB.instantiate(NATIVE_CLASS)


func is_available() -> bool:
	return _builder != null and _builder.has_method("build_chunk")


func core_version() -> String:
	if not is_available() or not _builder.has_method("core_version"):
		return "unavailable"
	return str(_builder.call("core_version"))


func build_chunk(seed: int, coordinate: Vector3i, edit_snapshots: Dictionary) -> Dictionary:
	if not is_available():
		return {
			"success": false,
			"error": "TeknikNativeChunkBuilder is unavailable",
		}
	var result: Variant = _builder.call("build_chunk", seed, coordinate, edit_snapshots)
	if not result is Dictionary:
		return {
			"success": false,
			"error": "Native chunk backend returned a non-dictionary result",
		}
	return result

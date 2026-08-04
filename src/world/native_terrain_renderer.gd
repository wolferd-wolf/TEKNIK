class_name TeknikNativeTerrainRenderer
extends RefCounted

const NATIVE_CLASS: StringName = &"TeknikTerrainRenderer"

var _renderer: Object


func _init() -> void:
	if ClassDB.class_exists(NATIVE_CLASS):
		_renderer = ClassDB.instantiate(NATIVE_CLASS)


func is_available() -> bool:
	return _renderer != null and _renderer.has_method("probe_renderer")


func probe_renderer() -> Dictionary:
	if not is_available():
		return {
			"success": false,
			"error": "TeknikTerrainRenderer is unavailable",
			"rendering_device_available": false,
			"packed_renderer_supported": false,
		}
	var result: Variant = _renderer.call("probe_renderer")
	if not result is Dictionary:
		return {
			"success": false,
			"error": "Native terrain renderer returned a non-dictionary probe",
			"rendering_device_available": false,
			"packed_renderer_supported": false,
		}
	return result


func render_chunk_parity_preview(
	packed_faces: PackedInt32Array,
	legacy_vertices: PackedVector3Array,
	legacy_normals: PackedVector3Array,
	legacy_indices: PackedInt32Array,
	chunk_origin: Vector3i,
	image_size: int = 256
) -> Dictionary:
	if not is_available() or not _renderer.has_method("render_chunk_parity_preview"):
		return {
			"success": false,
			"error": "Native packed chunk preview is unavailable",
		}
	var result: Variant = _renderer.call(
		"render_chunk_parity_preview",
		packed_faces,
		legacy_vertices,
		legacy_normals,
		legacy_indices,
		chunk_origin,
		image_size
	)
	if not result is Dictionary:
		return {
			"success": false,
			"error": "Native packed chunk preview returned a non-dictionary result",
		}
	return result

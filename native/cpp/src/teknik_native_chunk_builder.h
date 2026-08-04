#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

class TeknikNativeChunkBuilder : public RefCounted {
    GDCLASS(TeknikNativeChunkBuilder, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary build_chunk(int64_t seed, Vector3i coordinate, Dictionary edit_snapshots) const;
    String core_version() const;
};

} // namespace godot

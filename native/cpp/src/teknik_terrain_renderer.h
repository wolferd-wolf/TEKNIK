#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class TeknikTerrainRenderer : public RefCounted {
    GDCLASS(TeknikTerrainRenderer, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary probe_renderer() const;
};

} // namespace godot

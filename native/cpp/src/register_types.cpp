#include "register_types.h"

#include "teknik_native_chunk_builder.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_teknik_native_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    GDREGISTER_CLASS(TeknikNativeChunkBuilder);
}

void uninitialize_teknik_native_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {

GDExtensionBool GDE_EXPORT teknik_native_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization
) {
    GDExtensionBinding::InitObject init_object(
        get_proc_address,
        library,
        initialization
    );
    init_object.register_initializer(initialize_teknik_native_module);
    init_object.register_terminator(uninitialize_teknik_native_module);
    init_object.set_minimum_library_initialization_level(
        MODULE_INITIALIZATION_LEVEL_SCENE
    );
    return init_object.init();
}

}

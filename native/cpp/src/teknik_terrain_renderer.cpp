#include "teknik_terrain_renderer.h"

#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void TeknikTerrainRenderer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("probe_renderer"), &TeknikTerrainRenderer::probe_renderer);
}

Dictionary TeknikTerrainRenderer::probe_renderer() const {
    Dictionary report;
    RenderingServer *rendering_server = RenderingServer::get_singleton();
    if (rendering_server == nullptr) {
        report["success"] = false;
        report["error"] = "RenderingServer singleton is unavailable";
        report["rendering_device_available"] = false;
        return report;
    }

    const String method = rendering_server->get_current_rendering_method();
    const String driver = rendering_server->get_current_rendering_driver_name();
    const bool rendering_device_available = rendering_server->get_rendering_device() != nullptr;

    report["success"] = true;
    report["rendering_method"] = method;
    report["rendering_driver"] = driver;
    report["rendering_device_available"] = rendering_device_available;
    report["video_adapter_name"] = rendering_server->get_video_adapter_name();
    report["video_adapter_vendor"] = rendering_server->get_video_adapter_vendor();
    report["video_adapter_api_version"] = rendering_server->get_video_adapter_api_version();
    report["packed_renderer_supported"] = (
        rendering_device_available
        && (method == "mobile" || method == "forward_plus")
        && driver != "opengl3"
        && driver != "opengl3_es"
        && driver != "opengl3_angle"
    );
    return report;
}

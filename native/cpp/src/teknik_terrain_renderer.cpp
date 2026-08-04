#include "teknik_terrain_renderer.h"

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/rd_pipeline_color_blend_state.hpp>
#include <godot_cpp/classes/rd_pipeline_color_blend_state_attachment.hpp>
#include <godot_cpp/classes/rd_pipeline_depth_stencil_state.hpp>
#include <godot_cpp/classes/rd_pipeline_multisample_state.hpp>
#include <godot_cpp/classes/rd_pipeline_rasterization_state.hpp>
#include <godot_cpp/classes/rd_shader_file.hpp>
#include <godot_cpp/classes/rd_texture_format.hpp>
#include <godot_cpp/classes/rd_texture_view.hpp>
#include <godot_cpp/classes/rd_uniform.hpp>
#include <godot_cpp/classes/rd_vertex_attribute.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

using namespace godot;

namespace {

constexpr int64_t WORDS_PER_PACKED_FACE = 2;
constexpr int64_t FLOATS_PER_LEGACY_VERTEX = 6;
constexpr int64_t PROCEDURAL_VERTICES_PER_FACE = 6;

struct RenderingDeviceResourceGuard {
    RenderingDevice *device = nullptr;
    std::vector<RID> resources;

    explicit RenderingDeviceResourceGuard(RenderingDevice *p_device) : device(p_device) {}

    RID track(const RID &resource) {
        if (resource.is_valid()) {
            resources.push_back(resource);
        }
        return resource;
    }

    ~RenderingDeviceResourceGuard() {
        if (device == nullptr) {
            return;
        }
        for (auto iterator = resources.rbegin(); iterator != resources.rend(); ++iterator) {
            if (iterator->is_valid()) {
                device->free_rid(*iterator);
            }
        }
    }
};

PackedByteArray copy_int32_bytes(const PackedInt32Array &values) {
    PackedByteArray bytes;
    const int64_t byte_count = values.size() * static_cast<int64_t>(sizeof(int32_t));
    bytes.resize(byte_count);
    if (byte_count > 0) {
        std::memcpy(bytes.ptrw(), values.ptr(), static_cast<size_t>(byte_count));
    }
    return bytes;
}

PackedByteArray build_origin_bytes(const Vector3i &origin) {
    const int32_t values[4] = {
        static_cast<int32_t>(origin.x),
        static_cast<int32_t>(origin.y),
        static_cast<int32_t>(origin.z),
        0,
    };
    PackedByteArray bytes;
    bytes.resize(static_cast<int64_t>(sizeof(values)));
    std::memcpy(bytes.ptrw(), values, sizeof(values));
    return bytes;
}

PackedByteArray build_legacy_vertex_bytes(
    const PackedVector3Array &vertices,
    const PackedVector3Array &normals
) {
    std::vector<float> interleaved;
    interleaved.resize(
        static_cast<size_t>(vertices.size() * FLOATS_PER_LEGACY_VERTEX)
    );
    for (int64_t index = 0; index < vertices.size(); ++index) {
        const Vector3 vertex = vertices[index];
        const Vector3 normal = normals[index];
        const size_t base = static_cast<size_t>(index * FLOATS_PER_LEGACY_VERTEX);
        interleaved[base + 0] = static_cast<float>(vertex.x);
        interleaved[base + 1] = static_cast<float>(vertex.y);
        interleaved[base + 2] = static_cast<float>(vertex.z);
        interleaved[base + 3] = static_cast<float>(normal.x);
        interleaved[base + 4] = static_cast<float>(normal.y);
        interleaved[base + 5] = static_cast<float>(normal.z);
    }

    PackedByteArray bytes;
    const int64_t byte_count = static_cast<int64_t>(interleaved.size() * sizeof(float));
    bytes.resize(byte_count);
    if (byte_count > 0) {
        std::memcpy(bytes.ptrw(), interleaved.data(), static_cast<size_t>(byte_count));
    }
    return bytes;
}

Ref<RDShaderFile> load_shader_file(const String &path) {
    return ResourceLoader::get_singleton()->load(path);
}

RID create_color_target(
    RenderingDevice *device,
    RenderingDeviceResourceGuard &guard,
    int64_t size
) {
    Ref<RDTextureFormat> format;
    format.instantiate();
    format->set_width(size);
    format->set_height(size);
    format->set_format(RenderingDevice::DATA_FORMAT_R8G8B8A8_UNORM);
    format->set_usage_bits(
        RenderingDevice::TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
        | RenderingDevice::TEXTURE_USAGE_CAN_COPY_FROM_BIT
    );

    Ref<RDTextureView> view;
    view.instantiate();
    TypedArray<PackedByteArray> initial_data;
    return guard.track(device->texture_create(format, view, initial_data));
}

RID create_framebuffer(
    RenderingDevice *device,
    RenderingDeviceResourceGuard &guard,
    const RID &color_target
) {
    TypedArray<RID> attachments;
    attachments.push_back(color_target);
    return guard.track(device->framebuffer_create(attachments));
}

Ref<RDPipelineColorBlendState> create_color_blend_state() {
    Ref<RDPipelineColorBlendStateAttachment> attachment;
    attachment.instantiate();
    attachment->set_enable_blend(false);

    TypedArray<RDPipelineColorBlendStateAttachment> attachments;
    attachments.push_back(attachment);

    Ref<RDPipelineColorBlendState> state;
    state.instantiate();
    state->set_attachments(attachments);
    return state;
}

RID create_render_pipeline(
    RenderingDevice *device,
    RenderingDeviceResourceGuard &guard,
    const RID &shader,
    int64_t framebuffer_format,
    int64_t vertex_format
) {
    Ref<RDPipelineRasterizationState> rasterization;
    rasterization.instantiate();
    rasterization->set_cull_mode(RenderingDevice::POLYGON_CULL_DISABLED);
    rasterization->set_front_face(RenderingDevice::POLYGON_FRONT_FACE_COUNTER_CLOCKWISE);

    Ref<RDPipelineMultisampleState> multisample;
    multisample.instantiate();

    Ref<RDPipelineDepthStencilState> depth_stencil;
    depth_stencil.instantiate();
    depth_stencil->set_enable_depth_test(false);
    depth_stencil->set_enable_depth_write(false);

    const Ref<RDPipelineColorBlendState> color_blend = create_color_blend_state();
    return guard.track(device->render_pipeline_create(
        shader,
        framebuffer_format,
        vertex_format,
        RenderingDevice::RENDER_PRIMITIVE_TRIANGLES,
        rasterization,
        multisample,
        depth_stencil,
        color_blend
    ));
}

RID create_storage_uniform_set(
    RenderingDevice *device,
    RenderingDeviceResourceGuard &guard,
    const RID &shader,
    const std::vector<std::pair<int64_t, RID>> &bindings
) {
    TypedArray<RDUniform> uniforms;
    for (const auto &binding : bindings) {
        Ref<RDUniform> uniform;
        uniform.instantiate();
        uniform->set_uniform_type(RenderingDevice::UNIFORM_TYPE_STORAGE_BUFFER);
        uniform->set_binding(binding.first);
        uniform->add_id(binding.second);
        uniforms.push_back(uniform);
    }
    return guard.track(device->uniform_set_create(uniforms, shader, 0));
}

void draw_packed_faces(
    RenderingDevice *device,
    const RID &framebuffer,
    const RID &pipeline,
    const RID &uniform_set,
    const RID &vertex_array,
    int64_t face_count
) {
    PackedColorArray clear_colors;
    clear_colors.push_back(Color(0.0, 0.0, 0.0, 0.0));
    const int64_t draw_list = device->draw_list_begin(
        framebuffer,
        RenderingDevice::DRAW_CLEAR_COLOR_ALL,
        clear_colors
    );
    device->draw_list_bind_render_pipeline(draw_list, pipeline);
    device->draw_list_bind_uniform_set(draw_list, uniform_set, 0);
    device->draw_list_bind_vertex_array(draw_list, vertex_array);
    device->draw_list_draw(
        draw_list,
        false,
        face_count,
        PROCEDURAL_VERTICES_PER_FACE
    );
    device->draw_list_end();
}

void draw_legacy_mesh(
    RenderingDevice *device,
    const RID &framebuffer,
    const RID &pipeline,
    const RID &uniform_set,
    const RID &vertex_array,
    const RID &index_array
) {
    PackedColorArray clear_colors;
    clear_colors.push_back(Color(0.0, 0.0, 0.0, 0.0));
    const int64_t draw_list = device->draw_list_begin(
        framebuffer,
        RenderingDevice::DRAW_CLEAR_COLOR_ALL,
        clear_colors
    );
    device->draw_list_bind_render_pipeline(draw_list, pipeline);
    device->draw_list_bind_uniform_set(draw_list, uniform_set, 0);
    device->draw_list_bind_vertex_array(draw_list, vertex_array);
    device->draw_list_bind_index_array(draw_list, index_array);
    device->draw_list_draw(draw_list, true, 1);
    device->draw_list_end();
}

Dictionary compare_rendered_images(
    const PackedByteArray &packed_pixels,
    const PackedByteArray &legacy_pixels,
    int64_t image_size
) {
    Dictionary comparison;
    const int64_t expected_bytes = image_size * image_size * 4;
    comparison["expected_image_bytes"] = expected_bytes;
    comparison["packed_image_bytes"] = packed_pixels.size();
    comparison["legacy_image_bytes"] = legacy_pixels.size();
    if (packed_pixels.size() != expected_bytes || legacy_pixels.size() != expected_bytes) {
        comparison["valid_image_sizes"] = false;
        comparison["exact_pixel_match"] = false;
        comparison["mismatch_pixels"] = image_size * image_size;
        comparison["covered_pixels"] = 0;
        return comparison;
    }

    int64_t mismatch_pixels = 0;
    int64_t covered_pixels = 0;
    int64_t maximum_channel_error = 0;
    for (int64_t pixel = 0; pixel < image_size * image_size; ++pixel) {
        const int64_t base = pixel * 4;
        bool pixel_differs = false;
        for (int64_t channel = 0; channel < 4; ++channel) {
            const int64_t packed_value = packed_pixels[base + channel];
            const int64_t legacy_value = legacy_pixels[base + channel];
            const int64_t error = std::abs(packed_value - legacy_value);
            maximum_channel_error = std::max(maximum_channel_error, error);
            pixel_differs = pixel_differs || error != 0;
        }
        if (pixel_differs) {
            mismatch_pixels += 1;
        }
        if (packed_pixels[base + 3] != 0) {
            covered_pixels += 1;
        }
    }

    comparison["valid_image_sizes"] = true;
    comparison["exact_pixel_match"] = mismatch_pixels == 0;
    comparison["mismatch_pixels"] = mismatch_pixels;
    comparison["covered_pixels"] = covered_pixels;
    comparison["maximum_channel_error"] = maximum_channel_error;
    return comparison;
}

} // namespace

void TeknikTerrainRenderer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("probe_renderer"), &TeknikTerrainRenderer::probe_renderer);
    ClassDB::bind_method(
        D_METHOD(
            "render_chunk_parity_preview",
            "packed_faces",
            "legacy_vertices",
            "legacy_normals",
            "legacy_indices",
            "chunk_origin",
            "image_size"
        ),
        &TeknikTerrainRenderer::render_chunk_parity_preview,
        DEFVAL(256)
    );
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

Dictionary TeknikTerrainRenderer::render_chunk_parity_preview(
    PackedInt32Array packed_faces,
    PackedVector3Array legacy_vertices,
    PackedVector3Array legacy_normals,
    PackedInt32Array legacy_indices,
    Vector3i chunk_origin,
    int64_t image_size
) const {
    Dictionary report = probe_renderer();
    if (!static_cast<bool>(report.get("success", false))) {
        return report;
    }
    if (!static_cast<bool>(report.get("packed_renderer_supported", false))) {
        report["success"] = false;
        report["error"] = "The active renderer does not expose a supported RenderingDevice path";
        return report;
    }
    if (packed_faces.size() == 0 || packed_faces.size() % WORDS_PER_PACKED_FACE != 0) {
        report["success"] = false;
        report["error"] = "Packed face words must contain one non-empty two-word record per face";
        return report;
    }
    if (legacy_vertices.size() == 0 || legacy_vertices.size() != legacy_normals.size()) {
        report["success"] = false;
        report["error"] = "Legacy positions and normals must be non-empty and have matching counts";
        return report;
    }
    if (legacy_indices.size() == 0 || legacy_indices.size() % 3 != 0) {
        report["success"] = false;
        report["error"] = "Legacy indices must contain complete triangles";
        return report;
    }

    image_size = std::clamp<int64_t>(image_size, 64, 1024);
    RenderingServer *rendering_server = RenderingServer::get_singleton();
    RenderingDevice *device = rendering_server->get_rendering_device();
    if (device == nullptr) {
        report["success"] = false;
        report["error"] = "Global RenderingDevice became unavailable";
        return report;
    }

    RenderingDeviceResourceGuard guard(device);
    const Ref<RDShaderFile> packed_shader_file = load_shader_file(
        "res://native/shaders/packed_chunk_preview.glsl"
    );
    const Ref<RDShaderFile> legacy_shader_file = load_shader_file(
        "res://native/shaders/legacy_chunk_preview.glsl"
    );
    if (packed_shader_file.is_null() || legacy_shader_file.is_null()) {
        report["success"] = false;
        report["error"] = "Packed or legacy RenderingDevice shader resource failed to load";
        return report;
    }
    if (!packed_shader_file->get_base_error().is_empty()
        || !legacy_shader_file->get_base_error().is_empty()) {
        report["success"] = false;
        report["error"] = String("RenderingDevice shader import error: ")
            + packed_shader_file->get_base_error()
            + " "
            + legacy_shader_file->get_base_error();
        return report;
    }

    const RID packed_shader = guard.track(device->shader_create_from_spirv(
        packed_shader_file->get_spirv(),
        "TEKNIK packed chunk preview"
    ));
    const RID legacy_shader = guard.track(device->shader_create_from_spirv(
        legacy_shader_file->get_spirv(),
        "TEKNIK legacy chunk preview"
    ));
    if (!packed_shader.is_valid() || !legacy_shader.is_valid()) {
        report["success"] = false;
        report["error"] = "RenderingDevice failed to create packed or legacy shader";
        return report;
    }

    const RID packed_target = create_color_target(device, guard, image_size);
    const RID legacy_target = create_color_target(device, guard, image_size);
    const RID packed_framebuffer = create_framebuffer(device, guard, packed_target);
    const RID legacy_framebuffer = create_framebuffer(device, guard, legacy_target);
    if (!packed_target.is_valid()
        || !legacy_target.is_valid()
        || !device->framebuffer_is_valid(packed_framebuffer)
        || !device->framebuffer_is_valid(legacy_framebuffer)) {
        report["success"] = false;
        report["error"] = "RenderingDevice failed to create preview targets or framebuffers";
        return report;
    }

    TypedArray<RDVertexAttribute> empty_attributes;
    const int64_t packed_vertex_format = device->vertex_format_create(empty_attributes);

    Ref<RDVertexAttribute> position_attribute;
    position_attribute.instantiate();
    position_attribute->set_location(0);
    position_attribute->set_binding(0);
    position_attribute->set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);
    position_attribute->set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));
    position_attribute->set_offset(0);

    Ref<RDVertexAttribute> normal_attribute;
    normal_attribute.instantiate();
    normal_attribute->set_location(1);
    normal_attribute->set_binding(0);
    normal_attribute->set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);
    normal_attribute->set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));
    normal_attribute->set_offset(3 * sizeof(float));

    TypedArray<RDVertexAttribute> legacy_attributes;
    legacy_attributes.push_back(position_attribute);
    legacy_attributes.push_back(normal_attribute);
    const int64_t legacy_vertex_format = device->vertex_format_create(legacy_attributes);

    const int64_t framebuffer_format = device->framebuffer_get_format(packed_framebuffer);
    const RID packed_pipeline = create_render_pipeline(
        device,
        guard,
        packed_shader,
        framebuffer_format,
        packed_vertex_format
    );
    const RID legacy_pipeline = create_render_pipeline(
        device,
        guard,
        legacy_shader,
        framebuffer_format,
        legacy_vertex_format
    );
    if (!device->render_pipeline_is_valid(packed_pipeline)
        || !device->render_pipeline_is_valid(legacy_pipeline)) {
        report["success"] = false;
        report["error"] = "RenderingDevice failed to create packed or legacy render pipeline";
        return report;
    }

    const PackedByteArray packed_face_bytes = copy_int32_bytes(packed_faces);
    const PackedByteArray origin_bytes = build_origin_bytes(chunk_origin);
    const PackedByteArray legacy_vertex_bytes = build_legacy_vertex_bytes(
        legacy_vertices,
        legacy_normals
    );
    const PackedByteArray legacy_index_bytes = copy_int32_bytes(legacy_indices);

    const RID packed_face_buffer = guard.track(device->storage_buffer_create(
        packed_face_bytes.size(),
        packed_face_bytes
    ));
    const RID origin_buffer = guard.track(device->storage_buffer_create(
        origin_bytes.size(),
        origin_bytes
    ));
    const RID legacy_vertex_buffer = guard.track(device->vertex_buffer_create(
        legacy_vertex_bytes.size(),
        legacy_vertex_bytes
    ));
    const RID legacy_index_buffer = guard.track(device->index_buffer_create(
        legacy_indices.size(),
        RenderingDevice::INDEX_BUFFER_FORMAT_UINT32,
        legacy_index_bytes
    ));
    if (!packed_face_buffer.is_valid()
        || !origin_buffer.is_valid()
        || !legacy_vertex_buffer.is_valid()
        || !legacy_index_buffer.is_valid()) {
        report["success"] = false;
        report["error"] = "RenderingDevice failed to create packed or legacy GPU buffers";
        return report;
    }

    const RID packed_uniform_set = create_storage_uniform_set(
        device,
        guard,
        packed_shader,
        {{0, packed_face_buffer}, {1, origin_buffer}}
    );
    const RID legacy_uniform_set = create_storage_uniform_set(
        device,
        guard,
        legacy_shader,
        {{0, origin_buffer}}
    );

    TypedArray<RID> vertex_buffers;
    vertex_buffers.push_back(legacy_vertex_buffer);
    const RID legacy_vertex_array = guard.track(device->vertex_array_create(
        legacy_vertices.size(),
        legacy_vertex_format,
        vertex_buffers
    ));
    const RID legacy_index_array = guard.track(device->index_array_create(
        legacy_index_buffer,
        0,
        legacy_indices.size()
    ));
    TypedArray<RID> packed_vertex_buffers;
    const RID packed_vertex_array = guard.track(device->vertex_array_create(
        PROCEDURAL_VERTICES_PER_FACE,
        packed_vertex_format,
        packed_vertex_buffers
    ));
    if (!device->uniform_set_is_valid(packed_uniform_set)
        || !device->uniform_set_is_valid(legacy_uniform_set)
        || !packed_vertex_array.is_valid()
        || !legacy_vertex_array.is_valid()
        || !legacy_index_array.is_valid()) {
        report["success"] = false;
        report["error"] = "RenderingDevice failed to create uniform, vertex or index bindings";
        return report;
    }

    const int64_t face_count = packed_faces.size() / WORDS_PER_PACKED_FACE;
    draw_packed_faces(
        device,
        packed_framebuffer,
        packed_pipeline,
        packed_uniform_set,
        packed_vertex_array,
        face_count
    );
    draw_legacy_mesh(
        device,
        legacy_framebuffer,
        legacy_pipeline,
        legacy_uniform_set,
        legacy_vertex_array,
        legacy_index_array
    );

    const PackedByteArray packed_pixels = device->texture_get_data(packed_target, 0);
    const PackedByteArray legacy_pixels = device->texture_get_data(legacy_target, 0);
    const Dictionary comparison = compare_rendered_images(
        packed_pixels,
        legacy_pixels,
        image_size
    );

    report.merge(comparison, true);
    const bool valid_image_sizes = static_cast<bool>(comparison.get("valid_image_sizes", false));
    const bool exact_pixel_match = static_cast<bool>(comparison.get("exact_pixel_match", false));
    const int64_t covered_pixels = static_cast<int64_t>(comparison.get("covered_pixels", 0));
    report["success"] = valid_image_sizes && exact_pixel_match && covered_pixels > 0;
    report["image_size"] = image_size;
    report["face_count"] = face_count;
    report["procedural_vertex_count"] = face_count * PROCEDURAL_VERTICES_PER_FACE;
    report["legacy_vertex_count"] = legacy_vertices.size();
    report["legacy_index_count"] = legacy_indices.size();
    report["packed_upload_bytes"] = packed_face_bytes.size() + origin_bytes.size();
    report["legacy_upload_bytes"] = (
        legacy_vertex_bytes.size() + legacy_index_bytes.size() + origin_bytes.size()
    );
    report["packed_image"] = Image::create_from_data(
        image_size,
        image_size,
        false,
        Image::FORMAT_RGBA8,
        packed_pixels
    );
    report["legacy_image"] = Image::create_from_data(
        image_size,
        image_size,
        false,
        Image::FORMAT_RGBA8,
        legacy_pixels
    );
    if (!exact_pixel_match) {
        report["error"] = "Packed and conventional Vulkan preview pixels differ";
    } else if (covered_pixels <= 0) {
        report["error"] = "Packed Vulkan preview produced no covered pixels";
    }
    return report;
}

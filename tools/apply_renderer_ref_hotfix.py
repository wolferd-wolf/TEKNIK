from pathlib import Path

path = Path("native/cpp/src/teknik_terrain_renderer.cpp")
source = path.read_text(encoding="utf-8")

replacements = [
    (
        """Ref<RDPipelineColorBlendState> create_color_blend_state() {\n    RDPipelineColorBlendStateAttachment attachment;\n    attachment.set_enable_blend(false);\n\n    TypedArray<RDPipelineColorBlendStateAttachment> attachments;\n    attachments.push_back(&attachment);\n\n    Ref<RDPipelineColorBlendState> state;\n""",
        """Ref<RDPipelineColorBlendState> create_color_blend_state() {\n    Ref<RDPipelineColorBlendStateAttachment> attachment;\n    attachment.instantiate();\n    attachment->set_enable_blend(false);\n\n    TypedArray<RDPipelineColorBlendStateAttachment> attachments;\n    attachments.push_back(attachment);\n\n    Ref<RDPipelineColorBlendState> state;\n""",
    ),
    (
        """    RDVertexAttribute position_attribute;\n    position_attribute.set_location(0);\n    position_attribute.set_binding(0);\n    position_attribute.set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);\n    position_attribute.set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));\n    position_attribute.set_offset(0);\n\n    RDVertexAttribute normal_attribute;\n    normal_attribute.set_location(1);\n    normal_attribute.set_binding(0);\n    normal_attribute.set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);\n    normal_attribute.set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));\n    normal_attribute.set_offset(3 * sizeof(float));\n\n    TypedArray<RDVertexAttribute> legacy_attributes;\n    legacy_attributes.push_back(&position_attribute);\n    legacy_attributes.push_back(&normal_attribute);\n""",
        """    Ref<RDVertexAttribute> position_attribute;\n    position_attribute.instantiate();\n    position_attribute->set_location(0);\n    position_attribute->set_binding(0);\n    position_attribute->set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);\n    position_attribute->set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));\n    position_attribute->set_offset(0);\n\n    Ref<RDVertexAttribute> normal_attribute;\n    normal_attribute.instantiate();\n    normal_attribute->set_location(1);\n    normal_attribute->set_binding(0);\n    normal_attribute->set_format(RenderingDevice::DATA_FORMAT_R32G32B32_SFLOAT);\n    normal_attribute->set_stride(FLOATS_PER_LEGACY_VERTEX * sizeof(float));\n    normal_attribute->set_offset(3 * sizeof(float));\n\n    TypedArray<RDVertexAttribute> legacy_attributes;\n    legacy_attributes.push_back(position_attribute);\n    legacy_attributes.push_back(normal_attribute);\n""",
    ),
    (
        """    report.merge(comparison, true);\n    report[\"success\"] = static_cast<bool>(comparison.get(\"valid_image_sizes\", false));\n    report[\"image_size\"] = image_size;\n""",
        """    report.merge(comparison, true);\n    const bool valid_image_sizes = static_cast<bool>(comparison.get(\"valid_image_sizes\", false));\n    const bool exact_pixel_match = static_cast<bool>(comparison.get(\"exact_pixel_match\", false));\n    const int64_t covered_pixels = static_cast<int64_t>(comparison.get(\"covered_pixels\", 0));\n    report[\"success\"] = valid_image_sizes && exact_pixel_match && covered_pixels > 0;\n    report[\"image_size\"] = image_size;\n""",
    ),
    (
        """    if (!static_cast<bool>(comparison.get(\"exact_pixel_match\", false))) {\n        report[\"error\"] = \"Packed and conventional Vulkan preview pixels differ\";\n    } else if (static_cast<int64_t>(comparison.get(\"covered_pixels\", 0)) <= 0) {\n        report[\"success\"] = false;\n        report[\"error\"] = \"Packed Vulkan preview produced no covered pixels\";\n    }\n""",
        """    if (!exact_pixel_match) {\n        report[\"error\"] = \"Packed and conventional Vulkan preview pixels differ\";\n    } else if (covered_pixels <= 0) {\n        report[\"error\"] = \"Packed Vulkan preview produced no covered pixels\";\n    }\n""",
    ),
]

for old, new in replacements:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one replacement target, found {count}")
    source = source.replace(old, new)

path.write_text(source, encoding="utf-8")
print(f"Patched {path} ({len(source.splitlines())} lines)")

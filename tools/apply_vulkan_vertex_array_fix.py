from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one target, found {count}")
    return source.replace(old, new)


renderer_path = Path("native/cpp/src/teknik_terrain_renderer.cpp")
renderer = renderer_path.read_text(encoding="utf-8")
renderer = replace_once(
    renderer,
    """    const RID &pipeline,\n    const RID &uniform_set,\n    int64_t face_count\n) {\n""",
    """    const RID &pipeline,\n    const RID &uniform_set,\n    const RID &vertex_array,\n    int64_t face_count\n) {\n""",
    "packed draw signature",
)
renderer = replace_once(
    renderer,
    """    device->draw_list_bind_render_pipeline(draw_list, pipeline);\n    device->draw_list_bind_uniform_set(draw_list, uniform_set, 0);\n    device->draw_list_draw(\n""",
    """    device->draw_list_bind_render_pipeline(draw_list, pipeline);\n    device->draw_list_bind_uniform_set(draw_list, uniform_set, 0);\n    device->draw_list_bind_vertex_array(draw_list, vertex_array);\n    device->draw_list_draw(\n""",
    "packed vertex-array binding",
)
renderer = replace_once(
    renderer,
    """    const RID legacy_index_array = guard.track(device->index_array_create(\n        legacy_index_buffer,\n        0,\n        legacy_indices.size()\n    ));\n    if (!device->uniform_set_is_valid(packed_uniform_set)\n""",
    """    const RID legacy_index_array = guard.track(device->index_array_create(\n        legacy_index_buffer,\n        0,\n        legacy_indices.size()\n    ));\n    TypedArray<RID> packed_vertex_buffers;\n    const RID packed_vertex_array = guard.track(device->vertex_array_create(\n        PROCEDURAL_VERTICES_PER_FACE,\n        packed_vertex_format,\n        packed_vertex_buffers\n    ));\n    if (!device->uniform_set_is_valid(packed_uniform_set)\n""",
    "packed vertex-array creation",
)
renderer = replace_once(
    renderer,
    """        || !device->uniform_set_is_valid(legacy_uniform_set)\n        || !legacy_vertex_array.is_valid()\n""",
    """        || !device->uniform_set_is_valid(legacy_uniform_set)\n        || !packed_vertex_array.is_valid()\n        || !legacy_vertex_array.is_valid()\n""",
    "packed vertex-array validation",
)
renderer = replace_once(
    renderer,
    """        packed_pipeline,\n        packed_uniform_set,\n        face_count\n""",
    """        packed_pipeline,\n        packed_uniform_set,\n        packed_vertex_array,\n        face_count\n""",
    "packed draw call",
)
renderer = replace_once(
    renderer,
    """\n    device->submit();\n    device->sync();\n    const PackedByteArray packed_pixels = device->texture_get_data(packed_target, 0);\n""",
    """\n    const PackedByteArray packed_pixels = device->texture_get_data(packed_target, 0);\n""",
    "global device submission removal",
)
renderer_path.write_text(renderer, encoding="utf-8")

workflow_path = Path(".github/workflows/android-emulator-diagnostic.yml")
workflow = workflow_path.read_text(encoding="utf-8")
workflow = replace_once(
    workflow,
    """      - name: Initialize diagnostic evidence\n        run: |\n          mkdir -p emulator-artifacts\n""",
    """      - name: Locate downloaded emulator APK\n        run: |\n          mkdir -p emulator-artifacts\n          find \"$GITHUB_WORKSPACE/qa\" -maxdepth 3 -type f -printf '%p %s bytes\\n' | tee emulator-artifacts/downloaded-files.txt\n          APK=\"$(find \"$GITHUB_WORKSPACE/qa\" -type f -name 'TEKNIK-emulator-debug.apk' -print -quit)\"\n          test -n \"$APK\"\n          test -s \"$APK\"\n          printf 'TEKNIK_EMULATOR_APK=%s\\n' \"$APK\" >> \"$GITHUB_ENV\"\n\n      - name: Initialize diagnostic evidence\n        run: |\n          mkdir -p emulator-artifacts\n""",
    "emulator APK locate step",
)
workflow = replace_once(
    workflow,
    """            APK=\"$(find qa -name TEKNIK-emulator-debug.apk -print -quit)\"\n            printf 'apk=%s\\n' \"$APK\" >> emulator-artifacts/verdict.txt\n""",
    """            APK=\"$TEKNIK_EMULATOR_APK\"\n            printf 'apk=%s\\n' \"$APK\" >> emulator-artifacts/verdict.txt\n            if [ -z \"$APK\" ] || [ ! -s \"$APK\" ]; then\n              printf 'verdict=apk_missing\\n' | tee -a emulator-artifacts/verdict.txt\n              exit 1\n            fi\n""",
    "emulator absolute APK handoff",
)
workflow_path.write_text(workflow, encoding="utf-8")

print(f"Patched {renderer_path} and {workflow_path}")

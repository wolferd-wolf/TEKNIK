class_name TeknikTerrainTextureMaterial
extends RefCounted

const TERRAIN_SHADER: Shader = preload("res://assets/textures/terrain_texture_array.gdshader")
const LAYER_SIZE: int = 128
const LAYER_PATHS: Array[String] = [
    "res://assets/textures/terrain_layers/grass_top.png",
    "res://assets/textures/terrain_layers/grass_side.png",
    "res://assets/textures/terrain_layers/dirt.png",
    "res://assets/textures/terrain_layers/stone.png",
    "res://assets/textures/terrain_layers/sand.png",
    "res://assets/textures/terrain_layers/zinc_ore.png",
    "res://assets/textures/terrain_layers/copper_ore.png",
    "res://assets/textures/terrain_layers/iron_ore.png",
    "res://assets/textures/terrain_layers/gold_ore.png",
]

const GRASS_TOP_PNG := "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAMFBMVEVrdB1pch1ocR1mcBxmbxxlbxxkbhxjbhxkbRxjbRxibBxhbBxhaxxgahxfahxeaBt3uyn0AAACK0lEQVR42gEgAt/9A7LhaxvOcUNJ4lWe2fHUW+UCoBsNJ7rOqczR/dCT//3D+wCopRVV76MArDA23DMizCOaBE0RjJoLFiSXKFSYN8fO/zMCCQ3eHuMRffH++XXLhugVnATOwnvd/WvK9BSrNpfjINz6AjRWEfCP8bzTTljJEj/IkPQCUttAXKlcVzCi8QbcwrHv9AO04PUA2WX3NJT6d1iU5ug6A2727ZMrQu/l4hgs/cT70AcDJb022jjcRv8T+fcLdopLiwIyudkXLvPkal3MLXvkfNdzApi9/BAF1tMAehe9/bDwzgAEcvrzHY1wB+rsG73w+LxnPAIwEfq97G3w8TnjHIHg6wn1A1tIIzO+M/nFkmPsBu4A200C8t0SXyDanQi0/DCd7owWgQM/A/uu0SDM0chNXFNJmTzwBOYB9cB/C2HqQbAQsU/vVDQA/+ZrokFf9a/5FDEpETjMyQD/eq4QD/6hztpgOcEEOAj9As0TSUIJ6JQvmPDKol76+0cC/UCbWF1w3biw9RYQsyOmHgS8FpPB67/uWxYeJS8OGKjEAxZRcIWA5xHw7ATwIt7/b2ECpwuWqAACUAnkkrT3buG7+wL/363tK/8kMk347uUwZSuNAxGIDOUl9Fzy8r4IjXsOCToE2whA22P43w3enqCdm0a2tAT+9jA1OuBtOBA5+Xb3RSAGBPkyJBQnAvzJZyhKp3nZXeEB+v617WPCCr8Ad/6iOYQ/+rdYE3tMb3MEAAAAAElFTkSuQmCC"
const GRASS_SIDE_PNG := "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAMFBMVEV3gCFyfCBjbRxQWBZhQRtePxpdPhpcPRlGQhVaPBlYOxhYOhhXOhhSORdSNxdEMBTYSCO4AAAB+UlEQVR42i3HTUgUYRgH8P/zzoyzhDbPaJGB4bqRCBWkRp4iK0HsYEswQVGsFBh08hAUdZFAKhI81SEMuhWs2MctamlLEEJXCTUwa1tlL9buvjNLfuHuPh3q8oMfwMRU6wJMLjFIwWdyCkKu74gQGABcl8kFQCAXymVAiJmYhRhsgqABVyNwAACm60ecZQfLTRAiloDaCAAkYAA+A+rfiQGAAaioABZFfQ8ePEQt06JLW/YW2PZuDtiwo5D7IiL/FRGIiBRERLSuFEREaV9raA2I9EHntCqNYCo+Xon9iqd7pxOSUeahxYcTNT/CS/HBsFO3C2am8za282PFjf3XSqnQ9BtVmrWGdr4Mzn2p2xpNj49FzMb5R6v+g3K6Mr2kvYuLC0bri57hTMpeqNF7g9Cet7ZqqrlOtZJaa+0L2k8lty2z+XTZCLV8wPvHfyS9rzJAq5efxYC2wk8OOg6ulQ8o616VJ2IP1vmSb59JZdR2+VUCKGSNI97v5BVhwxtubjjcsrn+PRPiuQ75pgyeahdp+HTrwkw2PDURRv5zV89kV/eT0dyN7smuRMGk3dw0328cH75zdb2q3oERWTna/zV0Mvf6mHSmYkPVqncssrn5bsQ6kd2YpaesKVesHthBa2fDc2f6zkeToNzH+rvPK8Wc0bhSUohk/gJK7+XgU5EfFAAAAABJRU5ErkJggg=="
const DIRT_PNG := "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAMFBMVEVtTDBhRS5gQSpcQClbPihZPShYPCdWPCdVOiZTOSVSOCVQNyVPNiRONSNLNCJHMCCacn0DAAACK0lEQVR42gEgAt/9AAIQABABAAAAEAAAABAAAAACHzQBhv+DEAADxAACUhADIASD2EVo/mrf0Rk5ZiRwwI71Af/+sCsW+/T/A8gFMg/wEu4AqeAdnjLQL/3XIn/zEO5BOAA+uHn+M86MEDq6zobYftd7AAjnIn200ygohqk17zAe9+gCEE1XKcVQX6zaWBcQAADs8AJW3UZSquHE/vEULyBTa9oPAsCUGIf9B8bXSbYe7xTpAgAAF//hH1JeArzCE1td0RnWPQIk6qdeAsvtZwIfGrcLe8dHAoPnten0HPDuF3R/EKcfjA0DyqdaOqt/vvggSwT96fXRZQC5qSOt5U12yTNS3Fkzd+/iAF7/wyv+hup3g1gkqNd3idoCvmgGKxRU8atZHt7tIw3wvQBaEkSXAP5NQGMlntnai8ADA5/Z6/e73+o4+t2FDEI3TiIDIv2T56HxKWGrJMbfz5abDQIQAkT5YQO1WnHawfXZUOywAPsiRaycAI8T9hK7URJ8mesCtNoOlngRm3fnMiMhEfo1zgISg83aryMfJXTjtzQPnydOAxAG8yxpzxUOqwDVHMcPWfoC213zGCZEVNYD7Oaq9QlOXwPCQhw6uSaG9PMLRBlyQvX5AmRZXJBeqE1Wpw9B3CJUTuwC+q00/uH/T7FLMkkKBBYfwANR1x46F+gFu+V18fHMtK2pA/RKsnYz/sFLewhnLrfx2egC/aCBnFNYJdsInSIGzTwgn4S085jGUConAAAAAElFTkSuQmCC"
const STONE_PNG := "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAMFBMVEV0cWxyb2pybmpxbmlwbmlxbWhwbWhvbWhwbGhvbGdvbGZubGdva2dua2ZuamZtaWUKNUp8AAACK0lEQVR42gEgAt/9AVZGOfkLv8SSdydy3hPZzakDqqH+5XJoXQe5DQYa+5dUBQIXKEr7L5Xw/MBDBp1pJxhQBLNLIPUAERp1qRAKDMUAqMEE8NGHhhPwcP0QEHPRO68JAATUnQBGQK0z8f2R/87NBfaJBB4Q86X/4P0aJBVQH+AK8AYE3xED9QQzz1swBtEZYNkJgQHtNOL+MVtL9pXzC97/W8WBAxMNBE6z2/DG0j7h9Vrws30Axp/IEAACOe/+YzMP+GaWzwQDLvbwAg5mrkHu3v3hAMD4AtYs1VEQfU28/sDwMvTr4gACKY/90noS3QO1RVA6MDG+CwTAAWB9zWzEQDkMPxkc5srSAkCf2us0A9/Mkz/y0PfOIyMCvpqg7PiRIBqYPbvMAVDxQADMEBb/mZgAFjMG9gASac3tBPTzEJ1lMgDsbSWgIPYd0QED8ech/xOGAQAVlaASMMRzlwLf8gD9SxEUEw7g1K7uya6SApgN42USAj4oIWbxM8Ca4PADOHIZ4eAO3tiYBA/kHisDFQQwwXAIMTW8ggv5sbkK8spfBE2nCABSABkER/zG6cowLesDDMToACjfDekOUEF2pB6LXwBjEQAB3hE2yPyG8TFmOdkZABEAMRWMAVY5+anlACEMYAYEAgDXJBEP3zTlNAIRNy18OgPNxiNnMBUHmHr8GyZH9TltAsNcqsy51p4xfeu8yRehFP8EMAX/1Fuxi+IB4HDzxqD1D2rX78CBR2i9AAAAAElFTkSuQmCC"
const SAND_PNG := "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgBAMAAACBVGfHAAAAMFBMVEXRs2/Qsm3PsWzOsW3OsGzNsGzNr2rMrmrKrWjJrGjJq2bIqmbHqmXGqWTFqGPEpmG1KsT8AAAB40lEQVR42gXBzU4TURQA4HPuxRZM2zl38AebUGdGg4QGy1CMcYOUQKJh5catv0/lI/gSiAuNC4jowjQxTKdNaKvp3DPTApUw9/p90FKvEQDgPVAQCuXL4KJLYMrTRlfDuOBksIQ75L4NXCASgQKUoTleGMTF6ebZACzjK0nF/nmZQVuEi+lOxAJcusI3dunujEX38F1HLnfr3vDPSvnHrVZ6Op3kYrfGwmq9Dx1Mgw325fzwKncSoGezsXN1Y2hmKtBM421ePMjP652kFGNh05FWG9CT0jh/RB9ExQ3I/zRpxMZ1d0YfX8o9/jUbqKftMK33q16aydUHky8rTltxs+8WiuNl+bxXf4gRVI94EH7FYW9mQ5Y5burDFyyOtjsmlPdxdrr2zUurl3AHaNHIvSd/L3BB+QNAmpvOg4DxeigwBVSiJhSCuMaH7NmmuwamVwPeEKUkkKQSJm4ReI4U0Oj4EIAvXKU48y/FvAJDvTWVbnVOA921eGSTUTcc3TQATHDiYJJwVokdUjbCre8aUOf4W6p09bNBIvZ+yqXHbbqOBXn73xwx8Jnwx5QRgE7Jy9wQdkXr2FvPtMviniLDGKG2ysZEoJmQ8nEuCEapAzaqOMfOyUGSgTVaW2sTYyKd7xv9H1eN5PuyvV5iAAAAAElFTkSuQmCC"

static var _shared_material: ShaderMaterial
static var _terrain_layers: Texture2DArray

static func shared_material() -> ShaderMaterial:
    if _shared_material == null:
        _shared_material = ShaderMaterial.new()
        _shared_material.shader = TERRAIN_SHADER
        _shared_material.set_shader_parameter("terrain_layers", texture_layers())
        _shared_material.set_shader_parameter("detail_fade_start", 24.0)
        _shared_material.set_shader_parameter("detail_fade_end", 88.0)
        _shared_material.set_shader_parameter("detail_fade_strength", 0.88)
    return _shared_material

static func texture_layers() -> Texture2DArray:
    if _terrain_layers != null:
        return _terrain_layers

    var images: Array[Image] = [
        _decode_runtime_png(GRASS_TOP_PNG, "grass_top"),
        _decode_runtime_png(GRASS_SIDE_PNG, "grass_side"),
        _decode_runtime_png(DIRT_PNG, "dirt"),
        _decode_runtime_png(STONE_PNG, "stone"),
        _decode_runtime_png(SAND_PNG, "sand"),
    ]

    for index: int in range(5, LAYER_PATHS.size()):
        var texture := load(LAYER_PATHS[index]) as Texture2D
        if texture == null:
            push_error("TEKNIK terrain ore texture failed to load: %s" % LAYER_PATHS[index])
            return null
        var image: Image = texture.get_image()
        if image == null or image.is_empty():
            push_error("TEKNIK terrain ore texture has no image data: %s" % LAYER_PATHS[index])
            return null
        if image.get_width() != LAYER_SIZE or image.get_height() != LAYER_SIZE:
            image.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_LANCZOS)
        images.append(image)

    for image: Image in images:
        if image == null or image.is_empty():
            push_error("TEKNIK terrain texture image is empty")
            return null
        if image.get_format() != Image.FORMAT_RGBA8:
            image.convert(Image.FORMAT_RGBA8)
        if not image.has_mipmaps():
            var mipmap_error: Error = image.generate_mipmaps()
            if mipmap_error != OK:
                push_error("TEKNIK terrain mipmap generation failed")
                return null

    _terrain_layers = Texture2DArray.new()
    var create_error: Error = _terrain_layers.create_from_images(images)
    if create_error != OK:
        push_error("TEKNIK terrain Texture2DArray creation failed: %s" % error_string(create_error))
        _terrain_layers = null
    return _terrain_layers

static func _decode_runtime_png(encoded: String, label: String) -> Image:
    var image := Image.new()
    var decode_error: Error = image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))
    if decode_error != OK:
        push_error("TEKNIK runtime texture decode failed for %s: %s" % [label, error_string(decode_error)])
        return Image.new()
    if image.get_width() != LAYER_SIZE or image.get_height() != LAYER_SIZE:
        image.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_LANCZOS)
    return image

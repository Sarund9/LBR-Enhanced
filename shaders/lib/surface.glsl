/*

Surface Geometry Descriptor

Used:
  program/deferred

Uniforms:

Samplers:


Requires:
  lib/core
  lib/space
  lib/distort
  lib/shadow

Samplers are never required

*/

struct Surface {
    vec3 color;
    float alpha;

    vec3 normal;
    float metallic;
    
    vec3 viewDirection;
    float smoothness;
};

Surface getSurface(
    vec4 sceneColor,    // Raw sampled color from the Scene
    vec4 sceneNormal,   // Raw sampled normal from the Scene
    vec4 sceneDetail,   // Raw sampled 'specular' from the Scene
    vec3 viewPosition
) {
    Surface surface;

    surface.color = tolinear(sceneColor.rgb);
    surface.alpha = sceneColor.a;
    surface.normal = normalize(sceneNormal.rgb * 2.0f - 1.0f); // TODO: Normal Compression

    surface.smoothness = sceneDetail.r;
    surface.metallic = sceneDetail.g;
    // TODO: Subsurface/Porosity/
    // TODO: Emmision
    
    surface.viewDirection = -viewPosition;

    return surface;
}

/*

Surface Geometry Descriptor

Used:
  program/deferred

Requires:
  lib/core
  lib/space
  lib/distort
  lib/shadow

Uniforms:


*/

struct Surface {
    vec3 color;
    float alpha;

    vec3 normal;
    float metallic;
    
    vec3 viewDirection;
    float smoothness;
};

Surface newSurface(
    vec4 sceneColor,    // Raw sampled color from the Scene
    vec4 sceneNormal,   // Uncompressed normals
    vec4 sceneDetail,   // Raw sampled 'specular' from the Scene
    vec3 viewPosition   // View-Space position of Surface
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

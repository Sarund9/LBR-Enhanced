/*

Spatial Maniuplation

Uniforms:

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

*/

vec3 viewSpacePixel(vec2 tx, float depth) {
    vec3 clipSpace = vec3(tx, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return view;
}

vec4 relativeWorldSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return gbufferModelViewInverse * vec4(view, 1.0f);
}

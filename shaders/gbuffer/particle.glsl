

#include "/lib/core.glsl"

#ifdef __VERTEX__

#include "/lib/normal.glsl"

attribute vec4 at_tangent;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();

    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
}

#endif


#ifdef __PIXEL__

uniform vec3 upPosition;

uniform float viewWidth;
uniform float viewHeight;

// Space
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
// Shadow
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
// Light
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform float nightVision;

#include "/lib/color.glsl"
#include "/lib/normal.glsl"
#ifdef __TRANSLUCENT__
#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/lighting.glsl"
#endif

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;

void main() {
    vec4 albedo = texture2D(texture, vTexUV) * vColor;
    vec4 specularData = texture2D(specular, vTexUV);

    /* Base Normals are always up
       Tangent should be facing away from the camera in eye space
       Perpendicular to the upPosition
    */
    vec3 up = normalize(upPosition);
    vec3 tangent = cross(up, vec3(1, 0, 0));
    vec3 binormal = cross(tangent, up);
    
    vec3 normal = normalize(denormalizeNormalSample(texture2D(normals, vTexUV)) * rotor(
        up, tangent, binormal
    ));
    
    albedo.rgb = lighten(albedo.rgb, 0.35);

#ifdef __TRANSLUCENT__
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 posVS = viewSpacePixel(viewUV, gl_FragCoord.z);
    
    vec4 posRWS = (gbufferModelViewInverse * vec4(posVS, 1));

    TranslucentSurface surf; {
        surf.albedo = tolinear(albedo.rgb);
        surf.alpha = albedo.a;
        surf.normal = normalize(normal);
        surf.smoothness = specularData.r;
        surf.metallic = specularData.g;
        surf.viewPosition = posVS;
        surf.worldPosition = posRWS.xyz;
        surf.light = vLightUV;
    }
    vec3 diffuse = translucentBRDF(surf);
    // debug(diffuse);

    debugblender(diffuse, surf.alpha);

    /* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(diffuse, surf.alpha);
#else
    /* DRAWBUFFERS:0123 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(vLightUV, 0, 1);
    gl_FragData[3] = specularData; // R M T E
#endif
}

#endif

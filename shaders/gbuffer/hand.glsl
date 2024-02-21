

#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

varying vec2 lightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;

attribute vec4 at_tangent;

#include "/lib/normal.glsl"

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vec3 normal = gl_Normal;
    color = gl_Color;

    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;

    vertex_conormals(
        normal, at_tangent,
        gl_NormalMatrix,
        vNormal, vTangent, vBinormal
    );
}


#endif


#ifdef __PIXEL__

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferModelView;

// Space
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
// Shadow
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
// Water
uniform vec3 upPosition;
// Light
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform float nightVision;

#include "/lib/color.glsl"
#include "/lib/normal.glsl"
#include "/lib/noise.glsl"
#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D depthtex1;

varying vec2 lightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;

void main() {
    vec4 albedo = texture2D(texture, vTexUV) * color;
    vec3 normal = normalize(
        sampleNormalMap(normals, vTexUV) * rotor(vNormal, vTangent, vBinormal)
    );
    vec4 specularData = texture2D(specular, vTexUV);

#ifdef __TRANSLUCENT__
    // Get the scene depth and position
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    // float sceneDepth = texture2D(depthtex1, viewUV).r;

    // vec3 posVS = (gbufferModelView * vec4(posRWS, 1)).xyz;
    vec3 posVS = viewSpacePixel(viewUV, gl_FragCoord.z);

    Surface surface; {
        surface.color = albedo.rgb;
        surface.alpha = albedo.a;
        surface.normal = normal;
        surface.smoothness = specularData.r;
        surface.metallic = specularData.g;
        surface.viewDirection = -posVS;
    }
    
    Shadow shadow = incomingShadow(vec4(posRWS, 1));
    Light light = surfaceLight(surface, lightUV, shadow);
    
    vec4 fragColor;
    vec3 surfBRDF = directBRDF(surface, light);

    fragColor.rgb = surfBRDF;
    fragColor.a = surface.alpha;

    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;
    
#else
    /* DRAWBUFFERS:0123 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(lightUV, 0, 1);
    gl_FragData[3] = specularData; // S M T E
#endif
}

#endif

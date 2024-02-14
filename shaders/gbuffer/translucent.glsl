
#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    texUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;

    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
    
    int BlockID = int(max(mc_Entity.x - BaseID, 0));
    watermask = BlockID == ID_Water ? 1 : 0;
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
// Water
uniform vec3 upPosition;
// Light
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/shadow.glsl"
#include "/lib/surface.glsl"
#include "/lib/water.glsl"
#include "/lib/light.glsl"
#include "/lib/brdf.glsl"

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D colortex7; // Scene Color
uniform sampler2D depthtex0; // Scene Depth to this object
uniform sampler2D depthtex1; // Scene Depth behind this object

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;

void main() {
    vec4 fragColor;
    
    // Get the screen UV
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

    vec4 sceneColor = texture2D(colortex7, viewUV);
    float sceneDepth = texture2D(depthtex1, viewUV).r;

    vec3 posVS = (gbufferModelView * vec4(posRWS, 1)).xyz;

    vec4 scenePosRWS = relativeWorldSpacePixel(viewUV, sceneDepth);
    vec3 scenePosVS = viewSpacePixel(viewUV, sceneDepth);

    vec4 albedo = texture2D(texture, texUV) * color;
    vec4 specularData = texture2D(specular, texUV);

    // Surface surface = newSurface(albedo, vec4(normal, 0), specularData, posVS);
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
    
    vec3 surfBRDF = directBRDF(surface, light);
    fragColor.rgb = surfBRDF;
    fragColor.a = albedo.a;

    // debug(posVS.z + 1);

    fragColor.rgb = mix(fragColor.rgb, _debug_value.rgb, _debug_value.a);
    fragColor.a = max(fragColor.a, _debug_value.a);
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif

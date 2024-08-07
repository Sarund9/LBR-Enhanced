/*

COMPOSITE PASS 1: LIGHT PASS


*/

#include "/lib/core.glsl"

varying vec2 TexCoords;

// const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
// const vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);
// 158 -10 +202 +11 == 
#ifdef __VERTEX__

void main() {
	gl_Position = ftransform();
	TexCoords = gl_MultiTexCoord0.st;
}

#endif

#ifdef __PIXEL__

uniform sampler2D noisetex; // Utility noise texture

uniform float viewWidth;
uniform float viewHeight;

// SHADOW
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

uniform float aspectRatio;

uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth; // Used for eye adaptation
uniform vec3 skyColor;
uniform float nightVision;

#include "/lib/color.glsl"
#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/lighting.glsl"

// UNIFORMS
uniform sampler2D colortex0; // albedo
uniform sampler2D colortex1; // normal
uniform sampler2D colortex2; // lightmap
uniform sampler2D colortex3; // detail
uniform sampler2D colortex4; // aliasing

uniform sampler2D depthtex0; // full scene depth

void main() {
    vec4 sceneColor = texture2D(colortex0, TexCoords);
    
    float depth = texture2D(depthtex0, TexCoords).r;
    // Skip the Skybox, write straigt to Scene Color
    if (depth == 1.0) {
        gl_FragData[0] = vec4(tolinear(sceneColor.rgb), luma(sceneColor.rgb));
        return;
    }
    
    vec4 sceneLight = texture2D(colortex2, TexCoords);
    // Unlit objects
    if (sceneLight.a < 1.0)
    {
        gl_FragData[0] = vec4(tolinear(sceneColor.rgb), luma(sceneColor.rgb));
        return;
    }

    vec4 sceneNormal = texture2D(colortex1, TexCoords);
    vec4 sceneDetail = texture2D(colortex3, TexCoords);

    vec3 posVS = viewSpacePixel(TexCoords, depth);
    vec4 posRWS = relativeWorldSpacePixel(TexCoords, depth);
    vec4 posVXS = voxelPerfect(posRWS + vec4(cameraPosition, 0), 16) - vec4(cameraPosition, 0);
    posVXS += 0.01;
    vec3 posVVS = (gbufferModelView * posVXS).xyz;

    SolidSurface solid; {
        solid.albedo = tolinear(sceneColor.rgb);
        solid.normal = normalize(sceneNormal.rgb * 2.0 - 1.0);
        solid.smoothness = sceneDetail.r;
        solid.metallic = sceneDetail.g;
        
        solid.light = sceneLight.xy;
        solid.viewPosition = posVVS;
        solid.worldPosition = posRWS.xyz;
    }
    vec3 diffuse = solidBRDF(solid);
    
    // debug(posRWS.rgb + cameraPosition);
    // debug(voxelPerfect(posRWS + vec4(cameraPosition, 0), 16).rgb);
    // debug(posVXS.rgb);
    debugblender(diffuse);

 /* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(diffuse, 1);
}

#endif

/*

COMPOSITE PASS 1: LIGHT PASS


*/

#include "/lib/core.glsl"

varying vec2 TexCoords;

// const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
// const vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);
// 158 -10 +202 +11 == 
#ifdef __VERTEX__

uniform float day;

void main() {
	gl_Position = ftransform();
	TexCoords = gl_MultiTexCoord0.st;
}

#endif

#ifdef __PIXEL__

const float sunPathRotation = -9.0; // TODO: Settings

uniform sampler2D noisetex; // Utility noise texture

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float aspectRatio;
uniform vec3 cameraPosition;

uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth; // Used for eye adaptation
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 skyColor;

#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/shadow.glsl"
#include "/lib/surface.glsl"
#include "/lib/light.glsl"
#include "/lib/brdf.glsl"

// UNIFORMS
uniform sampler2D colortex0; // albedo
uniform sampler2D colortex1; // normal
uniform sampler2D colortex2; // lightmap
uniform sampler2D colortex3; // detail

uniform sampler2D depthtex0; // full scene depth

void main() {
    vec4 sceneColor = texture2D(colortex0, TexCoords);

    float depth = texture2D(depthtex0, TexCoords).r;
    // Skip the Skybox, write straigt to Scene Color
    if (depth == 1.0) {
        gl_FragData[0] = sceneColor;
        return;
    }

    vec4 sceneNormal = texture2D(colortex1, TexCoords);
    vec4 sceneDetail = texture2D(colortex3, TexCoords);

    vec3 posVS = viewSpacePixel(TexCoords, depth);
    vec4 posRWS = relativeWorldSpacePixel(TexCoords, depth);
    // vec4 posWS = vec4(cameraPosition, 0) + posRWS;

    // vec4 posVOXEL = voxelPerfect(posWS + vec4(.0001), 16);
    // vec4 posVOXEL_RWS = posVOXEL - vec4(cameraPosition, 0);
    // vec4 posVOXEL_VS = gbufferModelView * posVOXEL_RWS;

    Surface surface = newSurface(sceneColor, sceneNormal, sceneDetail, posVS);

    vec4 sceneLight = texture2D(colortex2, TexCoords);

    Shadow shadow = incomingShadow(posRWS);
    
    Light mainLight = incomingLight(surface.normal, sceneLight.xy, shadow);
    
    vec3 diffuse;
    diffuse = directBRDF(surface, mainLight);

    diffuse = mix(diffuse, _debug_value.rgb, _debug_value.a);

 /* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(diffuse, luma(mainLight.color));
}

#endif

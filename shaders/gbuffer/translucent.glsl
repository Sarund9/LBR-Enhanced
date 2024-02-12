

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;

#ifdef __VERTEX__

#include "/lib/core.glsl"

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

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

#include "/lib/core.glsl"
#include "/lib/water.glsl"

uniform sampler2D texture;
uniform sampler2D normals;

uniform sampler2D colortex7; // Scene Color
uniform sampler2D depthtex1; // Scene Depth, no transparents, no hand
// uniform sampler2D depthtex2;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

vec4 relativeWorldSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return gbufferModelViewInverse * vec4(view, 1.0f);
}

vec4 translucent() {
    vec4 albedo = texture2D(texture, texUV) * color;
    

    return albedo;
}

void main() {
    vec4 fragColor;
    if (watermask > 0.5) {
        // Is Water
        fragColor = vec4(.1, .4, .8, .6);
    }
    else
    {   // Translucent
        fragColor = translucent();
    }
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif

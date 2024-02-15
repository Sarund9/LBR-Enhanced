
#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;

    vNormal = gl_NormalMatrix * gl_Normal;
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
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

#include "/lib/color.glsl"
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

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;

void main() {
    vec4 fragColor;
    
    // Get the scene depth and position
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float sceneDepth = texture2D(depthtex1, viewUV).r;

    vec3 posVS = (gbufferModelView * vec4(posRWS, 1)).xyz;

    vec4 albedo = texture2D(texture, vTexUV);
    vec4 specularData = texture2D(specular, vTexUV);

    Surface surface; {
        vec4 col = albedo * color;
        
        // WATER: Bedrock Waters contrast Reduction
        const vec3 UniformWater = vec3(0.0667, 0.3098, 0.3569);
        surface.color = mix(col.rgb, UniformWater, .5 * watermask);
        /* Bedrock Waters mod changes water colors across biomes
        But the effect can be jarring with a more detailed water shader
        This brings the color back 50% to a vanilla colors*/

        surface.alpha = col.a;
        surface.normal = vNormal;
        surface.smoothness = specularData.r;
        surface.metallic = specularData.g;
        surface.viewDirection = -posVS; // TODO: This doesn't work
    }

    // Water
    // TODO: Move to water.glsl
    if (watermask > .5)
    {
        // Water Opacity
        const float DeepDiffusionDistance = 24.0;
        const float FarDiffusionStart = 12.0;
        const float FarDiffusionEnd = 46.0;

        // -> composeWater()
        vec4 scenePosRWS = relativeWorldSpacePixel(viewUV, sceneDepth);
        float trueDepth = length(scenePosRWS.xyz);
        float trueDistance = length(posRWS);
        
        float deepDiffusion = (trueDepth - trueDistance) / DeepDiffusionDistance;
        float distanceDiffusion = smoothstep(FarDiffusionStart, FarDiffusionEnd, trueDistance);
        
        // TODO: Base the distance diffusion on horizontal distance

        float diffusion = lstep(deepDiffusion, distanceDiffusion * .8, 7);
        float opacity = mix(surface.alpha, 1, diffusion);

        surface.alpha = clamp01(opacity);
        surface.smoothness = 1;
        surface.metallic = 1;
    }
    
    Shadow shadow = incomingShadow(vec4(posRWS, 1));
    Light light = surfaceLight(surface, vLightUV, shadow);
    
    vec3 surfBRDF = directBRDF(surface, light);
    
    fragColor.rgb = surfBRDF;
    fragColor.a = surface.alpha;

    fragColor.rgb = mix(fragColor.rgb, _debug_value.rgb, _debug_value.a);
    fragColor.a = max(fragColor.a, _debug_value.a);
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif

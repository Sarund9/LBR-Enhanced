
#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;

#include "/lib/normal.glsl"
#include "/lib/noise.glsl"

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;
varying vec3 vPositionCS;
varying float watermask;
varying vec3 vWaterSample;

void main() {
    // vec4 value = gl_Position;
    gl_Position = ftransform();
    // Assign values to varying variables
    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vPositionCS = gl_Position.xyz;
    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;
    
    vec3 normal = gl_Normal;
    color = gl_Color;
    
    int BlockID = int(max(mc_Entity.x - BaseID, 0));
    watermask = BlockID == ID_Water ? 1 : 0;

    if (BlockID == ID_Water)
    {
        vec3 posWS = cameraPosition + posRWS;
        vWaterSample.xz = posWS.xz * 0.8;
        vWaterSample.y = frameTimeCounter * 2;
        
        // float factor = simplex3d(vWaterSample);

        {
            // const float StdVoxel = 1.0 / 16.0;
            // float height = mix(-StdVoxel, StdVoxel, factor);
            // // Compute and add an offset in clip space
            // vec4 offset = vec4(0, height, 0, 1);
            // offset *= gbufferModelView;
            // offset *= gbufferProjection;
            // offset.z = 0;
            // gl_Position += offset;
        }
    }

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
// Water
uniform vec3 upPosition;
// Light
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

#include "/lib/color.glsl"
#include "/lib/normal.glsl"
#include "/lib/noise.glsl"
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
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;
varying vec3 vWaterSample;

void main() {
    // Get the scene depth and position
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float sceneDepth = texture2D(depthtex1, viewUV).r;

    // vec3 posVS = (gbufferModelView * vec4(posRWS, 1)).xyz;
    vec3 posVS = viewSpacePixel(viewUV, gl_FragCoord.z);

    vec4 albedo = texture2D(texture, vTexUV);
    vec4 specularData = texture2D(specular, vTexUV);

    Surface surface;
    Shadow shadow = incomingShadow(vec4(posRWS, 1));
    Light light;
    {
        surface.smoothness = specularData.r;
        surface.metallic = specularData.g;
        surface.viewDirection = -posVS;
    }

    if (watermask < .5)
    {
        vec4 col = albedo * color;
        surface.color = col.rgb;
        surface.alpha = col.a;

        surface.normal = normalize(
            sampleNormalMap(normals, vTexUV) * rotor(vNormal, vTangent, vBinormal)
        );
        
        light = surfaceLight(surface, vLightUV, shadow);
    }
    else
    {
        
        // Water Normals
        vec4 simplex; {
            vec3 p = vWaterSample;
            p.xz = (floor(p.xz * 16.0) / 16.0) + 0.5;
            p.y = floor(p.y * 12.0) / 12.0;
            simplex.w = waternoise_fract(p);
            const vec2 e = vec2(1 / 16.0, 0);
            /* Tangent points toward positive X
               Binormal points toward positive Y */
            simplex.xyz = vec3(0, 0, 1);

            const float WaterNormalMult = 2;

            simplex.x += (simplex.w - waternoise_fract(p - e.xyy)) * WaterNormalMult;
            simplex.y += (simplex.w - waternoise_fract(p - e.yyx)) * WaterNormalMult;

            simplex.xyz = normalize(simplex.xyz);
            
        }
        vec3 blendedNormal = normalize(
            simplex.xyz * rotor(vNormal, vTangent, vBinormal)
        );
        surface.normal = blendedNormal;

        vec4 col = color;
        // WATER: Bedrock Waters contrast Reduction
        const vec3 UniformWater = vec3(0.051, 0.1255, 0.2824);
        col.rgb = mix(col.rgb, UniformWater, mix(.5, .7, simplex.w));
        // surface.color = albedo.rgb * col;
        // albedo.rgb *= mix(.8, .9, simplex.w);
        col.a *= albedo.a;
        col.rgb *= mix(pow(avg(albedo.rgb), 3) * 1.3, .1, 1 - simplex.w);

        // debug(mix(pow(avg(albedo.rgb), 3), mix(.3, 1, simplex.w), .7));
        // debug(albedo.rgb);

        surface.color = col.rgb;

        surface.smoothness = 1;
        surface.metallic = 0;

        surface.alpha = col.a;
        light = surfaceLight(surface, vLightUV, shadow);

        /* Bedrock Waters mod changes water colors across biomes
        But the effect can be jarring with a more detailed water shader
        This brings the color back 50% to a vanilla-ish color */

        float dotview = dot(surface.normal, surface.viewDirection);

        // TODO: Move to water.glsl
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
        // debug(surface.viewDirection);

        float diffusion = lstep(deepDiffusion, distanceDiffusion * .8, 7);
        float opacity = mix(col.a, 1, deepDiffusion);

        surface.alpha = clamp01(opacity * .9);
        surface.smoothness = mix(.5, .9, simplex.w);
        surface.metallic = 0;
    }
    
    
    
    // debug(light.color);

    vec4 fragColor;
    vec3 surfBRDF = directBRDF(surface, light);

    // debug(surface.normal);

    fragColor.rgb = surfBRDF;
    fragColor.a = surface.alpha;

    fragColor.rgb = mix(fragColor.rgb, _debug_value.rgb, _debug_value.a);
    fragColor.a = max(fragColor.a, _debug_value.a);
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif

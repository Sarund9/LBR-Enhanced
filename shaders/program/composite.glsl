/*

COMPOSITE PASS 1: LIGHT PASS


*/

#include "/lib/core.glsl"

varying vec2 TexCoords;

const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
const vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);

#ifdef __VERTEX__

uniform float day;

void main() {
	gl_Position = ftransform();
	TexCoords = gl_MultiTexCoord0.st;
}

#endif

#ifdef __PIXEL__

#include "/lib/distort.glsl"

// Color we wrote to
uniform sampler2D colortex0;
uniform sampler2D colortex1; // normal
uniform sampler2D colortex2; // lightmap


uniform sampler2D depthtex0; // Scene Depth

uniform sampler2D shadowtex0;   // shadow attenuation
uniform sampler2D shadowtex1;   // shadow (no transparents)
uniform sampler2D shadowcolor0; // shadow colors

uniform sampler2D noisetex; // Utility noise texture

uniform ivec2 eyeBrightnessSmooth; // somehow used to detect distance
uniform vec3 sunPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;


/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;

const int colortex2Format = RGBA16;
*/

// Engine Parameters
const int shadowMapResolution = 1024;
const int noiseTextureResolution = 128;
const float sunPathRotation = -9.0;

float AdjustLightmapTorch(in float torch) {
    const float K = 2.0f;
    const float P = 5.06f;
    return K * pow(torch, P);
}

float AdjustLightmapSky(in float sky) {
    float sky_2 = sky * sky;
    return sky_2 * sky_2;
}

vec2 AdjustLightmap(in vec2 Lightmap) {
    vec2 NewLightMap;
    NewLightMap.x = AdjustLightmapTorch(Lightmap.x);
    NewLightMap.y = AdjustLightmapSky(Lightmap.y);
    return NewLightMap;
}

// Input is not adjusted lightmap coordinates
vec3 GetLightmapColor(in vec2 Lightmap) {
    // First adjust the lightmap
    Lightmap = AdjustLightmap(Lightmap);
    // Color of the torch and sky. The sky color changes depending on time of day but I will ignore that for simplicity
    const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
    const vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);
    // Multiply each part of the light map with it's color
    vec3 TorchLighting = Lightmap.x * TorchColor;
    vec3 SkyLighting = Lightmap.y * SkyColor;
    // Add the lighting togther to get the total contribution of the lightmap the final color.
    vec3 LightmapLighting = TorchLighting + SkyLighting;
    // Return the value
    return LightmapLighting;
}

float Visibility(in sampler2D ShadowMap, in vec3 SampleCoords) {
    return step(SampleCoords.z - 0.001f, texture2D(ShadowMap, SampleCoords.xy).r);
}

vec3 TransparentShadow(in vec3 SampleCoords){
    float ShadowVisibility0 = Visibility(shadowtex0, SampleCoords);
    float ShadowVisibility1 = Visibility(shadowtex1, SampleCoords);
    vec4 ShadowColor0 = texture2D(shadowcolor0, SampleCoords.xy);
    // Perform a blend operation with the sun color
    vec3 TransmittedColor = ShadowColor0.rgb * (1.0f - ShadowColor0.a);
    return mix(TransmittedColor * ShadowVisibility1, vec3(1.0f), ShadowVisibility0);
}

#define SHADOW_SAMPLES 2
const int ShadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

vec4 worldSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return gbufferModelViewInverse * vec4(view, 1.0f);
}

vec3 GetShadow(float depth) {
    vec4 World = worldSpacePixel(TexCoords, depth);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    ShadowSpace.xy = distortPosition(ShadowSpace.xy);
    vec3 SampleCoords = ShadowSpace.xyz * 0.5f + 0.5f;
    
    float RandomAngle = texture2D(noisetex, TexCoords * 20.0f).r * 100.0f;
    float cosTheta = cos(RandomAngle);
	float sinTheta = sin(RandomAngle);
    // We can move our division by the shadow map resolution here for a small speedup
    mat2 Rotation =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    vec3 ShadowAccum = vec3(0.0f);
    for(int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++){
        for(int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++){
            vec2 Offset = Rotation * vec2(x, y);
            vec3 CurrentSampleCoordinate = vec3(SampleCoords.xy + Offset, SampleCoords.z);
            ShadowAccum += TransparentShadow(CurrentSampleCoordinate);
        }
    }
    ShadowAccum /= TotalSamples;
    return ShadowAccum;
}

// Applies stylized shading to a color
vec3 shade(vec3 color) {
    vec3 res = color;
    float grayscale = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(res, vec3(grayscale), vec3(0.3)); // move 30% towards grayscale

    // Make it darker and more blue
    res *= vec3(0.95, 0.91, 1.14); // 5 + 9 == 14
    res *= 0.1;

    return res;
}

vec3 czm_saturation(vec3 rgb, float adjustment) {
    // Algorithm from Chapter 16 of OpenGL Shading Language
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    vec3 intensity = vec3(dot(rgb, W));
    return mix(intensity, rgb, adjustment);
}

vec3 getLightColor(float blocklight, float skylight, vec3 shadow, vec3 normal) {
    // TODO: Better color space for Hardcore Darkness
    // TODO: Proper defferred color chanel (HDR)
    
    const float MaxLight = 2.5;

    // Adjust game lighting
    float block2; float sky2;
    {
        const float P = 4;
        block2 = MaxLight * pow(blocklight, P); // (.5 1) -> (.06 1) x 2.4 == .15 2.5

        sky2 = MaxLight * pow(skylight, 2.5); // (.5 1) -> (.25 1)
    }

    const vec3 blockLightColorNear   = vec3(0.9216, 0.5843, 0.451);
    const vec3 blockLightColorFar    = vec3(1.0, 0.7647, 0.6392);

    // Calculate Sun Light
    float dotl = dot(normal, normalize(sunPosition));
    float inLight = max(dotl, 0);
    shadow = czm_saturation(shadow, 2.4);
    vec3 sunlight = shadow * inLight * MaxLight;
    // Blend: blocklight, skylight, sunlight 
    // debughdr(pow(dotl, 1/5));
    // C (Requires separate shadow color & attenuation ?)

    // TODO: Separate shadow attenuation and color

    // Add a 50/50 blend of sky and sun lighting
    
    float mask = min(1 - avg(sunlight) / 3, sky2 / 3);
    // debug(mask);
    // debug(sunlight);

    vec3 envBlend = mix(
        vec3(sky2),
        sunlight,
    mask); // <- B
    // debug(envBlend);

    // When skylight is 1, but outside of sunlight
    /*
    
    when skylight is low, darken sunlight
    when skylight is high, darken sunlight shadows
    MASK:
        1 when sunlight is low
        0 when skylight is low

    */


    // TODO: (A) Limit blocklight in skylight areas
    // float eyeAdjustedBlocklightMask = max(block2 - sky2, 0);
    
    // debug(mix(block2, pow(block2, 1/2), eyeAdjustedBlocklightMask) / 2);
    // debughdr(eyeAdjustedBlocklightMask);
    // debughdr(avg(envBlend + blocklight));
    // debughdr(eyeAdjustedBlocklightMask);

    // TODO: (B) Limit sunlight in areas darkened by skylight
    // TODO: (C) Mask out shadows in areas lightened by blocklight


    // debug(smoothstep(blocklight, 0, 1 - skylight));
    // debug(shadow);

    // shadow += 0.1;
    // res += linearstep(shadow * inLight, 0.1, 1);
    


    // TODO: Apply darkness to block sides/bottom (vanilla does this)

    // TODO: Night Vision
    // TODO: Screen Brightness ??

    vec3 res = envBlend + block2 * blockLightColorFar;

    // TONEMAPPER
    res = min(res, max(vec3(
        pow(res.x, 1 / 2.7),
        pow(res.y, 1 / 2.7),
        pow(res.z, 1 / 2.7)
    ) - .34, .14));

    // debughdr(avg(envBlend));
    // debughdr(block2);
    // debughdr(avg(res));

    // float factor = abs(1.5 - avg(res));
    // res = mix(res, res * vec3(2, 0.5, 0.5), factor);
    // if (avg(res) > 2) {
    //     res = vec3(10, 0, 0);
    // }
    // if (avg(res) > 1.1) {
    //     // debug(0, 1, 1);
    //     res *= vec3(1 + avg(res) , 0.5, 0.5);
    // }

    return res;
}

/*

Axis Aligned Texture Sampling

https://www.youtube.com/watch?v=d6tp43wZqps

TODO: How to make a texture sampled linearly

Terrain texture is already sampled in linear


vec2 tx = texCoord * BlockTextureSize;

vec2 offset = clamp(fract(tx) * PixelsPerTexel, 0, 0.5) - 
    clamp((1 - fract(tx)) * PixelsPerTexel, 0, 0.5);

vec2 uv = (floor(tx) + 0.5 + offset) * BlockTextureSize;

return uv;

terrain_solid.fsh: terrain_solid.fsh: 0(38) : error C1068: too much data in type constructor


TODO: Pre Multiply the Alpha

*/
// const float BlockTextureSize = 16;
// const float PixelsPerTexel = 1; // assume

// vec4 axisAlignedSample(in sampler2D image, vec2 texCoord) {
    
//     vec2 boxSize = clamp((abs(dFdx(texCoord))) + abs(dFdy(texCoord)) * BlockTextureSize, 1e-5, 1);

//     vec2 tx = texCoord * BlockTextureSize - 0.5 * boxSize;

//     // vec2 offset = clamp((fract(tx) - (1 - boxSize)) / boxSize, 0, 1);
//     vec2 offset = smoothstep(1 - boxSize, vec2(1.0), fract(tx));

//     vec2 uv = (floor(tx) + 0.5 + offset) * BlockTextureSize;
    
//     // return texture2D(image, uv);
//     return vec4(uv, 0, 1);
// }

void main() {
    
    vec3 albedo = tolinear(texture2D(colortex0, TexCoords).rgb);

    float depth = texture2D(depthtex0, TexCoords).r;
    if (depth == 1.0f) {
        gl_FragData[0] = vec4(albedo, 1.0);
        return;
    }

    vec3 normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);

    float blocklight;
    float skylight;
    {
        vec4 uvs = texture2D(colortex2, TexCoords);
        blocklight = uvs.x;
        skylight = uvs.y;
    }
    
    vec3 diffuse;
    // TODO: Better Shadow mapping
    /*
    Overall better shadow technique for HQ performant shadows
    - Sharper shadows
    - Entity Shadow Distance
    - LOD Shadows (Distant Horizons)
    */
    vec3 shadow = GetShadow(depth);
    
    diffuse = getLightColor(blocklight, skylight, shadow, normal);
    // diffuse = vec3(pow(max(blocklight, skylight), 3)) * .8;
    diffuse *= albedo.rgb;
    
    diffuse = togamma(diffuse); // convert to gamma space

    diffuse = mix(diffuse, _debug_value.rgb, _debug_value.a);

 /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(diffuse, 1);
}

#endif

    /*
Desired:
    When light is 15, keep it bright
        Cast bright shadows (Mostly changes color)
    When light is 0,

    X is light level
    Y is maxxed with real light
    .9 = .9
    .7 = .1
    0 = 0

Color interpolator:
    Where realLight is not in shade,
        Final color should be the same as gameLight
    Where realLight is in shade,
        Final color 

    gameLight is more important

    realLight is able to shade areas from gameLight

    // VANILLA LIGHT FORMULA (Missing Something ??)
    */

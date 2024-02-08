/*

COMPOSITE PASS 1: LIGHT PASS


*/

#include "/lib/core.glsl"

varying vec2 TexCoords;

// const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
// const vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);

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

const float sunPathRotation = -9.0;

// vec3 TransparentShadow(in vec3 SampleCoords, float ShadowVisibility0, float ShadowVisibility1)
// {
//     vec4 ShadowColor0 = texture2D(shadowcolor0, SampleCoords.xy);
//     // Perform a blend operation with the sun color
//     vec3 TransmittedColor = ShadowColor0.rgb * (1.0f - ShadowColor0.a);
//     return mix(TransmittedColor * ShadowVisibility1, vec3(1.0f), ShadowVisibility0);
// }

vec4 worldSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return gbufferModelViewInverse * vec4(view, 1.0f);
}


// TODO: Better Shadow mapping
/*
Overall better shadow technique for HQ performant shadows
- Sharper shadows
- Entity Shadow Distance
- LOD Shadows (Distant Horizons)
*/

// SHADOW PARAMETERS
#define SHADOW_SAMPLES 2
const int ShadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

// Engine Parameters
const int shadowMapResolution = 2048;
const int noiseTextureResolution = 128;

struct Shadow {
    vec3 color;
    float brightness;        // How bright is the sun
    float solidAttenuation;  // Transparents are solid
    float clipAttenuation;   // Transparents are cut out
};

vec3 shadowColor(Shadow shadow) {
    return shadow.color * (shadow.clipAttenuation - shadow.solidAttenuation);
}

float visibility(in sampler2D map, in vec3 coords) {
    return step(coords.z - 0.001f, texture2D(map, coords.xy).r);
}

Shadow incomingShadow(float depth) {
    vec4 posWS = worldSpacePixel(TexCoords, depth);
    vec4 posSS = shadowProjection * shadowModelView * posWS;
    
    posSS.xy = distortPosition(posSS.xy);
    vec3 coords = posSS.xyz * 0.5f + 0.5f;
    
    Shadow shadow;
    
    vec4 col = texture2D(shadowcolor0, coords.xy);

    shadow.color            = col.rgb;
    shadow.brightness       = col.a;
    shadow.solidAttenuation = visibility(shadowtex0, coords);
    shadow.clipAttenuation  = visibility(shadowtex1, coords);
    return shadow;
}

struct Surface {
    vec3 normal;
    vec3 albedo;
    float alpha;
};

// LIGHT PARAMETERS
const float LightK = 3;
const vec3 AmbientLight = vec3(.001);
const vec3 SkyColor = vec3(0.8902, 1.0, 0.9843);
const vec3 SunColor = vec3(1.0, 0.9922, 0.9216);
const vec3 BaseBlocklightColor = vec3(1.0, 0.9098, 0.7373);

struct Light {
    vec3 color;
    vec3 direction;
};

vec3 blocklightColor(float T) {
    const vec3 Warm = vec3(1.0, 0.5843, 0.2863);
    const vec3 White = vec3(1.0, 1.0, 1.0);
    const vec3 Cold = vec3(0.749, 0.9647, 1.0);

    // float warm = T * 5;
    // float cold = T * -5 + 5;

    // vec3 warmclr = oklab_mix(Warm, White, smin(warm, 1, 1));
    // vec3 coldclr = oklab_mix(Cold, White, smin(cold, 1, 1));

    // vec4 col = mix(mix(firstColor, middleColor, xy.x/h), mix(middleColor, endColor, (xy.x - h)/(1.0 - h)), step(h, xy.x));

    return getGradient(vec4(Warm, 0), vec4(White, .3), vec4(White, .9), vec4(Cold, 1), T);
}

vec3 incomingLight(Surface surface, float blocklight, float skylight, Shadow shadow)
{
    const vec3 Warm = vec3(1.0, 0.6941, 0.2902);

    float block     = pow(blocklight, 3.2);   // (.1, 3)
    vec3  blockclr  = blocklightColor(.08) * block * 1.1;
    float sky       = pow(skylight, 2.5);     // (.1, 3)
    vec3  skyclr    = SkyColor * sky;

    float dotl = dot(surface.normal, normalize(sunPosition));
    float smask = (shadow.clipAttenuation - shadow.solidAttenuation); // TODO: <- this may have bugs
    float inl  = max(dotl, smask * .9);
    float trueshadow = mix(shadow.clipAttenuation * shadow.brightness, 1, shadow.solidAttenuation);
    trueshadow = clamp(trueshadow, 0, 1);
    
    float sunlight = n_raiseStart(trueshadow, 0) * inl;

    // TODO: Make shadow color resaturate better during dawn/dusk
    vec3 sunlight_clr = mix(SunColor, resaturate(shadow.color, 1.5), smask);

    // TODO: Vary sun color based on time of day
    
    float envmask = skylight * skylight * .7;
    envmask = clamp(envmask, 0, 1);

    // vec3 env = min(sky * SkyColor, sunlight * sunlight_clr);
    vec3 env = mix(sky * SkyColor, sunlight * sunlight_clr, envmask);
    
    float blendmask = sky;

    vec3 blockblend = mix(
        blockclr * 1.6,
        smin(blockclr, blockclr * .5 + .75, .5),
    blendmask);

    // TODO: Light Colors, Color Space
    // TODO: 

    // Mask out shadows in blocklight
    vec3 lightValue = AmbientLight;
    lightValue += (env + blockblend) * 1.5;
    // TODO: Tonemapping outside this function
    
    /*
    OUTSIDE: (skylight is low)
    - Blocklights do not affect shadows that much
    INSIDE: (sky light < 10)
    - Sunlight is less powerfull, but shadow colors matter
    
    Calculate Inndoor and Outdoor
    Mix by using the Skylight

    */

    return lightValue;
}


void main() {
    Surface surface;
    {
        vec4 s = texture2D(colortex0, TexCoords);
        surface.albedo = texture2D(colortex0, TexCoords).rgb;
        surface.alpha = s.a;
    }

    float depth = texture2D(depthtex0, TexCoords).r;
    if (depth == 1.0f) {
        gl_FragData[0] = vec4(surface.albedo, 1.0);
        return;
    }
    surface.albedo = tolinear(surface.albedo);

    surface.normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);

    float blocklight;
    float skylight;
    {
        vec4 uvs = texture2D(colortex2, TexCoords);
        blocklight = uvs.x;
        skylight = uvs.y;
    }
    
    vec3 diffuse;
    
    Shadow shadow = incomingShadow(depth);
    
    vec3 mainLight = incomingLight(surface, blocklight, skylight, shadow);
    // debug(mainLight);
    // getLighting
    diffuse = surface.albedo * mainLight;

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

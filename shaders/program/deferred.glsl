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

#include "/lib/distort.glsl"

// Color we wrote to
uniform sampler2D colortex0; // albedo
uniform sampler2D colortex1; // normal
uniform sampler2D colortex2; // lightmap
uniform sampler2D colortex3; // specular

uniform sampler2D depthtex0; // Scene Depth

uniform sampler2D shadowtex0;   // shadow attenuation
uniform sampler2D shadowtex1;   // shadow (no transparents)
uniform sampler2D shadowcolor0; // shadow colors

// Trying to see what these are
// uniform sampler2D shadowcolor;  // Identical to shadowcolor0
// uniform sampler2D shadowcolor1; // (Seemingly) Identical
// uniform sampler2D shadow;       // Identical to shadowtex0
// uniform sampler2D watershadow;  // Identical
/*
Documentation Values:
4: watershadow shadowtex0 shadow(if water shadows disabled)
5: shadowtex1 shadow(if water shadows enabled)

13: shadowcolor shadowcolor0
14: shadowcolor1

Q: Why is shadowcolor1
*/


uniform sampler2D noisetex; // Utility noise texture

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

const float sunPathRotation = -9.0;

uniform float aspectRatio;
uniform vec3 cameraPosition;

// 
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth; // Used for eye adaptation
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 skyColor;


// vec3 TransparentShadow(in vec3 SampleCoords, float ShadowVisibility0, float ShadowVisibility1)
// {
//     vec4 ShadowColor0 = texture2D(shadowcolor0, SampleCoords.xy);
//     // Perform a blend operation with the sun color
//     vec3 TransmittedColor = ShadowColor0.rgb * (1.0f - ShadowColor0.a);
//     return mix(TransmittedColor * ShadowVisibility1, vec3(1.0f), ShadowVisibility0);
// }

vec3 viewSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return view;
}

vec4 relativeWorldSpacePixel(vec2 texCoord, float depth) {
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
const int shadowMapResolution = 1024;
const int noiseTextureResolution = 128;

struct Shadow {
    vec3 color;
    float brightness;        // How bright is the sun
    float solidAttenuation;  // Transparents are solid
    float clipAttenuation;   // Transparents are cut out
    // TODO
    // float water;          // 
};

vec3 shadowColor(Shadow shadow) {
    return shadow.color * (shadow.clipAttenuation - shadow.solidAttenuation);
}

float visibility(in sampler2D map, in vec3 coords) {
    return step(coords.z - 0.001f, texture2D(map, coords.xy).r);
}

Shadow incomingShadow(vec4 posWS) {
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
    vec3 viewDirection;
    vec3 color;
    float alpha;
    float metallic;
    float smoothness;
};

Surface getSurface(vec4 sceneColor, vec3 viewPosition) {
    Surface surface;

    surface.color = tolinear(sceneColor.rgb);
    surface.alpha = sceneColor.a;

    vec4 specData = texture2D(colortex3, TexCoords);

    surface.smoothness = specData.r;
    surface.metallic = specData.g;
    // TODO: Subsurface/Porosity/
    // TODO: Emmision
    
    surface.viewDirection = -viewPosition;


    surface.normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);

    return surface;
}

// LIGHT PARAMETERS
const float LightK = 3;
const vec3 AmbientLight = vec3(.001);

const vec3 SkyColor = vec3(0.8902, 1.0, 0.9843);
const vec3 SkyColorNight = vec3(0.1333, 0.1137, 0.1373);

const vec3 SunColor = vec3(1.0, 0.9922, 0.9216);
const vec3 SunColor_Low = vec3(1.0, 0.8275, 0.6431);

const vec3 BaseBlocklightColor = vec3(1.0, 0.9098, 0.7373);



vec3 blocklightColor(float T) {
    const vec3 Warm = vec3(1.0, 0.9059, 0.6235);
    const vec3 White = vec3(1.0, 1.0, 1.0);
    const vec3 Cold = vec3(0.749, 0.9647, 1.0);

    // float warm = T * 5;
    // float cold = T * -5 + 5;

    // vec3 warmclr = oklab_mix(Warm, White, psmin(warm, 1, 1));
    // vec3 coldclr = oklab_mix(Cold, White, psmin(cold, 1, 1));

    // vec4 col = mix(mix(firstColor, middleColor, xy.x/h), mix(middleColor, endColor, (xy.x - h)/(1.0 - h)), step(h, xy.x));

    return getGradient(vec4(Warm, 0), vec4(White, .3), vec4(White, .9), vec4(Cold, 1), T);
}

struct Light {
    vec3 color;
    vec3 direction;
    float directional;
};

Light incomingLight(Surface surface, float blocklight, float skylight, Shadow shadow)
{
    // 0 to 1 is daytime
    // 1 to 2 is nighttime
    float time = worldTime / 12000.0;
    float celestial = sin(time * PI); // > 0 is sun, < 0 is moon

    /*
    500 (0.04)
    
    Values
    11500 (23/24=.958): Starts to diminish
    12500 : Reduced to 55%, Dusk Colored Begins
    13000: Official Night Time, Dusk Color is Max
    13500: Dusk Color is Halved
    14000: No Light
    
    Cel   S     D
    0.95  1.00  0.0
    1.04  0.50  0.3
    1.08  0.1   1.0
    1.12  0.0   0.5
    1.16  0.0   0.0

    */
    float sunFactor; float ddFactor; {
        // Desmos: \min\left(\frac{1.15-x}{.2},\ \frac{1.1-x}{.1}\right)
        float H1 = 1 - clamp01(smoothstep(.95, 1.05, time));
        float H2 = 1 - clamp01(smoothstep(1, 1.1, time));
        sunFactor = min(H1, H2);

        float D1 = clamp01(smoothstep(0.97, 1.04, time));
        float D2 = 1 - clamp01(smoothstep(1.04, 1.12, time));
        
        // NOTE: This creates a (harsh ?) transition between both lights and only dusk at 12K ticks

        ddFactor = max(min(D1, D2), 0);
    }
    
    // Increase sun intensity during noon
    float sunIntensity =
        bellcurve(
            max(time * float(time <= 1), 0),
            .7, 0, 1.1
        ) * .5;
    sunFactor += sunIntensity;

    float moon_height = max(n_raiseStart(-celestial, -.3), 0);
    moon_height *= .2; // Max Light

    // float debugHelper = n_raiseStart(max(blocklight, skylight), -.1);

    // (.1, 3)
    float sky = pow(skylight, 2.5); 
    vec3 skyclr; {
        // float dusk = 1 - smoothstep(0.9, 1.1, time);
        // float factor = 1 - smoothstep(0.9, 1.1, time);

        skyclr = sky * mix(SkyColorNight, skyColor, sunFactor);
    }
    
    // Apply nighttime to sky
    {
        // TODO: Apply Dusk Light
        float factor = clamp01(smoothstep(-.3, .1, celestial));
        factor = 1 + pow(factor - 1, 3); // Desmos: 1+\left(x-1\right)^{3}
        
        sky *= factor;
    }

    float block     = pow(blocklight, 3.2);   // (.1, 3)
    vec3  blockclr  = blocklightColor(0) * block * 1.1; // 0 is the Torch
    
    float dots = dot(surface.normal, normalize(sunPosition));
    float dotm = dot(surface.normal, normalize(moonPosition));

    float smask = (shadow.clipAttenuation - shadow.solidAttenuation); // TODO: <- this may have bugs
    float inl  = max(dots, smask * .9) * sunFactor;

    // debug(shadow.brightness);
    float trueshadow = mix(shadow.clipAttenuation * shadow.brightness, 1, shadow.solidAttenuation);
    trueshadow = clamp01(trueshadow);
    
    float sunlight = trueshadow * inl;

    // TODO: Make shadow color resaturate better during dawn/dusk
    vec3 shadowclr = resaturate(shadow.color, 1.5);
    vec3 sunlight_clr = mix(SunColor, shadowclr, smask);

    // TODO: Go back to innDoor/outDoor lightings
    // TODO: Eye Adaptation

    // Better to use a more realistic system
    /*
    Sky Light:



    */

    float envmask = square(skylight) * .7;
    envmask = clamp01(envmask);

    vec3 env = mix(skyclr, sunlight * sunlight_clr, envmask);
    
    float blendmask = sky;
    
    vec3 blockblend = mix(
        blockclr * 1.6,
        psmin(blockclr, blockclr * .5 + .75, .5),
    blendmask);

    // TODO: Light Colors, Color Space
    // TODO: 

    // Mask out shadows in blocklight
    Light light;
    light.color = (env + blockblend) * 1.5;
    // debug(sunPosition / 100.0);
    light.direction = normalize(sunPosition);
    light.directional = sunlight;
    
    // TODO: Tonemapping outside this function
    
    
    return light;
}

float specularStrenght(Surface surface, Light light) {
    /*
    light.direction.xyz:   -> sun
    surface.normal:        normal in view space
    surface.viewDirection: view space position -> 0 0 0
    */
    
    vec3 fragToEye = normalize(surface.viewDirection);
    vec3 reflected = normalize(reflect(-light.direction, surface.normal));

    float factor = dot(fragToEye, reflected);

    // Desmos: \left(\frac{\left(x+a-1\right)}{a}\right)^{b}\cdot c
    const float Threshold = .05;
    const float Power = 6;

    factor = pow(
        (factor + Threshold - 1) / Threshold,
        Power
    );
    
    float roughness; {
        float perceptualRoughness = 1 - surface.smoothness;
        roughness = square(perceptualRoughness);
    }
    // TODO: Roughness

    return max(factor, 0) * light.directional;

    // vec3 h = normalize(-light.direction + surface.viewDirection);
	// float nh2 = square(clamp01(dot(surface.normal, h)));
	// float lh2 = square(clamp01(dot(light.direction, h)));
	// float r2 = square(roughness);
	// float d2 = square(nh2 * (r2 - 1.0) + 1.00001);
	// float normalization = roughness * 4.0 + 2.0;
	// return r2 / (d2 * max(0.1, lh2) * normalization);
}

vec3 BRDF(Surface surface, Light light) {
    
    // Light that enters the material
    vec3 incomingLight = surface.color * light.color;

    // Divide the light into diffused, and reflected
    vec3 diffuse; vec3 specular;
    {
        vec3 minReflect = vec3(0.04) * light.color;

        // LBR: Total light color is doubled, metals keep 50% of their color, and nonmetals reflect 50%
        diffuse = mix(minReflect, incomingLight, 1 - surface.metallic * .5);
        specular = mix(minReflect, incomingLight, surface.metallic);
    }

    // DirectBRDF
    vec3 direct = diffuse;

    // Specular Highlights
    float specularMask = specularStrenght(surface, light) * 7;
    // debug(specularMask);
    direct += specularMask
        * resaturate(specular, 2); // LBR: Specular Highlight Saturation
    
    return direct;
}

void main() {
    vec4 sceneColor = texture2D(colortex0, TexCoords);

    float depth = texture2D(depthtex0, TexCoords).r;
    if (depth == 1.0) {
        gl_FragData[0] = sceneColor;
        return;
    }

    // debug(depth);

    vec3 posVS = viewSpacePixel(TexCoords, depth);
    vec4 posRWS = relativeWorldSpacePixel(TexCoords, depth);
    vec4 posWS = vec4(cameraPosition, 0) + posRWS;


    Surface surface = getSurface(sceneColor, posVS);

    float blocklight;
    float skylight;
    {
        vec4 uvs = texture2D(colortex2, TexCoords);
        blocklight = uvs.x;
        skylight = uvs.y;
    }
    
    Shadow shadow = incomingShadow(posRWS);
    
    // debug(shadow.color);

    Light mainLight = incomingLight(surface, blocklight, skylight, shadow);
    
    vec3 diffuse;
    diffuse = BRDF(surface, mainLight);

    diffuse = mix(diffuse, _debug_value.rgb, _debug_value.a);

 /* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(diffuse, luma(mainLight.color));
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

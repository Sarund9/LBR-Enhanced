/*

Lighting, Shadows and PBR

Shadow Sampling
Incoming Light Descriptor

Light and Surface definition
PBR

Requires:
  lib/core
  lib/distort
  lib/space

Uniforms:
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform float nightVision;


Desired API

vec4 sceneColor = ...
vec3 sceneNormal = ...

BRDF brdf;
brdf.surfaceColor = ...
brdf.surfaceNormal = 
brdf.viewDirection

directBRDF(brdf)

debugblender(brdf.finalColor)

gl_FragData[0] = vec4(brdf.finalColor, luma(brdf.light.color));
*/

// TODO: Better Shadow mapping
/*
Overall better shadow technique for HQ performant shadows
- Sharper shadows
- Entity Shadow Distance
- LOD Shadows (Distant Horizons)
*/

// TODO: Move these to settings.glsl (included by core)

// SHADOW PARAMETERS
// #define SHADOW_SAMPLES 2
// const int ShadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
// const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

// Engine Parameters
const int shadowMapResolution = 2048;
const int noiseTextureResolution = 128;

uniform sampler2D shadowtex0;   // shadow attenuation
uniform sampler2D shadowtex1;   // shadow (no transparents)
uniform sampler2D shadowcolor0; // shadow colors

const float sunPathRotation = -9.0; // TODO: Settings

struct Shadow {
    vec3 color;
    float brightness;        // How bright is the sun
    float solidAttenuation;  // Transparents are solid
    float clipAttenuation;   // Transparents are cut out
};

vec3 shadowColor(Shadow shadow) {
    return shadow.color * (shadow.clipAttenuation - shadow.solidAttenuation);
}

float visibility(vec4 shadowSample, float coordDepth) {
    return step(coordDepth - 0.001f, shadowSample.r);
}

Shadow incomingShadow(vec4 posRWS) {
    vec4 shadowLightPositionRWS = gbufferModelViewInverse
        * vec4(shadowLightPosition, 1);

    // vec4 posSRWS = (posRWS + vec4(cameraPosition, 0)) - shadowLightPositionRWS;
    vec4 posAbsWS = posRWS + vec4(cameraPosition, 0);
    posAbsWS += 0.0001;

    // debug(voxelPerfect(posAbsWS, 4).rgb);
    // debug(shadowLightPositionRWS.rgb);
    // Shadowlight relative world position
    vec4 posSRWS = voxelPerfect(posAbsWS, 16) - voxelPerfect(shadowLightPositionRWS, 16);
    // posSRWS = voxelPerfect(posSRWS, 16); // Pixel Perfect
    

    // Back to camera relative (Voxel Relative World)
    vec4 posVRWS = (posSRWS + shadowLightPositionRWS) - vec4(cameraPosition, 0);

    vec4 posSVS = shadowModelView * posVRWS;

    vec4 posSS = shadowProjection * posSVS;
    
    posSS.xy = distortPosition(posSS.xy);
    vec3 coords = posSS.xyz * 0.5f + 0.5f;
    
    Shadow shadow;
    
    vec4 col = texture2D(shadowcolor0, coords.xy);

    shadow.color            = col.rgb;
    shadow.brightness       = col.a;
    shadow.solidAttenuation = visibility(texture2D(shadowtex0, coords.xy), coords.z);
    shadow.clipAttenuation  = visibility(texture2D(shadowtex1, coords.xy), coords.z);

    // debug(shadow.brightness);

    return shadow;
}

// 
//  SURFACE DESCRIPTOR
// 

struct Surface {
    vec3 color;
    float alpha;

    vec3 normal;
    float metallic;
    
    vec3 viewDirection; // inversed View-Space position of Surface
    float smoothness;
};

Surface newSurface(
    vec4 sceneColor,    // Raw sampled color from the Scene
    vec4 sceneNormal,   // Uncompressed normals
    vec4 sceneDetail,   // Raw sampled 'specular' from the Scene
    vec3 viewPosition   // View-Space position of Surface
) {
    Surface surface;

    surface.color = tolinear(sceneColor.rgb);
    surface.alpha = sceneColor.a;
    surface.normal = normalize(sceneNormal.rgb * 2.0f - 1.0f); // TODO: Normal Compression

    surface.smoothness = sceneDetail.r;
    surface.metallic = sceneDetail.g;
    // TODO: Subsurface/Porosity/
    // TODO: Emmision
    
    surface.viewDirection = -viewPosition;

    return surface;
}

// 
//  LIGHT DESCRIPTOR
//

const float LightK = 3;
const vec3 AmbientLight = vec3(.001);

const vec3 SunColor = vec3(1.0, 0.9608, 0.8353);
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
    vec3 direction;     // Surface -> Light Source in View Space
    float directional;
};

// Compute the light that hits a surface
/*
    TODO: Rewrite an entire separate function for Translucents
    This is related to subsurface calculations as well
    It may require a separate BRDF entirely

    TODO: Rewrite the lighting model
        Join together:
            shadow.glsl
            surface.glsl
            light.glsl
            brdf.glsl
        Into a single file `lighting.glsl`

*/
Light surfaceLight(Surface surface, vec2 sceneLight, Shadow shadow)
{
    /* Day/Night in Ticks
       0 to 13k is day
       13k to 23k is night */
    float time = float(worldTime);

    const float TK = 1000.0;

    float day = smoothmask(time, 0, 12250, 750);
    float night = 1 - day;

    float translucent = smoothstep(1, .95, surface.alpha);

    /* skylight
    11500: Starts to diminish
    12500: Reduced to 55%, Dusk Colored Begins
    13000: Official Night Time, Dusk Color is Max
    13500: Dusk Color is Halved
    14000: No Light
    */
    vec4 skylight; {
        float light = pow(sceneLight.y, 2.5);

        skylight.a = light;

        // TODO: This affects sunlight
        float dusk; {
            float start = smoothstep(12200, 12900, time);
            float end   = smoothstep(13500, 13000, time);
            dusk = min(start, end);
        }

        vec3 daycolor = lighten(skyColor, .2);

        // debug(daycolor);
        vec3 color = mix(daycolor, vec3(0.1725, 0.1255, 0.1961), night);

        skylight.rgb = color;
    }
    
    /* blocklight:
    */
    vec4 blocklight; {
        blocklight.a = pow(sceneLight.x, 3.2);
        blocklight.rgb = blocklightColor(0);
    }

    /* sunlight:

    At tick 12789: shadows start coming from the moon
        Can this time be changed ??

    */
    vec4 sunlight; float sunlightDirect; {
        // Directional Dot Product
        float dotl = dot(surface.normal, normalize(shadowLightPosition) + vec3(1e-4));
        
        // Is light directly hitting this surface
        float direct = max(dotl, 0); //mix(1, max(dotl, 0), surface.alpha);
        // Translucent surfaces have the light pass through
        // direct += max(-dotl, 0) * (1 - surface.alpha);
        
        float solidOclussion = shadow.clipAttenuation * shadow.brightness;
        // Is this surface ocluded by shadows
        float oclussion = mix(shadow.clipAttenuation, solidOclussion * max(dotl, 0), surface.alpha > .95);

        // Is this surface covered by shadows
        float attenuation = mix(oclussion * surface.alpha, oclussion * pow(direct, .25), surface.alpha);
        
        // What color to use. 1 when shadow transmits it's color, 0 when the sun color is used
        float solidColorMask = mix(
            (shadow.clipAttenuation - shadow.solidAttenuation),
            smoothstep(-.1, .1, -dotl),
            // surface.alpha < 1
            translucent
            );
        /* This uglyness used to (Incorrectly) blend 2 different masks to blend colors between translucents and opaques.
        This is incorrect because the mask is only capable of blending between the Sun color and the shadow color, where self-shadowed translucents should use their own surface color as the correct shadow color.
        I kept it because due to an error in mimapping, which results in far-off alpha cutout objects keeping the color of their shadows.
        This simply looks nicer, it seems to result in AO for a-clipped terrain */
        
        // Color of Shadows
        // vec3 transmittedColor = mix(surface.color, shadow.color, surface.alpha > .95);
        vec3 transmittedColor = resaturate(shadow.color, 0.8); // Aesthetic Saturation

        vec3 solidLight = mix(SunColor, transmittedColor, solidColorMask);

        // Color of self shadowed translucent surfaces
        vec3 translucentColor = mix(
            mix(SunColor, surface.color, surface.alpha),
            SunColor * smoothstep(0, .6, surface.alpha),
        direct * 0.6 + 0.1);

        vec3 shadedColor = mix(solidLight, translucentColor, translucent);

        sunlight.rgb = shadedColor;
        sunlight.a = attenuation;
        sunlightDirect = direct;
    }

    // Apply night-time
    vec4 skylight2; vec4 sunlight2; {
        // TODO: Moon phases (.04 to .01)
        float skymul = .2;
        float moonmul = .05; // TODO: Brighten shadows
        skylight2 = mix(skylight, skylight * skymul, night);
        sunlight2 = mix(sunlight, sunlight * moonmul, night);
    }

    vec3 environment; {
        float mask = square(skylight.a) * .7;
        mask = clamp01(mask);
        
        float alpha = mix(skylight2.a, sunlight2.a, mask);

        // TODO: new mask method
        
        environment = oklab_mix(skylight2.rgb * skylight2.a, sunlight2.rgb * sunlight2.a, alpha);
        // Apply Night Vision
        const vec3 NightVisionColor = vec3(0.5, 0.5, 0.64);
        float nvmask = nightVision;
        nvmask -= mix(skylight2.a, sunlight2.a, alpha) * 2;
        nvmask = clamp01(nvmask);
        environment = oklab_mix(
            environment, NightVisionColor, nvmask);
    }
    
    vec4 blockblend; {
        float blendmask = skylight.a;
        blockblend = mix(
            blocklight * 1.6,
            psmin(blocklight, blocklight * .5 + .75, .5),
        blendmask);
    } 
    
    Light light;

    light.color = (environment + blockblend.rgb * blockblend.a) * 1.5;
    light.direction = normalize(shadowLightPosition);
    light.directional = pow(sunlight.a, 1.0 / 2.0);
    
    // Prevent specular highlights in the underside of translucents
    light.directional = mix(light.directional, sunlightDirect, translucent);
    
    // debug(environment.rgb);

    return light;
}


//
//  BRDF
//

float specularStrenght(Surface surface, Light light) {   
    float roughness; {
        float perceptualRoughness = 1 - surface.smoothness;
        roughness = square(perceptualRoughness);
    }
    
    vec3 h = snormalize(light.direction + normalize(surface.viewDirection));
	float nh2 = square(clamp01(dot(surface.normal, h)));

	float lh2 = square(clamp01(dot(light.direction, h)));
	float r2 = square(roughness);
	float d2 = square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = roughness * 4.0 + 2.0;

	float specular =  r2 / (d2 * max(0.1, lh2) * normalization);

    // debug(roughness);

    return specular;
}

/*
Given surface geometry, and incoming light.
Calculate output light value

*/
vec3 directBRDF(Surface surface, Light light) {
    
    // Light that enters the material
    vec3 incomingLight = surface.color * light.color;

    // Divide the light into diffused, and reflected
    vec3 diffuse; vec3 specular;
    {
        vec3 minReflect = vec3(0.001) * light.color;

        // LBR: Total light color is doubled, metals keep 50% of their color, and nonmetals reflect 50%
        diffuse = mix(minReflect, incomingLight, 1 - surface.metallic * .5);
        specular = mix(minReflect, incomingLight, surface.metallic);
    }

    float SS = specularStrenght(surface, light);

    // DirectBRDF
    vec3 direct = diffuse;
    direct += specular * SS * light.directional;

    // debug(mix(direct, light.direction, .5));
    // #ifdef DEBUG_LIB
    // debug(mix(direct, light.direction, .5));
    // #endif
    return direct;
}

vec3 simplifiedBRDF(Surface surface, Light light) {
    vec3 incomingLight = surface.color * light.color;

    return incomingLight;
}

/*

*/
struct SolidSurface {
    vec3 albedo;
    vec3 normal;
    float metallic;
    vec3 viewPosition;  // View-Space Position
    vec3 worldPosition; // Relative World Position
    float smoothness;
    vec2 light;         // Normalized light level values
};

Light solidSurfaceLight(SolidSurface surf) {
    Shadow shadow = incomingShadow(vec4(surf.worldPosition, 1));

    /* Day/Night in Ticks
       0 to 13k is day
       13k to 23k is night */
    float time = float(worldTime);
    /*  11500: Starts to diminish
        12500: Reduced to 55%, Dusk Colored Begins
        13000: Official Night Time, Dusk Color is Max
        13500: Dusk Color is Halved
        14000: No Light */
    
    const float TK = 1000.0;

    float day = smoothmask(time, 0, 12250, 750);
    float night = 1 - day;
    
    /* skylight:
    */
    vec4 skylight; {
        float light = pow(surf.light.y, 2.5);

        skylight.a = light;

        // TODO: This affects sunlight
        float dusk; {
            float start = smoothstep(12200, 12900, time);
            float end   = smoothstep(13500, 13000, time);
            dusk = min(start, end);
        }

        vec3 daycolor = lighten(skyColor, .2);

        // debug(daycolor);
        vec3 color = mix(daycolor, vec3(0.1725, 0.1255, 0.1961), night);

        skylight.rgb = color;
    }

    /* blocklight:
    */
    vec4 blocklight; {
        blocklight.a = pow(surf.light.x, 3.2);
        blocklight.rgb = blocklightColor(0);
    }

    /* sunlight:
    At tick 12789: shadows start coming from the moon
    */
    vec4 sunlight; float sunlightDirect; {
        // Directional Dot Product
        float dotl = dot(surf.normal, normalize(shadowLightPosition) + vec3(1e-4));
        
        // Is light directly hitting this surface
        float direct = max(dotl, 0);
        float solidOclussion = shadow.clipAttenuation * shadow.brightness;
        // Is this surface ocluded by shadows
        float oclussion = solidOclussion * direct;

        // Is this surface covered by shadows
        float attenuation = oclussion * pow(direct, .25);
        
        // What color to use. 1 when shadow transmits it's color, 0 when the sun color is used
        float solidColorMask = (shadow.clipAttenuation - shadow.solidAttenuation);
        
        // Color of Shadows
        vec3 transmittedColor = resaturate(shadow.color, 0.8); // Aesthetic Saturation

        vec3 shadedColor = mix(SunColor, transmittedColor, solidColorMask);

        sunlight.rgb = shadedColor;
        sunlight.a = attenuation;
        sunlightDirect = direct;
    }

    
    // Apply night-time
    vec4 skylight2; vec4 sunlight2; {
        // TODO: Moon phases (.04 to .01)
        float skymul = .2;
        float moonmul = .05; // TODO: Brighten shadows
        skylight2 = mix(skylight, skylight * skymul, night);
        sunlight2 = mix(sunlight, sunlight * moonmul, night);
    }

    vec3 environment; {
        float mask = square(skylight.a) * .7;
        mask = clamp01(mask);
        
        float alpha = mix(skylight2.a, sunlight2.a, mask);

        // TODO: new mask method
        
        environment = oklab_mix(skylight2.rgb * skylight2.a, sunlight2.rgb * sunlight2.a, alpha);
        // Apply Night Vision
        const vec3 NightVisionColor = vec3(0.5, 0.5, 0.64);
        float nvmask = nightVision;
        nvmask -= mix(skylight2.a, sunlight2.a, alpha) * 2;
        nvmask = clamp01(nvmask);
        environment = oklab_mix(
            environment, NightVisionColor, nvmask);
    }
    
    vec4 blockblend; {
        float blendmask = skylight.a;
        blockblend = mix(
            blocklight * 1.6,
            psmin(blocklight, blocklight * .5 + .75, .5),
        blendmask);
    } 
    
    Light light;

    light.color = (environment + blockblend.rgb * blockblend.a) * 1.5;
    light.direction = normalize(shadowLightPosition);
    light.directional = pow(sunlight.a, 1.0 / 2.0);
    
    // debug(shadow.solidAttenuation);

    return light;
}

float specularStrenght(SolidSurface surf, vec3 lightDirection) {   
    float roughness; {
        float perceptualRoughness = 1 - surf.smoothness;
        roughness = square(perceptualRoughness);
    }

    vec3 h = snormalize(lightDirection - normalize(surf.viewPosition));
	float nh2 = square(clamp01(dot(surf.normal, h)));

	float lh2 = square(clamp01(dot(lightDirection, h)));
	float r2 = square(roughness);
	float d2 = square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = roughness * 4.0 + 2.0;

	float specular =  r2 / (d2 * max(0.1, lh2) * normalization);

    // debug(roughness);

    return specular;
}

vec3 solidBRDF(SolidSurface surf) {
    // Compute the light that hits the solid
    Light light = solidSurfaceLight(surf);

    vec3 incomingLight = surf.albedo * light.color;
    vec3 diffuse; vec3 specular; {
        vec3 minReflect = vec3(0.001) * light.color;

        // LBR: Total light color is doubled, metals keep 50% of their color
        diffuse = mix(minReflect, incomingLight, 1 - surf.metallic * .5);
        specular = mix(minReflect, incomingLight, surf.metallic);
    }
    
    float SS = specularStrenght(surf, light.direction);

    // DirectBRDF
    vec3 direct = diffuse;
    direct += specular * SS * light.directional;


    return direct;
}

struct TranslucentSurface {
    vec3 albedo;
    float alpha;
    vec3 normal;
    float metallic;
    vec3 viewPosition;  // View-Space Position
    vec3 worldPosition; // Relative World Position
    float smoothness;
    vec2 light;         // Normalized light level values
};

Light translucentSurfaceLight(TranslucentSurface surf) {
    Shadow shadow = incomingShadow(vec4(surf.worldPosition, 1));
    /* Day/Night in Ticks
       0 to 13k is day
       13k to 23k is night */
    float time = float(worldTime);

    const float TK = 1000.0;

    float day = smoothmask(time, 0, 12250, 750);
    float night = 1 - day;

    // Sky Light
    vec4 skylight; {
        float light = pow(surf.light.y, 2.5);

        skylight.a = light;

        // TODO: This affects sunlight
        float dusk; {
            float start = smoothstep(12200, 12900, time);
            float end   = smoothstep(13500, 13000, time);
            dusk = min(start, end);
        }

        vec3 daycolor = lighten(skyColor, .2);

        // debug(daycolor);
        vec3 color = mix(daycolor, vec3(0.1725, 0.1255, 0.1961), night);

        skylight.rgb = color;
    }
    
    // Block Light
    vec4 blocklight; {
        blocklight.a = pow(surf.light.x, 3.2);
        blocklight.rgb = blocklightColor(0);
    }

    vec4 sunlight; float sunlightDirect; {
        // Directional Dot Product
        float dotl = dot(surf.normal, normalize(shadowLightPosition) + vec3(1e-4));
        
        // Is light directly hitting this surface
        float direct = max(dotl, 0); //mix(1, max(dotl, 0), surface.alpha);
        // Translucent surfaces have the light pass through
        // direct += max(-dotl, 0) * (1 - surface.alpha);
        
        float solidOclussion = shadow.clipAttenuation * shadow.brightness;
        // Is this surface ocluded by shadows
        float oclussion = shadow.clipAttenuation;

        // Is this surface covered by shadows
        float attenuation = oclussion * surf.alpha;
        
        // What color to use. 1 when shadow transmits it's color, 0 when the sun color is used
        float solidColorMask = smoothstep(-.1, .1, -dotl);
        
        // Color of Shadows
        vec3 transmittedColor = resaturate(shadow.color, 0.8); // Aesthetic Saturation

        vec3 solidLight = mix(SunColor, transmittedColor, solidColorMask);

        // Color of self shadowed translucent surfaces
        vec3 shadedColor = mix(
            mix(SunColor, surf.albedo, surf.alpha),
            SunColor * smoothstep(0, .6, surf.alpha),
        direct * 0.6 + 0.1);

        sunlight.rgb = shadedColor;
        sunlight.a = attenuation;
        sunlightDirect = direct;
    }

    // Apply night-time
    vec4 skylight2; vec4 sunlight2; {
        // TODO: Moon phases (.04 to .01)
        float skymul = .2;
        float moonmul = .05; // TODO: Brighten shadows
        skylight2 = mix(skylight, skylight * skymul, night);
        sunlight2 = mix(sunlight, sunlight * moonmul, night);
    }

    vec3 environment; {
        float mask = square(skylight.a) * .7;
        mask = clamp01(mask);
        
        float alpha = mix(skylight2.a, sunlight2.a, mask);

        // TODO: new mask method
        
        environment = oklab_mix(skylight2.rgb * skylight2.a, sunlight2.rgb * sunlight2.a, alpha);
        // Apply Night Vision
        const vec3 NightVisionColor = vec3(0.5, 0.5, 0.64);
        float nvmask = nightVision;
        nvmask -= mix(skylight2.a, sunlight2.a, alpha) * 2;
        nvmask = clamp01(nvmask);
        environment = oklab_mix(
            environment, NightVisionColor, nvmask);
    }
    
    vec4 blockblend; {
        float blendmask = skylight.a;
        blockblend = mix(
            blocklight * 1.6,
            psmin(blocklight, blocklight * .5 + .75, .5),
        blendmask);
    } 
    
    Light light;

    light.color = (environment + blockblend.rgb * blockblend.a) * 1.5;
    light.direction = normalize(shadowLightPosition);
    light.directional = pow(sunlight.a, 1.0 / 2.0);
    
    return light;
}

float specularStrenght(TranslucentSurface surf, vec3 lightDirection) {   
    float roughness; {
        float perceptualRoughness = 1 - surf.smoothness;
        roughness = square(perceptualRoughness);
    }

    vec3 h = snormalize(lightDirection - normalize(surf.viewPosition));
	float nh2 = square(clamp01(dot(surf.normal, h)));

	float lh2 = square(clamp01(dot(lightDirection, h)));
	float r2 = square(roughness);
	float d2 = square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = roughness * 4.0 + 2.0;

	float specular =  r2 / (d2 * max(0.1, lh2) * normalization);

    // debug(roughness);

    return specular;
}

vec3 translucentBRDF(TranslucentSurface surf) {
    Light light = translucentSurfaceLight(surf);

    vec3 incomingLight = surf.albedo * light.color;
    vec3 diffuse; vec3 specular; {
        vec3 minReflect = vec3(0.001) * light.color;

        // LBR: Total light color is doubled, metals keep 50% of their color
        diffuse = mix(minReflect, incomingLight, 1 - surf.metallic * .5);
        specular = mix(minReflect, incomingLight, surf.metallic);
    }

    float SS = specularStrenght(surf, light.direction);

    // DirectBRDF
    vec3 direct = diffuse;
    direct += specular * SS * light.directional;

    return direct;
}

// TODO: Normal Compression
// TODO: Subsurface/Porosity/
// TODO: Emmision

// TODO: Translucent BRDF

// TODO: WRDF (Water Reflectance Distribution Function)


/*

Incoming Light Descriptor

Used:
  program/deferred
  gbuffer/translucent

Uniforms:
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

Required:
  lib/core
    lib/space
    lib/distort
  lib/shadow
  lib/surface

*/


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

Light incomingLight(Surface surface, vec2 sceneLight, Shadow shadow)
{
    float blocklight = sceneLight.x;
    float skylight = sceneLight.y;
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
    
    // TODO: Use Shadowlight Position
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

Light surfaceLight(Surface surface, vec2 sceneLight, Shadow shadow)
{
    /* Day/Night in Ticks
       0 to 13k is day
       13k to 23k is night */
    float time = float(worldTime);

    const float TK = 1000.0;

    float day = smoothmask(time, 0, 12250, 750);
    float night = 1 - day;

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

        vec3 color = mix(skyColor, SkyColorNight, night);

        skylight.rgb = color * light;
    }
    
    /* blocklight:
    */
    vec4 blocklight; {
        blocklight.a = pow(sceneLight.x, 3.2);
        blocklight.rgb = blocklightColor(0) * blocklight.a * 1.2;
    }

    /* sunlight:

    At tick 12789: shadows start coming from the moon
        Can this time be changed ??

    */
    vec4 sunlight; {
        // Directional Dot Product
        float dotl = dot(surface.normal, normalize(shadowLightPosition) + vec3(1e-4));
        
        // Is light directly hitting this surface
        float direct = mix(1, max(dotl, 0), surface.alpha);
        // Translucent surfaces have the light pass through
        // direct += max(-dotl, 0) * (1 - surface.alpha);
        
        float solidOclussion = shadow.clipAttenuation * shadow.brightness;
        // Is this surface ocluded by shadows
        float oclussion = mix(shadow.clipAttenuation, solidOclussion, surface.alpha > .95)
            * max(dotl, 0);

        // Is this surface covered by shadows
        float attenuation = oclussion * direct;
        // attenuation = mix(attenuation, attenuation, 1);

        // 1 when shadow color is transmitted
        float solidMask = (shadow.clipAttenuation - shadow.solidAttenuation);
        // 1 when tra
        // float translucentMask = mix(surface.alpha, 0, direct);
        float translucentMask = smoothstep(-.1, .1, -dotl);

        // What color to use. 1 when shadow transmits it's color
        float colormask = mix(
            solidMask,
            translucentMask,
            // surface.alpha < 1
            smoothstep(1, .95, surface.alpha)
            );
        
        // Color 
        vec3 transmittedColor = mix(surface.color, shadow.color, surface.alpha > .95);

        transmittedColor = resaturate(transmittedColor, 1.5);

        vec3 light = mix(SunColor, transmittedColor, colormask);
        
        sunlight.rgb = light * attenuation;
        sunlight.a = attenuation;
    }

    vec4 environment; {
        float mask = square(skylight.a) * .7;
        mask = clamp01(mask);
        
        vec4 skyedit; vec4 sunedit; {
            // TODO: Moon phases
            float skymul = .2;
            float moonmul = .05;
            skyedit = mix(skylight, skylight * skymul, night);
            sunedit = mix(sunlight, sunlight * moonmul, night);
        }

        environment = mix(skyedit, sunedit, mask);

        // debug(mask);
    }
    
    
    vec3 outDoor; {
        outDoor += environment.rgb;
        // outDoor += sunlight.rgb;

        outDoor += blocklight.rgb;
    }
    
    vec3 innDoor; {

    }

    // debugldr(luma(sunlight.rgb));

    Light light;

    light.color = outDoor;
    light.direction = vec3(0, 0, 0);
    light.directional = 0;
    
    return light;
}

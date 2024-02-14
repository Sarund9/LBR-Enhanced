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
        float attenuation = oclussion * pow(direct, .25);
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
    // debug(sunlight.rgb);

    // Apply night-time
    vec4 skylight2; vec4 sunlight2; {
        // TODO: Moon phases
        float skymul = .2;
        float moonmul = .05;
        skylight2 = mix(skylight, skylight * skymul, night);
        sunlight2 = mix(sunlight, sunlight * moonmul, night);
    }

    vec4 environment; {
        float mask = square(skylight.a) * .7;
        mask = clamp01(mask);
        
        environment = mix(skylight2, sunlight2, mask);
    }
    
    vec4 blockblend; {
        float blendmask = skylight.a;
        blockblend = mix(
            blocklight * 1.6,
            psmin(blocklight, blocklight * .5 + .75, .5),
        blendmask);
    } 
    
    Light light;

    light.color = (environment.rgb + blockblend.rgb) * 1.5;
    light.direction = normalize(shadowLightPosition);
    light.directional = pow(sunlight.a, 1.0 / 2.0);
    
    return light;
}

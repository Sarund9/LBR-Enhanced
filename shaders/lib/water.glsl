/*

Water Effects and Shaders

Requires:
// lib/space
// lib/surface
lib/noise

Uniforms:
uniform float frameTimeCounter;

*/

// TODO: Compute a water object instead of a Surface
// TODO: Send pure light values instead of the scene color


vec3 watercolor(vec3 current, float simplex, float texture) {
    const vec3 BaseWaterColor = vec3(0.007, 0.012, 0.08);
    // WATER: Bedrock Waters contrast Reduction
    /* Bedrock Waters mod changes water colors across biomes
    But the effect can be jarring with a more detailed water shader
    This brings the color back 50% to a vanilla-ish color */
    // debug(BaseWaterColor);
    vec3 hue = mix(current, BaseWaterColor, mix(.5, .7, simplex));

    hue *= mix(texture, .1, 1 - simplex);

    return hue;
}

// struct Water {
//     float value;
//     vec3 surfaceNormal;
// };

vec4 waternoise(vec3 surfacePositionWS) {
    vec4 simplex;

    vec3 p;
    p.xz = surfacePositionWS.xz * 0.8;
    p.y = frameTimeCounter * 2;

    p.xz = (floor(p.xz * 16.0) / 16.0) + 0.5;
    p.y = floor(p.y * 12.0) / 12.0;
    simplex.w = fractalnoise(p);
    const vec2 e = vec2(1 / 16.0, 0);
    /* Tangent points toward positive X
        Binormal points toward positive Y */
    simplex.xyz = vec3(0, 0, 1);

    const float WaterNormalMult = 2;

    simplex.x += (simplex.w - fractalnoise(p - e.xyy)) * WaterNormalMult;
    simplex.y += (simplex.w - fractalnoise(p - e.yyx)) * WaterNormalMult;

    simplex.xyz = normalize(simplex.xyz);
    
    return simplex;
}

vec2 waterfract(vec4 noise, vec2 viewUV) {

    float lines = smoothstep(.8, 1, noise.a);

    return viewUV;
}

const float WaterDiffusionDistance = 20.0;

/* Computes the ammount of light color lost as it travels water
*/
float waterfog(float sceneDistance, float surfaceDistance) {
    // Water Opacity
    const float FarDiffusionStart = 12.0;
    const float FarDiffusionEnd = 46.0;


    float diffusionDistance = (sceneDistance - surfaceDistance);
    float diffusionFactor = smoothstep(0, WaterDiffusionDistance, diffusionDistance);
    
    // TODO: Base the distance diffusion on horizontal distance
    // TODO: Diffusion based on entry angle to water

    return mix(0.1, 1, diffusionFactor);
}

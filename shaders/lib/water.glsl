/*

Water Effects and Shaders

Requires:
lib/color
lib/noise
lib/lighting

Uniforms:
uniform float frameTimeCounter;
uniform ivec2 atlasSize;

*/

// TODO: Compute a water object instead of a Surface
// TODO: Send pure light values instead of the scene color

const vec3 BaseWaterColor = vec3(32.1 / 255.0, 60.7 / 255.0, 180.3 / 255.0);

vec3 watercolor(vec3 current, float simplex, float texture) {
    // WATER: Bedrock Waters contrast Reduction
    /* Bedrock Waters mod changes water colors across biomes
    But the effect can be jarring with a more detailed water shader
    This brings the color back 50% to a vanilla-ish color */
    // debug(BaseWaterColor);
    vec3 hue = mix(current, BaseWaterColor, mix(.5, .7, simplex));

    hue *= mix(texture, .3, 1 - simplex);
    // hue *= texture - simplex * .05;
    // debug(texture);

    return hue;
}

// struct Water {
//     float value;
//     vec3 surfaceNormal;
// };

vec4 waternoise(vec3 surfacePositionWS) {
    vec4 simplex;

    // Makes distant normals less intense
    float dist = length(surfacePositionWS - cameraPosition);
    float mask = smoothstep(0, 40, dist);
    mask = mix(1, .2, mask);
    mask = clamp01(mask);

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

    simplex.x += (simplex.w - fractalnoise(p - e.xyy)) * WaterNormalMult * mask;
    simplex.y += (simplex.w - fractalnoise(p - e.yyx)) * WaterNormalMult * mask;

    simplex.xyz = normalize(simplex.xyz);
    simplex.w *= mask;

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

struct Water {
    vec3 color;          // Surface Color
    vec3 normal;         // Surface Normal
    vec3 rawNormal;

    vec3 viewPosition;   // View-Space Position
    vec3 worldPosition;  // Relative World Position
    vec3 screenPosition; // ScreenUV .. Depth


    vec3 depthWorldPosition;

    vec2 light;
};

const vec3 WaterFoamRanges = vec3(3.5, 4.0, 100.0);
const vec3 WaterShoreColor = vec3(1);


float waterFresnel(vec3 normal, vec3 viewDir) {
    // Constant related to the Index of Refraction (IOR)
    float R0 = 0.3;
    // Increase value to weaken reflections
    float refractionStrength = 0.5;

    /* Simplified:
    return R0 + (1.0f - R0) * pow(1.0f - dot(viewDir, normal), 5.0f);
    */

    float angle = 1 - clamp01(dot(normal, viewDir));
    float fresnel = square(square(angle)) * angle;


    return clamp01(fresnel * (1 - clamp01(R0)) + R0 - refractionStrength);
}

vec3 waterRadiance(Light light, vec3 viewDir, vec3 normal, float fresnel) {
    float shininess = 0.5;  // 0 to 3
    // specular values: 12 768 0.15
    float shininessExp = 0.15;

    float SpecularX = 12;

    // Blinn Phong
    float specularIntensity = SpecularX * 0.0075;

    vec3 H = normalize(viewDir + light.direction);
    float e = shininess * shininessExp * 800;
    float kS = clamp01(dot(normal, light.direction));
    float specularFactor = kS * specularIntensity * pow(clamp01(dot(normal, H)), e)
        * sqrt((e + 1) / 2.0);
    // specular *= light.color;
    
    return specularFactor * light.color;
}

vec3 waterRefraction(
    float waterDepth, float viewWaterDepth,
    vec3 refractionColor, vec3 watercolor)
{
    float waterClarity = 0.75;  // 0 to 3
    float visibility = 10;      // 0 to 30
    float shoreRange = max(WaterFoamRanges.x, WaterFoamRanges.y) * 2.0;
    vec3 horizontalExtinction = vec3(3.0, 10.0, 12.0);

    vec3 waterDepthColor = watercolor;

    float accDepth = viewWaterDepth * waterClarity;
    float accDepthExp = clamp01(accDepth / (visibility * 2.5));
    accDepthExp *= (1 - accDepthExp) * accDepthExp * accDepthExp + 1;

    vec3 surfaceColor = mix(WaterShoreColor, waterDepthColor, clamp01(waterDepth / shoreRange));
    vec3 waterColor = mix(surfaceColor, waterDepthColor, clamp01(waterDepth / horizontalExtinction));

    vec3 color = refractionColor;
    color = mix(color, surfaceColor * waterColor, clamp01(accDepth / visibility));
    color = mix(color, waterDepthColor, accDepthExp);
    color = mix(color, waterDepthColor * waterColor, clamp01(waterDepth / horizontalExtinction));

    return color;
}

vec3 waterBRDF(Water water, vec4 sceneSample) {

    vec3 viewDir = -normalize(water.viewPosition);
    vec2 viewUV = water.screenPosition.xy;
    // TODO: DOESN'T WORK FROM THE SIDE

    Light light; {
        TranslucentSurface ts;
        ts.albedo = water.color;
        ts.normal = water.normal;
        ts.worldPosition = water.worldPosition;
        ts.alpha = 0.5;
        ts.light = water.light;
        ts.viewPosition = water.viewPosition;
        light = translucentSurfaceLight(ts);
    }
    
    float fresnel = waterFresnel(water.normal, viewDir);
    vec3 specular = waterRadiance(light, viewDir, water.normal, fresnel);
    // debug(fresnel);
    {
        // float noisemask = float(dot(water.normal, viewDir) < .1);
        // debug(noisemask);
        // fresnel -= .1 * noisemask;
    }

    vec3 surfacePosition = water.worldPosition + cameraPosition;
    vec3 depthPosition = water.depthWorldPosition + cameraPosition;

    // TODO: do not use waterDepth, reduce it's effects

    float waterDepth = surfacePosition.y - depthPosition.y;
    float viewWaterDepth = length(surfacePosition - depthPosition);

    vec3 pureRefractionColor;
    {
        const float RefractionScale = 0.001;
        float timer = frameTimeCounter;

        vec2 uv = viewUV;
        float scale = RefractionScale * min(viewWaterDepth, 1.0);
        float Frecuency = 1.05;
        float noise = simplex3d_smooth(depthPosition);
        vec2 delta;
        delta = vec2(
            sin(timer + 3.0 * abs(depthPosition.y)),
			sin(timer + 5.0 * abs(depthPosition.y))
        );
        // delta += noise * .2;
        // delta = simplex3d_smooth(vec3(viewUV, 0));
        // delta.x = noise;
        // delta = water.rawNormal.xz;
        uv += delta * scale;

        pureRefractionColor = sceneSample.rgb;
        // debug(float(fract(uv.x * 90) < .5) * .4);
        // debug(delta);
    }

    // TODO: Refractions (Sampling the scene color)

    vec3 refractionColor = waterRefraction(waterDepth, viewWaterDepth, pureRefractionColor, water.color) * light.color;

    // debug(pureRefractionColor);

    // debug(refractionColor);
    // TODO: Reflections

    vec3 watercolor = lighten(resaturate(water.color, 1), 10);
    vec3 reflectedColor = lighten(resaturate(water.color, 0.5), 5) * light.color;
    
    float foam = smoothstep(.5, 0, viewWaterDepth);

    const float ShoreFade = 1.5; // 0.1 to 3.0
    float shoreFade = clamp01(waterDepth * ShoreFade);

    const float DiffuseDensity = 0.001;  // 0 to 1
    const float AmbientDensity = 0.005; // 0 to 1
    float diffuse = clamp01(dot(water.normal, light.direction)) * DiffuseDensity;
    vec3 ambientDiffuse = diffuse + vec3(0.05, 0.1, 0.2) * AmbientDensity;

    vec3 depthRefractionColor = mix(pureRefractionColor, reflectedColor, fresnel * clamp01(waterDepth / WaterFoamRanges.x * 0.4));
    depthRefractionColor = mix(depthRefractionColor, WaterShoreColor, 0.1 * shoreFade);
    
    vec3 color = mix(refractionColor, reflectedColor, max(specular, fresnel));
    color = clamp01(color);

    
    color = mix(refractionColor + specular * shoreFade, color, shoreFade);
    // TODO: Make this pureRefractionColor brighter so it's not so transparent
    // debug(shoreFade);


    return color;
}



float cubeDistance(vec3 point, vec3 dir) {

    float xda = float(dir.x >= 0) + (point.x * -sign(dir.x));
    float xa = 90.0 * (1 - abs(dot(dir, vec3(1, 0, 0))));
    float xd = xda / cos(xa);

    float yda = float(dir.y >= 0) + (point.y * -sign(dir.y));
    float ya = 90.0 * (1 - abs(dot(dir, vec3(0, 1, 0))));
    float yd = yda / cos(ya);



    return min(xd, ya);
}

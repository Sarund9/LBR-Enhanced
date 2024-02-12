/*

Bidirectional Reflectance Distribution Function

Used:
  program/deferred
  gbuffer/translucent

Requires:
  lib/core
    lib/space
    lib/distort
  lib/shadow
  lib/surface
  lib/light

Uniforms:

*/



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

    // 
    float highlight = pow(
        (factor + Threshold - 1) / Threshold,
        Power
    );

    // TODO: Move everything to True World Space
    float result = max(highlight, 0) * light.directional;
    // // Step Gradient
    // {
    //     float grad = 0;
    //     stepgrad(grad, result, .001);
    //     stepgrad(grad, result, .002);
    //     stepgrad(grad, result, .005);
    //     stepgrad(grad, result, .01);
    //     // result = grad;
    //     result = floor((result * 1.05) / .05) * .05;
    // }
    // debug(result);

    
    float roughness; {
        float perceptualRoughness = 1 - surface.smoothness;
        roughness = square(perceptualRoughness);
    }
    // TODO: Roughness

    return result;

    // vec3 h = normalize(-light.direction + surface.viewDirection);
	// float nh2 = square(clamp01(dot(surface.normal, h)));
	// float lh2 = square(clamp01(dot(light.direction, h)));
	// float r2 = square(roughness);
	// float d2 = square(nh2 * (r2 - 1.0) + 1.00001);
	// float normalization = roughness * 4.0 + 2.0;
	// return r2 / (d2 * max(0.1, lh2) * normalization);
}

/*
Given surface geometry, and incoming light.
Calculate output light value

*/
vec3 directBRDF(Surface surface, Light light) {
    
    // Light that enters the material
    vec3 incomingLight = surface.color * light.color;

    // The alpha affects the material
    incomingLight *= surface.alpha;

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

// TODO: Translucent BRDF
/*
Surface color:
- 

*/



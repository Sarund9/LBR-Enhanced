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

// TODO: Translucent BRDF
/*
Surface color:
- 

*/



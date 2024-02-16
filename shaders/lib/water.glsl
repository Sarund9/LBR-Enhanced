/*

Water Surface

Requires:
lib/space
lib/surface

Uniforms:
uniform vec3 upPosition;

*/

// TODO: Compute a water object instead of a Surface
// TODO: Send pure light values instead of the scene color

float waterFog(
    float trueDepth,
    float trueDistance
) {
    // Find the true distance to the scene pixel
    // float trueDepth = length(scenePositionRWS.xyz);
    // Find the distance to the water surface
    // float trueDistance = length(surfacePositionRWS);
    
    // Distance by which a ray of light must travel to get from the underwater surface to the Eye
    float diffusionDistance = trueDepth - trueDistance;
    
    // Adjust this value to create a mask
    const float DarkViewDistance = 20.0;
    const float LightViewDistance = 64.0;
    const float MinOpacity = 0.5;
    
    // TODO: Make incoming light from BRDF reduced by this
    // float viewDistance; {
    //     float hdrl = luma(sceneColor.rgb);
    //     float lightl = sceneColor.a;
    //     float lightmask = smoothstep(.5, 3.0, lightl);
    //     float factor = lightmask * pow(hdrl, 1.0 / 2.0);
    //     viewDistance = mix(DarkViewDistance, LightViewDistance, factor);
    //     // debug(factor);
    // }
    
    float distanceFactor = smoothstep(0, DarkViewDistance, diffusionDistance);
    
    float opacity = mix(MinOpacity, 1, pow(distanceFactor, 1.2));
    
    return opacity;
}

void computeWaterSurface(
    inout Surface surface,
    vec4 sceneColor,        // Raw HDR Color
    float sceneDepth,       // Raw scene depth behind water surface
    vec4 scenePositionRWS,  // Raw scene position in Relative World Space
    vec3 surfacePositionRWS // Raw surface position in Relative World Space
) {
    
    // Find the true distance to the scene pixel
    float trueDepth = length(scenePositionRWS.xyz);
    // Find the distance to the water surface
    float trueDistance = length(surfacePositionRWS);
    
    // Distance by which a ray of light must travel to get from the underwater surface to the Eye
    float diffusionDistance = trueDepth - trueDistance;
    
    // Adjust this value to create a mask
    const float DarkViewDistance = 20.0;
    const float LightViewDistance = 64.0;
    const float MinOpacity = 0.5;
    
    // TODO: Take into account the ammount of light in this fragment
    // This can be assumed to be the HDR channel value itself
    // This will become more noticeable with Emmision
    float viewDistance; {
        float hdrl = luma(sceneColor.rgb);
        float lightl = sceneColor.a;
        float lightmask = smoothstep(.5, 3.0, lightl);
        float factor = lightmask * pow(hdrl, 1.0 / 2.0);
        viewDistance = mix(DarkViewDistance, LightViewDistance, factor);
        // debug(factor);
    }
    
    float distanceFactor = smoothstep(0, viewDistance, diffusionDistance);
    
    float opacity = mix(MinOpacity, 1, pow(distanceFactor, 1.2));
    
    // TODO: Water surface plane from underneath
    // TODO: Defferred water (and water entity ID)
    /*
    Defferred water is preferable here:
    - This shader is for translucents, defferring water prevents overhead
    - Can better blend by writing some values to a buffer:
    - Water color (vanilla) is written to the default buffer
    DISTANCEBUFFER (Float):
    R: Distance to the nearest plane of Water
    
    TODO After:
    * Water Normals
    Vanilla water texture not used
    Rather, a normal map is used that results in a vanilla-like result
    This normal should be procedural and animated
    NOTE: Water does not have a normal texture by default
    * Waves
    * Water Edges
    
    
    Future: Volumetric Lights (under the water)
    */
    
    // TODO: Separate water vs translucent shaders
    
    surface.color=vec3(.1608,.0667,.7647);
    surface.alpha=opacity*.5;
    surface.normal=upPosition;
    surface.metallic=0;
    surface.smoothness=1;
    // surface.viewDirection =
}

// #define __WATER__

// struct Water {
//     float sceneDepth;
//     float surfaceDepth;

// };






struct Water {
    float d;
};

void computeWaterFog(float sceneDepth) {


    // Get the screen UV
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

    vec4 sceneColor = texture2D(colortex7, viewUV);
    float sceneDepth = texture2D(depthtex1, viewUV).r;

    // Find the true distance to the scene pixel
    vec4 scenePositionRWS = relativeWorldSpacePixel(viewUV, sceneDepth);
    float trueDepth = length(scenePositionRWS.xyz);
    // Find the distance to the 
    float trueDistance = length(posRWS);

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

    // finalColor = mix(sceneColor.rgb, albedo.rgb, albedo.a);
    finalColor = mix(sceneColor.rgb, color.rgb, opacity);
    finalColor *= albedo.rgb;

    finalColor = mix(finalColor.rgb, _debug_value.rgb, _debug_value.a);

    // gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    // gl_FragData[2] = vec4(lightUV, 0, 1);
    // gl_FragData[3] = vec4(0, 0, 0, 0); // R M T E
}




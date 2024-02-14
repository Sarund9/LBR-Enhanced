/*

Shared Shadow

Used:
  program/deferred
  program/shadowpass

Requires:
  lib/core
  lib/distort
  lib/space

Uniforms:
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
  
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

    // debug(shadow.brightness);

    return shadow;
}



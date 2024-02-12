

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec4 color;
varying vec3 posRWS;

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    texUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;

    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
}


#endif


#ifdef __PIXEL__

#include "/lib/core.glsl"
#include "/lib/water.glsl"

uniform sampler2D texture;
uniform sampler2D normals;

uniform sampler2D colortex7; // Scene Color
uniform sampler2D depthtex1; // Scene Depth, no transparents, no hand
// uniform sampler2D depthtex2;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

vec4 relativeWorldSpacePixel(vec2 texCoord, float depth) {
    vec3 clipSpace = vec3(texCoord, depth) * 2.0f - 1.0f;
    vec4 viewW = gbufferProjectionInverse * vec4(clipSpace, 1.0f);
    vec3 view = viewW.xyz / viewW.w;

    return gbufferModelViewInverse * vec4(view, 1.0f);
}

void main() {
    
    
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

    vec4 albedo = texture2D(texture, texUV) * color;
    
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

    vec3 finalColor;
    // finalColor = mix(sceneColor.rgb, albedo.rgb, albedo.a);
    finalColor = mix(sceneColor.rgb, color.rgb, opacity);
    finalColor *= albedo.rgb;

    finalColor = mix(finalColor.rgb, _debug_value.rgb, _debug_value.a);

    /* DRAWBUFFERS:7123 */
    gl_FragData[0] = vec4(finalColor, 1.0);
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(lightUV, 0, 1);
    gl_FragData[3] = vec4(0, 0, 0, 0); // R M T E
}

#endif

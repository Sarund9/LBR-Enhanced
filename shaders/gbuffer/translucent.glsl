
#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;

#include "/lib/normal.glsl"
#include "/lib/noise.glsl"

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;
varying vec3 vPositionCS;
varying float watermask;
varying vec3 vWaterSample;

void main() {
    gl_Position = ftransform();
    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vPositionCS = gl_Position.xyz;
    vec4 posVS = gbufferProjectionInverse * gl_Position;
    posRWS = (gbufferModelViewInverse * posVS).xyz;
    
    vec3 normal = gl_Normal;
    color = gl_Color;
    
    int BlockID = int(max(mc_Entity.x - BaseID, 0));
    watermask = BlockID == ID_Water ? 1 : 0;

    if (BlockID == ID_Water)
    {
        vec3 posWS = cameraPosition + posRWS;
        vWaterSample.xz = posWS.xz * 0.8;
        vWaterSample.y = frameTimeCounter * 2;
    }

    vertex_conormals(
        normal, at_tangent,
        gl_NormalMatrix,
        vNormal, vTangent, vBinormal
    );
}


#endif


#ifdef __PIXEL__

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferModelView;

// Space
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
// Shadow
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
// Water
uniform vec3 upPosition;
uniform float frameTimeCounter;
// Light
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;

#include "/lib/color.glsl"
#include "/lib/normal.glsl"
#include "/lib/noise.glsl"
#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/shadow.glsl"
#include "/lib/surface.glsl"
#include "/lib/water.glsl"
#include "/lib/light.glsl"
#include "/lib/brdf.glsl"

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D colortex7; // Scene Color
uniform sampler2D depthtex1; // Scene Depth behind this object

uniform int isEyeInWater;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 color;
varying vec3 posRWS;
varying float watermask;
varying vec3 vWaterSample;

void main() {
    vec2 viewUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float sceneDepth = texture2D(depthtex1, viewUV).r;

    vec3 posVS = viewSpacePixel(viewUV, gl_FragCoord.z);

    vec4 specularData = texture2D(specular, vTexUV);

    Shadow shadow = incomingShadow(vec4(posRWS, 1));

    Surface surface;
    Light light;
    {
        surface.smoothness = specularData.r;
        surface.metallic = specularData.g;
        surface.viewDirection = -posVS;
    }

    vec4 fragColor;
    if (watermask < .5)
    {
        vec4 albedo = texture2D(texture, vTexUV);
        vec4 col = albedo * color;
        surface.color = tolinear(col.rgb);
        surface.alpha = col.a;

        surface.normal = normalize(
            sampleNormalMap(normals, vTexUV) * rotor(vNormal, vTangent, vBinormal)
        );
        
        light = surfaceLight(surface, vLightUV, shadow);

        fragColor.rgb = directBRDF(surface, light);
        fragColor.a = surface.alpha;
    }
    else
    {
        // Water Surface normals and Height
        vec4 simplex = waternoise(posRWS + cameraPosition);


        surface.normal = normalize(
            simplex.xyz * rotor(vNormal, vTangent, vBinormal)
        );

        // TODO: Standarized Water Color
        // Water Surface Color and Alpha
        {
            vec4 albedo = texture2D(texture, vTexUV);

            vec4 col = vec4(watercolor(color.rgb, simplex.w, pow(albedo.b, 3) * 1.3), color.a);
            col.a *= albedo.a;
            // col.rgb *= mix(pow(avg(albedo.rgb), 3) * 1.3, .1, 1 - simplex.w);
            // float factor = mix(pow(avg(albedo.rgb), 3) * 1.3, .1, 1 - simplex.w);
            // debug(1 - simplex.w);

            surface.color = col.rgb;
            surface.alpha = col.a;
        }
        
        surface.smoothness = mix(.5, .9, simplex.w);
        surface.metallic = 0.01;
        
        light = surfaceLight(surface, vLightUV, shadow);

        vec4 scenePosRWS = relativeWorldSpacePixel(viewUV, sceneDepth);

        // -> composeWater()
        
        // 
        if (isEyeInWater == 1)
        {

        }
        else
        {
            float sceneDistance = length(scenePosRWS.xyz);
            float surfaceDistance = length(posRWS);
            
            float fog = waterfog(sceneDistance, surfaceDistance);
            float opacity = mix(surface.alpha, 1, fog);
            
            surface.alpha = clamp01(opacity);
        }

        // Water Refractions
        // TODO: Redesign water noise, using layered voronoi to emulate waves.
        // Simplex3D can still be used to add 
        // vec3 refraction; {

        //     refraction = texture2D(colortex7, waterfract(simplex, viewUV)).rgb;

        //     // debug(refraction);
        // }

        vec3 diffuse = directBRDF(surface, light);
        fragColor.rgb = diffuse;
        fragColor.a = surface.alpha;

    }
    
    fragColor.rgb = mix(fragColor.rgb, _debug_value.rgb, _debug_value.a);
    fragColor.a = max(fragColor.a, _debug_value.a);
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif


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

// Space
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
// Lighting
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform float nightVision;
// Water
uniform vec3 upPosition;
uniform float frameTimeCounter;
uniform ivec2 atlasSize;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 normalMatrix;

#include "/lib/color.glsl"
#include "/lib/normal.glsl"
#include "/lib/noise.glsl"
#include "/lib/space.glsl"
#include "/lib/distort.glsl"
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"


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
        TranslucentSurface surf;
        vec4 col = texture2D(texture, vTexUV) * color;
        surf.albedo = tolinear(col.rgb);
        surf.alpha = col.a;
        surf.smoothness = specularData.r;
        surf.metallic = specularData.g;
        
        surf.normal = normalize(
            sampleNormalMap(normals, vTexUV) * rotor(vNormal, vTangent, vBinormal)
        );

        surf.light = vLightUV;
        surf.viewPosition = posVS;
        surf.worldPosition = posRWS.xyz;
        
        fragColor.rgb = translucentBRDF(surf);
        fragColor.a = surf.alpha;
    }
    else
    {
        // Water Surface normals and Height
        vec4 simplex = waternoise(posRWS + cameraPosition);

        // debug(simplex.w);
        // vec4 height = waterheight(texture, vTexUV);

        // vec4 aspect;
        // aspect.w = simplex.w * height.w;
        // aspect.xyz = normalize(simplex.xyz + height.xyz);

        // aspect.xyz = height.xyz;

        // debug(height.xyz);

        Water water;
        {
            vec4 albedo = texture2D(texture, vTexUV);
            // float wtex = pow(albedo.b, 3) * 1.5;
            vec4 col = vec4(watercolor(color.rgb, simplex.w, albedo.b), color.a);
            col.a *= albedo.a;
            water.color = col.rgb;   // Blended Water Color
            // debug(water.color);
        }

        water.viewPosition = posVS;
        water.worldPosition = posRWS.xyz;
        water.screenPosition = vec3(viewUV, gl_FragCoord.z);

        vec4 scenePosRWS = relativeWorldSpacePixel(viewUV, sceneDepth);

        water.depthWorldPosition = scenePosRWS.xyz;

        water.rawNormal = simplex.xyz;
        water.normal = normalize(
            simplex.xyz * rotor(vNormal, vTangent, vBinormal)
        );
        water.light = vLightUV;

        fragColor.rgb = waterBRDF(water, colortex7);
        fragColor.a = 1.0;
    }
    
    debugblender(fragColor.rgb, fragColor.a);
    
    /* DRAWBUFFERS:7 */
    gl_FragData[0] = fragColor;

}

#endif

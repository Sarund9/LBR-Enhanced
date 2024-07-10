



#include "/lib/core.glsl"

#ifdef __VERTEX__

uniform vec3 upPosition;

#include "/lib/normal.glsl"

attribute vec4 at_tangent;
attribute vec3 at_midBlock;
attribute vec3 mc_Entity;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    
    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    vec3 normal = gl_Normal;

    int BlockID = int(max(mc_Entity.x - BaseID, 0));
    if (BlockID == ID_Foliage)
    {
        float blockheight = 1 - ((at_midBlock.y + 64.0) / 128.0);
        float ao = smoothstep(-0.3, 0.35, blockheight);
        vColor.rgb *= ao;

        vec3 up = normalize(upPosition);

        // Better Foliage Normals
        normal = mix(vec3(0, 1, 0), normal, .2);
    }

    vertex_conormals(
        normal, at_tangent,
        gl_NormalMatrix,
        vNormal, vTangent, vBinormal
    );
}

#endif

#ifdef __PIXEL__

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

#include "/lib/normal.glsl"

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec3 vNormal, vTangent, vBinormal;
varying vec4 vColor;

void main() {
    vec4 albedo = texture2D(texture, vTexUV) * vColor;
    
    vec3 normalBlend = normalize(
        denormalizeNormalSample(texture2D(normals, vTexUV))
        * rotor(vNormal, vTangent, vBinormal));

    vec4 spec = texture2D(specular, vTexUV);
    
    // TODO: Distant Horizons Blending: Apply dithering on furthest chunks
    /*
    Normal: 0 0 1
    Tangent: 0 1 0
    */

    /* DRAWBUFFERS:0123 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normalBlend * 0.5 + 0.5, 1.0f);
    gl_FragData[2] = vec4(vLightUV, 0, 1);
    gl_FragData[3] = spec;
}


#endif
/*

*/
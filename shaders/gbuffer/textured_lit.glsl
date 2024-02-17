

#include "/lib/core.glsl"

#ifdef __VERTEX__

#include "/lib/normal.glsl"

attribute vec4 at_tangent;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;
varying vec3 vNormal, vTangent, vBinormal;

void main() {
    gl_Position = ftransform();

    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    vertex_conormals(
        gl_Normal, at_tangent,
        gl_NormalMatrix,
        vNormal, vTangent, vBinormal
    );
}

#endif


#ifdef __PIXEL__

#include "/lib/normal.glsl"

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;
varying vec3 vNormal, vTangent, vBinormal;

void main() {
    vec4 albedo = texture2D(texture, vTexUV) * vColor;
    vec3 normal = normalize(
        sampleNormalMap(normals, vTexUV) * rotor(vNormal, vTangent, vBinormal)
    );
    vec4 specularData = texture2D(specular, vTexUV);
    
    /* DRAWBUFFERS:0123 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(vLightUV, 0, 1);
    gl_FragData[3] = specularData; // R M T E
}

#endif

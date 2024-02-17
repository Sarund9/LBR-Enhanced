

#include "/lib/core.glsl"

#ifdef __VERTEX__

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();

    vTexUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
}

#endif


#ifdef __PIXEL__

#include "/lib/normal.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2 vLightUV;
varying vec2 vTexUV;
varying vec4 vColor;

void main() {
    vec4 albedo = texture2D(texture, vTexUV) * vColor * texture2D(lightmap, vLightUV);
    
    /* DRAWBUFFERS:02 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(vLightUV, 0, 0);
}

#endif


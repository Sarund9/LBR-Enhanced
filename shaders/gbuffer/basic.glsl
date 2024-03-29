

#ifdef __VERTEX__

varying vec2 vLightUV;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    
    vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vColor = gl_Color;
}

#endif


#ifdef __PIXEL__

uniform sampler2D lightmap;

varying vec2 vLightUV;
varying vec4 vColor;

void main() {
    vec4 albedo = texture2D(lightmap, vLightUV) * vColor;
    
    /* DRAWBUFFERS:02 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(vLightUV, 0, 0);
}

#endif





varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec4 color;

#ifdef __VERTEX__

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    texUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
}


#endif


#ifdef __PIXEL__

uniform sampler2D texture;

void main() {
    vec4 albedo = texture2D(texture, texUV) * color;
    
    /* DRAWBUFFERS:012 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0f);
    gl_FragData[2] = vec4(lightUV, 0, 1);
}

#endif


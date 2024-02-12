

varying vec2 TexCoords;
varying vec4 Color;

#ifdef __VERTEX__

#include "/lib/core.glsl"
#include "/lib/distort.glsl"

void main() {
    
	gl_Position = ftransform();
    
	gl_Position.xy = distortPosition(gl_Position.xy);

    TexCoords = gl_MultiTexCoord0.st;
    Color = gl_Color;
}

#endif

#ifdef __PIXEL__

uniform sampler2D texture;

void main() {
    gl_FragData[0] = texture2D(texture, TexCoords) * Color;
    // gl_FragData[0] = Color;
}

#endif

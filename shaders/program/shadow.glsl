


#ifdef __VERTEX__

#include "/lib/distort.glsl"

varying vec2 TexCoords;
varying vec4 Color;

void main() {
	gl_Position = ftransform();
	gl_Position.xy = distortPosition(gl_Position.xy);
    TexCoords = gl_MultiTexCoord0.st;
    Color = gl_Color;
}

#endif

#ifdef __PIXEL__

varying vec2 TexCoords;
varying vec4 Color;

uniform sampler2D texture;

void main() {
    gl_FragData[0] = texture2D(texture, TexCoords) * Color;
}

#endif

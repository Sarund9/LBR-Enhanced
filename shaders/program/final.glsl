

#include "/lib/core.glsl"

varying vec2 TexCoords;


#ifdef __VERTEX__

void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.xy;
}

#endif

#ifdef __PIXEL__

uniform sampler2D colortex7;

// TEXTURE FORMATS
const int RGBA32F = 1;
const int R32F = 1;

const int colortex7Format = RGBA32F;

uniform float viewWidth;
uniform float viewHeight;

void main() {
    vec3 color = texture2D(colortex7, TexCoords).rgb;

    color = togamma(color); // convert to gamma space
    // float depth = texture2D(depthtex1, TexCoords).r;

    // float debugged = texture2D(colortex4, TexCoords).r;

    // depth = smoothstep(.9, 1, depth);
    // depth = pow(depth, 10);

    // color = vec3(depth);
    
    gl_FragColor = vec4(color, 1.0);
}

#endif





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

    vec3 K = vec3(luma(color));
    color = mix(K, color, 1.1);
    color += K * .05;

    gl_FragColor = vec4(togamma(color), 1.0);
}

#endif





#include "/lib/core.glsl"

#ifdef __VERTEX__

varying vec2 TexCoords;


void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.xy;
}

#endif

#ifdef __PIXEL__

#include "/lib/space.glsl"
#include "/lib/color.glsl"

uniform sampler2D colortex7;
uniform sampler2D depthtex0;

// TEXTURE FORMATS
const int RGBA32F = 1;
const int R32F = 1;

const int colortex7Format = RGBA32F;

uniform float viewWidth;
uniform float viewHeight;
uniform ivec2 atlasSize;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform float far;

varying vec2 TexCoords;

void main() {
    vec2 screenSize = vec2(viewWidth, viewHeight);

    vec3 color = texture2D(colortex7, TexCoords).rgb;

    // TODO: Ditheting Effect

    gl_FragData[0] = vec4(togamma(color), 1.0);
}

#endif



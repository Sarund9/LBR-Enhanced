

#include "/lib/core.glsl"

#ifdef __VERTEX__

varying vec2 TexCoords;


void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.xy;
}

#endif

#ifdef __PIXEL__

uniform sampler2D colortex4;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;

// TEXTURE FORMATS
const int RGBA32F = 1;
const int R32F = 1;

const int colortex7Format = RGBA32F;
const int colortex4Format = RGBA32F;

uniform float viewWidth;
uniform float viewHeight;
uniform ivec2 atlasSize;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform float far;

#include "/lib/space.glsl"

varying vec2 TexCoords;

vec4 texture2D_bilinear(in sampler2D t, in vec2 uv, in vec2 textureSize, in vec2 texelSize)
{
    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    vec2 f = fract( uv * textureSize );
    uv += ( .5 - f ) * texelSize;    // move uv to texel centre
    vec4 tl = textureGrad(t, uv, ddx, ddy);
    vec4 tr = texture2D(t, uv + vec2(texelSize.x, 0.0));
    vec4 bl = texture2D(t, uv + vec2(0.0, texelSize.y));
    vec4 br = texture2D(t, uv + vec2(texelSize.x, texelSize.y));
    vec4 tA = mix( tl, tr, f.x );
    vec4 tB = mix( bl, br, f.x );
    return mix( tA, tB, f.y );
}

vec4 supersample(in sampler2D t, vec2 uv, vec2 boxSize) {
    vec2 screenSize = vec2(viewWidth, viewHeight);
    vec2 texelSize = 1 / screenSize;

    // Get the texel coordinate of what we are actually sampling
    vec2 tx = uv * screenSize - 0.5 * boxSize;
    // 
    
    vec2 realUV = (floor(tx) + 0.5 + uv) / screenSize;
    // vec2 uv = (floor(tx) + 0.5 + offset) / texsize;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    vec2 f = fract( uv * screenSize );
    uv += ( .5 - f ) * texelSize;    // move uv to texel centre
    vec4 tl = textureGrad(t, uv, ddx, ddy);
    vec4 tr = texture2D(t, uv + vec2(texelSize.x, 0.0));
    vec4 bl = texture2D(t, uv + vec2(0.0, texelSize.y));
    vec4 br = texture2D(t, uv + vec2(texelSize.x, texelSize.y));
    vec4 tA = mix( tl, tr, f.x );
    vec4 tB = mix( bl, br, f.x );
    return mix( tA, tB, f.y );
}

void main() {
    vec2 screenSize = vec2(viewWidth, viewHeight);

    // vec2 halfTexelOffset = TexCoords + (2.0 / screenSize);

    vec3 color = texture2D(colortex7, TexCoords).rgb;

    // vec4 edges = texture2D(colortex4, TexCoords);
    // float sceneDepth = texture2D(depthtex0, TexCoords).r;

    // vec3 view = viewSpacePixel(TexCoords, sceneDepth);

    // vec2 offsetVS = (gbufferModelView * vec4(edges.xyz, 1)).xy;
    // debug(offsetVS);
    // float depthCS = pow(sceneDepth, 2) / far;

    // float supersamplemask = 1 - smoothstep(4, 10, length(view));

    // debug(max(vec3(edges.xy * 2 - 1, 0), color));
    // vec2 texeloffset = (edges.xy * 2 - 1) * 0.5;

    // vec2 uv = TexCoords + texeloffset / screenSize;

    // vec3 aliased = supersample(colortex7, uv, edges.zw).rgb;
    // vec3 aliased = textureGrad(colortex7, uv, dFdx(TexCoords), dFdy(TexCoords)).rgb;

    // debug(aliased);
    // debug(mix(color, vec3(0, 1, 0), avg(texeloffset) * 2));
    // debug(abs(color - aliased));

    // color = mix(color, aliased, supersamplemask);

    // TODO:
    /*
    The effect is meant to sample the texture again, not the screen.
    It is too weak up close, and too strong far away

    Make the effect less intense further away from the camera
    Make the effect more intense closer

    Effect works perfectly up close
        May need a bit of blur if the supersample location has greater depth

    Effect works poorly far away
        This is because the effect was designed to Upscale images, not Downscale them


    */

    vec3 K = vec3(luma(color));
    color = mix(K, color, 1.1);
    // color += K * .05;

    // color = mix(color, _debug_value.rgb, _debug_value.a);
    
    gl_FragColor = vec4(togamma(color), 1.0);
}

#endif



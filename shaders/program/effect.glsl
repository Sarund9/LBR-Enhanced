/*

Vanilla Game Effects (Composite Pass)


*/

#include "/lib/core.glsl"

#ifdef __VERTEX__

varying vec2 vTexUV;

void main() {
	gl_Position = ftransform();
	vTexUV = gl_MultiTexCoord0.st;
}

#endif


#ifdef __PIXEL__

// Space
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
// Water
uniform float frameTimeCounter;

#include "/lib/space.glsl"
#include "/lib/noise.glsl"
#include "/lib/color.glsl"
#include "/lib/water.glsl"

uniform sampler2D colortex7;
uniform sampler2D depthtex0; //
uniform sampler2D depthtex1; // No Transparents
uniform sampler2D depthtex2;
/* Distance to <????> */

varying vec2 vTexUV;

uniform int isEyeInWater;
/* 1 = camera is in water,
   2 = camera is in lava,
   3 = camera is in powdered snow */

uniform float near;
uniform float far;
uniform vec3 fogColor;
uniform ivec2 eyeBrightness;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 cameraPosition;
uniform float blindness;

float linearize_depth(float depth) {
    float z_n = 2.0 * depth - 1.0;
    return 2.0 * near * far / (far + near - z_n * (far - near));
}

vec3 fogfarpos(vec4 gPosRWS) {
    vec3 dir = normalize(gPosRWS.xyz);

    // float dfactor = eyeBrightness

    // float dist = mix(40, WaterDiffusionDistance, fogDensity);

    vec3 direct = cameraPosition + dir * WaterDiffusionDistance;

    return direct;
}

void main() {
    vec4 sceneColor = texture2D(colortex7, vTexUV);
    float sceneDepth = texture2D(depthtex0, vTexUV).r;

    vec4 gPosRWS = relativeWorldSpacePixel(vTexUV, sceneDepth);

    vec3 frag = sceneColor.rgb;

    switch (isEyeInWater) {
    
    // UNDERWATER
    case 1:
        vec3 fogpos = fogfarpos(gPosRWS);

        float noise = fractalnoise(fogpos) * .05 + .1;
        float fog = waterfog(length(gPosRWS), 0);
        
        vec3 wcolor = watercolor(fogColor, noise, .4);

        frag = oklab_mix(frag, wcolor, fog);
        break;
    }

    // BLINDNESS
    if (blindness > 0)
    {
        const float BlindnessFogDistance = 5.0;
        float dist = length(gPosRWS);
        float factor = smoothstep(BlindnessFogDistance, 0, dist);
        factor = pow(factor, 2);
        frag = mix(fogColor, frag, factor);
    }
    

    frag = mix(frag, _debug_value.rgb, _debug_value.a);

 /* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(frag, sceneColor.a);
}

#endif


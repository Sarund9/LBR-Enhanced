

varying vec2 TexCoords;
varying vec4 Color;

#ifdef __VERTEX__

#include "/lib/core.glsl"
#include "/lib/distort.glsl"

// uniform mat4 shadowProjection;
// uniform mat4 shadowProjectionInverse;
// uniform mat4 shadowModelView;
// uniform mat4 shadowModelViewInverse;
// uniform vec3 cameraPosition;

void main() {
    
	gl_Position = ftransform();
    
    // Transform position to true world position
    // vec4 posSS = shadowProjectionInverse * gl_Position;
    // vec4 posRWS = shadowModelViewInverse * posSS;
    // vec4 posWS = posRWS + vec4(cameraPosition, 0);

    // posRWS = voxelPerfect(posRWS, 1024); // VOXEL PERFECT (In World Space, to 32)

    // Reverse back the values
    // posRWS = posWS - vec4(cameraPosition, 0);
    // posSS = shadowModelView * posRWS;
    // gl_Position = shadowProjection * posSS;

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

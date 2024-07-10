

#ifdef __VERTEX__

#include "/lib/core.glsl"
#include "/lib/distort.glsl"

varying vec2 TexCoords;
varying vec4 Color;
varying float clip;

attribute vec3 mc_Entity;
attribute vec3 at_midBlock;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

void main() {
	gl_Position = ftransform();
    
    TexCoords = gl_MultiTexCoord0.st;
    Color = gl_Color;
    
    int BlockID = int(max(mc_Entity.x - BaseID, 0));
    clip = float(BlockID == ID_Foliage);

    if (BlockID == ID_Foliage)
    {
        vec3 blockPosition = 1 - ((at_midBlock + 64.0) / 128.0);
        blockPosition = (gbufferModelView * vec4(blockPosition, 1)).xyz;

        // float downfactor = blockPosition.y;
        // vec4 offset = vec4(0, -1, 0, 1) * downfactor * .1;
        // offset *= gbufferModelView;
        // offset *= gbufferProjection;
        // gl_Position += offset;
    }

	gl_Position.xy = distortPosition(gl_Position.xy);
}

#endif

#ifdef __PIXEL__

varying vec2 TexCoords;
varying vec4 Color;
varying float clip;

uniform sampler2D texture;

void main() {
    if (clip > .5) { discard; }

    gl_FragData[0] = texture2D(texture, TexCoords) * Color;
    // gl_FragData[0] = vec4(0, 0, 0, 1);
    // gl_FragData[0] = Color;
}

#endif

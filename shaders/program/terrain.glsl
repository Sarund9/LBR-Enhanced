



#include "/lib/core.glsl"

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
    // lightUV = (lightUV * 33.05f / 32.0f) - (1.05f / 32.0f);

    // lightUV = vec2(lightUV.x, lightUV.y);
    // lightUV *= lightUV;

    // lightUV = clamp(lightUV, 0, 1);

    // lightUV = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    // mul by 1.1~, sub 0.1~

    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
}

#endif

#ifdef __PIXEL__

uniform sampler2D texture;
// uniform sampler2D lightmap;


void main() {
	// Sample from texture atlas and account for biome color + ambien occlusion
    vec4 albedo = texture2D(texture, texUV) * color;
    // TODO: Distant Horizons Blending: Apply dithering on furthest chunks

    /* DRAWBUFFERS:012 */
    // Write the values to the color textures
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0f);
    gl_FragData[2] = vec4(lightUV, 0, 1);
}


#endif

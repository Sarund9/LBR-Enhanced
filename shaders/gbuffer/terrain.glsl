



#include "/lib/core.glsl"

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec3 binormal, tangent;

varying vec4 color;

// WTF is this ?
attribute vec4 at_tangent;

#ifdef __VERTEX__

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    texUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);

    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
}

#endif

#ifdef __PIXEL__

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

void main() {
	// Sample from texture atlas and account for biome color + ambien occlusion
    vec4 albedo = texture2D(texture, texUV) * color;

    vec3 normalBlend; {
        vec4 map = (texture2D(normals, texUV) * 2) - 1;
        
        mat3 mat = mat3(tangent.x, binormal.x, normal.x,
						tangent.y, binormal.y, normal.y,
					    tangent.z, binormal.z, normal.z);

		normalBlend = clamp(normalize(map.xyz * mat), vec3(-1.0), vec3(1.0));
    } 

    vec4 spec = texture2D(specular, texUV);
    // albedo.rgb = vec3(spec.rgb);
    // TODO: Distant Horizons Blending: Apply dithering on furthest chunks

    /* DRAWBUFFERS:0123 */
    // Write the values to the color textures
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normalBlend * 0.5 + 0.5, 1.0f);
    gl_FragData[2] = vec4(lightUV, 0, 1);
    gl_FragData[3] = spec;
}


#endif
/*

*/
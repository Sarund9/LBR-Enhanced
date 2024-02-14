



#include "/lib/core.glsl"

#ifdef __VERTEX__

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec3 normalWS;
varying vec3 binormal, tangent;
varying vec3 binormalWS, tangentWS;
varying vec3 blockPosition;

varying vec4 color;

attribute vec4 at_tangent;
attribute vec3 at_midBlock;

void main() {
    gl_Position = ftransform();
    // Assign values to varying variables
    texUV   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    vec3 bn = cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w;
    vec3 tn = at_tangent.xyz;

    binormal = normalize(gl_NormalMatrix * bn);
	tangent  = normalize(gl_NormalMatrix * tn);
    binormalWS = normalize(bn);
    tangentWS = normalize(tn);

    // vec4 posVS = gbufferProjectionInverse * gl_Position;
    // posRWS = (gbufferModelViewInverse * posVS).xyz;
    blockPosition = 1 - ((at_midBlock + 64.0) / 128.0);

    normalWS = gl_Normal;
    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;
}

#endif

#ifdef __PIXEL__

// AATS
uniform ivec2 atlasSize;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeigth;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

varying vec2 lightUV;
varying vec2 texUV;
varying vec3 normal;
varying vec3 normalWS;
varying vec3 binormal, tangent;
varying vec3 binormalWS, tangentWS;
varying vec3 blockPosition;

varying vec4 color;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

// vec3 toWS(vec3 ) {
    
// }

vec4 axisAliasMask(vec2 texCoord) {
    vec2 texsize = vec2(atlasSize);

    // Texel Space
    vec2 box = clamp(fwidth(texCoord) * texsize, 1e-5, 1);
    // vec2 tx = (input * inputSize) - (0.5 * box);
    vec2 tx = (texCoord * texsize) - (0.5 * box);

    // vec2 offset = clamp01((fract(tx) - (1 - box)) / box);
    vec2 offset = smoothstep(1 - box, vec2(1), fract(tx));

    vec2 uv = (floor(tx) + 0.5 + offset) / texsize;

    return vec4(box, offset);
}

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

vec4 axisAlignedSample(in sampler2D s, vec2 texCoord) {
    vec2 texsize = vec2(atlasSize);

    // Texel Space
    vec2 box = clamp(fwidth(texCoord) * texsize, 1e-5, 1);
    // vec2 tx = (input * inputSize) - (0.5 * box);
    vec2 tx = (texCoord * texsize) - (0.5 * box);

    // vec2 offset = clamp01((fract(tx) - (1 - box)) / box);
    vec2 offset = smoothstep(1 - box, vec2(1), fract(tx));

    vec2 uv = (floor(tx) + 0.5 + offset) / texsize;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    return texture2D_bilinear(s, uv, texsize, 1 / texsize);
}

void main() {
	
    vec4 aliasMask; {
        
        /*
        The transpose(ModelViewInverse) brings normals from World Space into Eye Space

        */

        vec4 mask = axisAliasMask(texUV);

        vec3 offsetWS = tangentWS * mask.z + binormalWS * mask.w;

        
        vec2 offsetVS = (gbufferModelView * vec4(offsetWS, 1)).xy;

        aliasMask.xy = (offsetVS + 1) / 2.0;
        aliasMask.zw = mask.xy;

        // vec3 blend = ((tangentWS + 1) / 2.0);
        // blend = tangentWS;
        // blend *= vec3(1, 1, 1);
        // blend = mix(blend, vec3(1), mask.z);

        // debug(offsetWS);
        /*
        Multiply Texel X by the Tangent
        Multiply Text Y by the Binormal

        */
    }

    // Sample from texture atlas and account for biome color + ambien occlusion
    vec4 albedo = texture2D(texture, texUV) * color;
    // debug(albedo.rgb);
    // albedo.rgb *= albedo.a;
    // if(albedo.a < .8) {
    //     discard;
    // }


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

    albedo.rgb = mix(albedo.rgb, _debug_value.rgb, _debug_value.a);
    albedo.a = max(albedo.a, _debug_value.a);

    /* DRAWBUFFERS:01234 */
    // Write the values to the color textures
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normalBlend * 0.5 + 0.5, 1.0f);
    gl_FragData[2] = vec4(lightUV, 0, 1);
    gl_FragData[3] = spec;
    gl_FragData[4] = aliasMask;
}


#endif
/*

*/
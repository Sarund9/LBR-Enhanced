
/*

Axis Aligned Texture Sampling

https://www.youtube.com/watch?v=d6tp43wZqps

TODO: How to make a texture sampled linearly
    Terrain is already linear sampled

TODO: Pre Multiply the Alpha

Terrain texture is already sampled in linear


vec2 tx = texCoord * BlockTextureSize;

vec2 offset = clamp(fract(tx) * PixelsPerTexel, 0, 0.5) - 
    clamp((1 - fract(tx)) * PixelsPerTexel, 0, 0.5);

vec2 uv = (floor(tx) + 0.5 + offset) * BlockTextureSize;

return uv;
*/

// const float BlockTextureSize = 16;
// const float PixelsPerTexel = 1; // assume

// vec2 alginTexCoord(vec2 texCoord) {
//     return texCoord;
// }

// const float BlockTextureSize = 16;
// const float PixelsPerTexel = 1; // assume

// vec4 axisAlignedSample(in sampler2D image, vec2 texCoord) {
    
//     vec2 boxSize = clamp((abs(dFdx(texCoord))) + abs(dFdy(texCoord)) * BlockTextureSize, 1e-5, 1);

//     vec2 tx = texCoord * BlockTextureSize - 0.5 * boxSize;

//     // vec2 offset = clamp((fract(tx) - (1 - boxSize)) / boxSize, 0, 1);
//     vec2 offset = smoothstep(1 - boxSize, vec2(1.0), fract(tx));

//     vec2 uv = (floor(tx) + 0.5 + offset) * BlockTextureSize;
    
//     // return texture2D(image, uv);
//     return vec4(uv, 0, 1);
// }


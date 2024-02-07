
/*

Axis Aligned Texture Sampling

https://www.youtube.com/watch?v=d6tp43wZqps

TODO: How to make a texture sampled linearly

Terrain texture is already sampled in linear


vec2 tx = texCoord * BlockTextureSize;

vec2 offset = clamp(fract(tx) * PixelsPerTexel, 0, 0.5) - 
    clamp((1 - fract(tx)) * PixelsPerTexel, 0, 0.5);

vec2 uv = (floor(tx) + 0.5 + offset) * BlockTextureSize;

return uv;
*/

const float BlockTextureSize = 16;
const float PixelsPerTexel = 1; // assume

vec2 alginTexCoord(vec2 texCoord) {
    return texCoord;
}



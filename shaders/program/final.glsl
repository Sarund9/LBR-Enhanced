

#include "/lib/core.glsl"

varying vec2 TexCoords;


#ifdef __VERTEX__

void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.xy;
}

#endif

#ifdef __PIXEL__

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;

// vec2 pixelCoord() {
//     return TexCoords / vec2(viewWidth, viewHeight);
// }

// float matmask(mat3 input, mat3 weights) {
//     float value = 0;
//     for (int x = 0; x <= 2; x++) {
//         for (int y = 0; y <= 2; y++) {
//             value += input[x][y] * weights[x][y] * (1/9);
//         }
//     }
//     return value;
// }

// vec4 blur5(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
//     vec4 color = vec4(0.0);
//     vec2 off1 = vec2(1.3333333333333333) * direction;
//     color += texture2D(image, uv) * 0.29411764705882354;
//     color += texture2D(image, uv + (off1 / resolution)) * 0.35294117647058826;
//     color += texture2D(image, uv - (off1 / resolution)) * 0.35294117647058826;
//     return color; 
// }

void main() {
    vec3 color = texture2D(colortex0, TexCoords).rgb;

    // mat3 depthMatrix;
    // vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    // for (int x = 0; x <= 2; x++) {
    //     for (int y = 0; y <= 2; y++) {
    //         vec2 pixelCoord = TexCoords + pixelSize * vec2(x - 1, y - 1);
    //         depthMatrix[x][y] = texture2D(depthtex0, pixelCoord).r;
    //     }
    // }
    
    // float mask = matmask(depthMatrix, mat3(
    //     1.0, 1.0, 1.0,
    //     1.0, 10.0, 1.0,
    //     1.0, 1.0, 1.0
    // ));

    // vec4 b = blur5(colortex0, TexCoords, vec2(viewWidth, viewHeight), vec2(0));
    // color = b.rgb;

    // renderBlend = mix(renderBlend, _debug_value.rgb, _debug_value.a);

    gl_FragColor = vec4(color, 1.0);
}

#endif



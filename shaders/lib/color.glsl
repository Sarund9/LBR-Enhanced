/*

General Color Control


*/


float luma(vec3 color) {
    // Algorithm from Chapter 16 of OpenGL Shading Language
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    return dot(color, W);
}

// Applies stylized shading to a color
vec3 shade(vec3 color) {
    vec3 res = color;
    float grayscale = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(res, vec3(grayscale), vec3(0.3)); // move 30% towards grayscale

    // Make it darker and more blue
    res *= vec3(0.95, 0.91, 1.14); // 5 + 9 == 14
    res *= 0.1;

    return res;
}

vec3 resaturate(vec3 rgb, float adjustment) {
    vec3 intensity = vec3(luma(rgb));
    return mix(intensity, rgb, adjustment);
}

float saturation(vec3 color) {
    // TODO: 
    float a = avg(color);
    vec3 dist = abs(color - vec3(a));
    return avg(dist);
}

vec3 normalizeColor(vec3 rgb) {
    return rgb / avg(rgb);
}

vec3 oklab_mix( vec3 colA, vec3 colB, float h )
{
    // https://bottosson.github.io/posts/oklab
    const mat3 kCONEtoLMS = mat3(                
         0.4121656120,  0.2118591070,  0.0883097947,
         0.5362752080,  0.6807189584,  0.2818474174,
         0.0514575653,  0.1074065790,  0.6302613616);
    const mat3 kLMStoCONE = mat3(
         4.0767245293, -1.2681437731, -0.0041119885,
        -3.3072168827,  2.6093323231, -0.7034763098,
         0.2307590544, -0.3411344290,  1.7068625689);
                    
    // rgb to cone (arg of pow can't be negative)
    vec3 lmsA = pow( kCONEtoLMS*colA, vec3(1.0/3.0) );
    vec3 lmsB = pow( kCONEtoLMS*colB, vec3(1.0/3.0) );
    // lerp
    vec3 lms = mix( lmsA, lmsB, h );
    // gain in the middle (no oaklab anymore, but looks better?)
    // lms *= 1.0+0.2*h*(1.0-h);
    // cone to rgb
    return kLMStoCONE*(lms*lms*lms);
}

vec3 getGradient(vec4 c1, vec4 c2, vec4 c3, vec4 c4, float value_) {
	
	float blend1 = smoothstep(c1.w, c2.w, value_);
	float blend2 = smoothstep(c2.w, c3.w, value_);
	float blend3 = smoothstep(c3.w, c4.w, value_);
	
	vec3 
	col = oklab_mix(c1.rgb, c2.rgb, blend1);
	col = oklab_mix(col, c3.rgb, blend2);
	col = oklab_mix(col, c4.rgb, blend3);
	
	return col;
}

vec3 hueShift(vec3 color, float hue) {
    const vec3 k = vec3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(hue);
    return vec3(
        (color * cosAngle)
      + (cross(k, color) * sin(hue))
      + (k * dot(k, color) * (1.0 - cosAngle))
    );
}

vec3 darken(vec3 color, float sub) {
    /* Desmos:
    D\left(v\right)=\left(1-v\right)^{2}-1
    F\left(v,\ c\right)=D\left(v\right)c
    R=r+F\left(x,\ r\right)
    G=g+F\left(x,\ g\right)
    B=b+F\left(x,\ b\right)
    */
    float C = square(1 - sub) - 1;
    return color + C * color;
}

vec3 lighten(vec3 color, float add) {
    /* Desmos:
    x+b\left(1-x\right)
    F is a factor that gradually reduces the effect of add
    */

    vec3 F = vec3(1) - color;
    F = smoothstep(1, 0, F);

    return color + vec3(add) * F;
}

vec3 lighten(vec3 color, vec3 add) {
    /* Desmos:
    x+b\left(1-x\right)
    F is a factor that gradually reduces the effect of add
    */

    vec3 F = vec3(1) - color;
    F = smoothstep(1, 0, F);

    return color + add * F;
}

float asqrt(float value) {
    float X = intBitsToFloat((floatBitsToInt(value) & 0xff000000) / 2 + (1 << 29));

    return (X + value / X) / 2.0;
}


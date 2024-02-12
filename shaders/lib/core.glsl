#ifndef __INCLUDED_CORE__
#define __INCLUDED_CORE__

/*
Channels:

colortex0: color
colortex1: normal
depthtex0: shadows

IDS:

Base ID is 1000

Water: 5


*/

const int BaseID = 1000;

const int ID_Water          = BaseID + 5;



const float PI = 3.14159265359;

vec4 _debug_value;

void debug(vec3 value) {
    _debug_value = vec4(value, 1);
}

void debug(vec2 value) {
    _debug_value = vec4(value, 0, 1);
}

void debug(float value) {
    _debug_value = vec4(value, value, value, 1);
}

void debug(float r, float g) {
    _debug_value = vec4(r, g, 0, 1);
}

void debug(float r, float g, float b) {
    _debug_value = vec4(r, g, b, 1);
}

void debughdr(float value) {
    _debug_value = vec4(
        value * float(value < 1),
        value * float(value < 2) * float(value > 1),
        value * float(value < 3) * float(value > 2),
    1);
}

void debugp(float value, float start, float end) {
    const vec3 StartColor = vec3(0);
    const vec3 EndColor = vec3(1);

    float T = (value - start) / (end - start);

    _debug_value = vec4(
        mix(StartColor, EndColor, T),
    1);
}

void debugldr(float value) {
    float T = clamp(value, 0, 1);
    _debug_value = vec4(T, T, T, 1);
    float under = max(- value, 0); // TODO: This des not work
    float over = max(value - 1, 0);
    _debug_value.rgb *= vec3(
        1 + over - under,
        1 - max(over, under),
        1 + under - over
    );
}

// vec3 pow3() {

// }

#include "option.glsl"

float square(float v) {
    return v * v;
}

float clamp01(float v) {
    return clamp(v, 0, 1);
}

vec3 clamp01(vec3 v) {
    return clamp(v, 0, 1);
}

vec3 tolinear(vec3 color) {
    return pow(color, vec3(2.2f));
}

vec3 togamma(vec3 color) {
    return pow(color, vec3(1.0f / 2.2f));
}

vec3 linearstep(vec3 value, float a, float b) {
    return (value - a) / (b - a);
}

float linearstep(float value, float a, float b) {
    return (value - a) / (b - a);
}

vec3 mixstep(vec3 value, float xMin, float xMax, float yMin, float yMax) {
    return mix(vec3(yMin), vec3(yMax), linearstep(value, xMin, xMax));
}

float mixstep(float value, float xMin, float xMax, float yMin, float yMax) {
    return mix(yMin, yMax, linearstep(value, xMin, xMax));
}

float avg(vec3 vec) {
    return (vec.x + vec.y + vec.z) / 3;
}

float luma(vec3 color) {
    // Algorithm from Chapter 16 of OpenGL Shading Language
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    return dot(color, W);
}

// Polynomial smooth min
float psmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
    return mix(a, b, h) - k*h*(1.0-h);
}

// Polynomial smooth min
vec3 psmin(vec3 a, vec3 b, float k) {
    vec3 h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
    return mix(a, b, h) - k*h*(1.0-h);
}

/*
Logic Step Interpolation
k = 0 returns the average
Non-Zero values provide a smooth min/max
Greater (abs) values provide a more accurate result.
-5/5 is recommended at least.
*/
float lstep(float a, float b, float k)
{
    // Desmos: S\left(a,\ b,\ k\right)=\frac{\left(a\cdot\exp\left(ka\right)+b\cdot\exp\left(kb\right)\right)}{\exp\left(ka\right)+\exp\left(kb\right)}
    float x = exp(k * a);
    float y = exp(k * b);
    return (a * x + b * y) / (x + y);
}

vec3 lstep(vec3 a, vec3 b, float k)
{
    vec3 x = exp(k * a);
    vec3 y = exp(k * b);
    return (a * x + b * y) / (x + y);
}

float stepmask(float value, float a, float b) {
    float G = float(value >= a);
    float L = float(value <= b);

    return G * L;
}

float stepmask(float value, float a, float b, float k) {
    
    float aDiff = value - a;
    float bDiff = value - b;

    float range = abs(a - b) * k;

    float transition = clamp01(linearstep(a - range, a + range, value))
                     * clamp01(linearstep(b - range, b + range, value));

    

    /*
    When v==a, .5
    When v==a-range, 0

    */

    float extended = stepmask(value, a - range, b + range);
    float retracted = stepmask(value, a + range, b - range);

    return smoothstep(extended, retracted, transition);
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

float packNormal(float value, float mult) {
    return value * mult - mult * .5 + .5;
}

float n_raiseStart(float value, float T) {
    return (1 - T) * value + T;
}

float bellcurve(float value, float width, float lowest, float damp) {
    // Desmos: 1-\left(\frac{x-.5}{.5a}\right)^{2}
    float curve = 1 - square((value - 0.5) / (width * 0.5));
    float high = lstep(curve, lowest, 5 + damp);

    return high;
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

/*
Dampened Add
A, B: add
E: dampener power (should be (0-1))
T: threshold 
K: smoothing
*/
float dampadd(float a, float b, float e, float t, float k) {
    float add = a + b;
    float damp = pow(add, e) + t;

    return psmin(add, damp, k);
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

vec4 voxelPerfect(vec4 value, float voxelSize) {
    // const float BlockTextureSize = 16.0; // TODO: Texture Size Menu Option
    vec4 pix = value * voxelSize;
    pix = floor(pix);
    pix += vec4(.5);
    return pix / voxelSize;
}

#endif
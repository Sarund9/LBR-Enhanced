
/*
Channels:

colortex0: color
colortex1: normal
depthtex0: shadows

IDS:

Base ID is 1000

Water: 5


*/

#include "/settings.glsl"

const int BaseID = 10000;

const int ID_Water = 3;
const int ID_Foliage = 10;



const float PI = 3.14159265359;

#ifdef DEBUG
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
#else
#define debug(...)
#define debughdr(...)
#define debugp(...)
#define debugldr(...)

#endif

void debugblender(inout vec3 rgb) {
#ifdef DEBUG
    rgb = mix(rgb, _debug_value.rgb, _debug_value.a);
#endif
}

void debugblender(inout vec3 rgb, inout float alpha) {
#ifdef DEBUG
    rgb = mix(rgb, _debug_value.rgb, _debug_value.a);
    alpha = max(alpha, _debug_value.a);
#endif
}

// vec3 pow3() {

// }

float square(float v) {
    return v * v;
}

vec2 square(vec2 v) {
    return v * v;
}

vec3 square(vec3 v) {
    return v * v;
}

vec4 square(vec4 v) {
    return v * v;
}

vec3 snormalize(vec3 val) {
    if (val.x == 0 && val.y == 0 && val.z == 0) { return vec3(0); }

    return normalize(val);
}

float clamp01(float v) {
    return clamp(v, 0, 1);
}

vec2 clamp01(vec2 v) {
    return clamp(v, 0, 1);
}

vec3 clamp01(vec3 v) {
    return clamp(v, 0, 1);
}

vec3 tolinear(vec3 color) {
    return pow(color, vec3(2.2));
}

vec3 togamma(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
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

float smoothmask(float value, float a, float b, float k) {
    float L = smoothstep(a-k, a+k, value);
    float H = smoothstep(b+k, b-k, value);
    return min(L, H);
}

float avg(vec2 vec) {
    return (vec.x + vec.y) / 2.0;
}

float avg(vec3 vec) {
    return (vec.x + vec.y + vec.z) / 3.0;
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

// Polynomial smooth min
vec4 psmin(vec4 a, vec4 b, float k) {
    vec4 h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
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

    float high = stepmask(value, a - range, b + range);
    float low = stepmask(value, a + range, b - range);

    return smoothstep(high, low, transition);
}

void stepgrad(inout float grad, float value, float threshold) {
    grad = max(grad, step(threshold, value) * threshold);
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

vec2 voxelPerfect(vec2 value, float voxelSize) {
    // const float BlockTextureSize = 16.0; // TODO: Texture Size Menu Option
    vec2 pix = value * voxelSize;
    pix = floor(pix);
    pix += vec2(.5);
    return pix / voxelSize;
}

vec4 voxelPerfect(vec4 value, float voxelSize) {
    // const float BlockTextureSize = 16.0; // TODO: Texture Size Menu Option
    vec4 pix = value * voxelSize;
    pix = floor(pix);
    pix += vec4(.5);
    return pix / voxelSize;
}

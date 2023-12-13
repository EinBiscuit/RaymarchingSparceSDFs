
#define PI 3.14159
#define U(a,b) (a.x*b.y-b.x*a.y)
#define MAX_STEPS 256

//distance functions by Inigo Quilez

float Sphere(float3 p, float s)
{
    return length(p) - s;
}

float RoundBox(float3 p, float3 b, float r)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// polynomial smooth min IQ
float sminCubic( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*h*k*(1.0/6.0);
}

float smoothmax(float a, float b, float k)
{
    return -sminCubic(-a, -b, k);
}

void opRep(float3 p, float3 c, out float3 q )
{
    q = abs(fmod(p + 0.5 * c, c)) - 0.5 * c;
}

float2 repeat(float2 pos, float t)
{
    t = 2. * PI / t;
    float angle = fmod(atan2(pos.y, pos.x), t) - 0.5 * t;
    float r = length(pos);
    return r * float2(cos(angle), sin(angle));
}

// Created by Sebastien Durand - 2014

float smoothabs(float p, float k)
{
    return sqrt(p * p + k * k) - k;
}

float2 B(float2 m, float2 n, float2 o, float3 p) 
{
    float2 q = p.xy;
    m -= q;
    n -= q;
    o -= q;
    float x = U(m, o), y = 2. * U(n, m), z = 2. * U(o, n);
    float2 i = o - m, j = o - n, k = n - m,
		 s = 2. * (x * i + y * j + z * k),
		 r = m + (y * z - x * x) * float2(s.y, -s.x) / dot(s, s);
    float t = clamp((U(r, i) + 2. * U(k, r)) / (x + x + y + z), 0., 1.); // parametric position on curve
    r = m + t * (k + k + t * (j - k)); // distance on 2D xy space
    return float2(sqrt(dot(r, r) + p.z * p.z), t); // distance on 3D space
};



float Teapot(float3 pos) 
{
    float2 A[15];
    float2 T1[5];
    float2 T2[5];
    
    // Teapot body profil (8 quadratic curves) 
    A[0] = float2(0, 0);
    A[1] = float2(.64, 0);
    A[2] = float2(.64, .03);
    A[3] = float2(.8, .12);
    A[4] = float2(.8, .3);
    A[5] = float2(.8, .48);
    A[6] = float2(.64, .9);
    A[7] = float2(.6, .93);
    A[8] = float2(.56, .9);
    A[9] = float2(.56, .96);
    A[10] = float2(.12, 1.02);
    A[11] = float2(0, 1.05);
    A[12] = float2(.16, 1.14);
    A[13] = float2(.2, 1.2);
    A[14] = float2(0, 1.2);
	// Teapot spout (2 quadratic curves)
    T1[0] = float2(1.16, .96);
    T1[1] = float2(1.04, .9);
    T1[2] = float2(1, .72);
    T1[3] = float2(.92, .48);
    T1[4] = float2(.72, .42);
	// Teapot handle (2 quadratic curves)
    T2[0] = float2(-.6, .78);
    T2[1] = float2(-1.16, .84);
    T2[2] = float2(-1.16, .63);
    T2[3] = float2(-1.2, .42);;
    T2[4] = float2(-.72, .24);
    
    // precalcul first part of teapot spout
    float2 h = B(T1[2], T1[3], T1[4], pos);
    float a = 99.,
    // distance to teapot handle (-.06 => make the thickness) 
		b = min(min(B(T2[0], T2[1], T2[2], pos).x, B(T2[2], T2[3], T2[4], pos).x) - .06,
    // max p.y-.9 => cut the end of the spout 
                max(pos.y - .9,
    // distance to second part of teapot spout (abs(dist,r1)-dr) => enable to make the spout hole 
                    min(abs(B(T1[0], T1[1], T1[2], pos).x - .07) - .01,
    // distance to first part of teapot spout (tickness incrase with pos on curve) 
                        h.x * (1. - .75 * h.y) - .08)));
	
    // distance to teapot body => use rotation symetry to simplify calculation to a distance to 2D bezier curve
    float3 qq = float3(sqrt(dot(pos, pos) - pos.y * pos.y), pos.y, 0);
    // the substraction of .015 enable to generate a small thickness arround bezier to help convergance
    // the .8 factor help convergance  
    for (int i = 0; i < 13; i += 2) 
        a = min(a, (B(A[i], A[i + 1], A[i + 2], qq).x - .015) * .7);
    // smooth minimum to improve quality at junction of handle and spout to the body
    return sminCubic(a, b, .02);
}

void getHeatMapColor(float value, out float red, out float green, out float blue) // http://andrewnoske.com/wiki/Code_-_heatmaps_and_color_gradients adapted from
{
    const int NUM_COLORS = 4;
    static float color[NUM_COLORS][3] = { { 0, 0, 1 }, { 0, 1, 0 }, { 1, 1, 0 }, { 1, 0, 0 } };
    // A static array of 4 colors:  (blue,   green,  yellow,  red) using {r,g,b} for each.
  
    int idx1; // |-- Our desired color will be between these two indexes in "color".
    int idx2; // |
    float fractBetween = 0; // Fraction between "idx1" and "idx2" where our value is.
  
    if (value <= 0)
    {
        idx1 = idx2 = 0;
    } // accounts for an input <=0
    else if (value >= 1)
    {
        idx1 = idx2 = NUM_COLORS - 1;
    } // accounts for an input >=0
    else
    {
        value = value * (NUM_COLORS - 1); // Will multiply value by 3.
        idx1 = floor(value); // Our desired color will be after this index.
        idx2 = idx1 + 1; // ... and before this index (inclusive).
        fractBetween = value - float(idx1); // Distance between the two indexes (0-1).
    }
    
    red = (color[idx2][0] - color[idx1][0]) * fractBetween + color[idx1][0];
    green = (color[idx2][1] - color[idx1][1]) * fractBetween + color[idx1][1];
    blue = (color[idx2][2] - color[idx1][2]) * fractBetween + color[idx1][2];
}

void  opRepLim(in float3 p, in float c, in float3 l, in out float3 q)
{
    q = p - c * clamp(round(p / c), -l, l);
}
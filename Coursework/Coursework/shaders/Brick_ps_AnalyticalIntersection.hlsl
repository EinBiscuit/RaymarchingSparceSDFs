// Texture pixel/fragment shader
// Basic fragment shader for rendering textured geometry

#include "OctreeDefs.hlsli"


// Texture and sampler registers
Texture3D<float> texture0 : register(t0);

StructuredBuffer<Node> Octree : register(t1);

SamplerState Sampler0 : register(s0);

#include "Scene.hlsli"

struct InputType
{
	float4 position : SV_POSITION;
	float3 tex : TEXCOORD0;
	float4 worldPos : TEXCOORD1;
};

cbuffer Control : register(b0)
{
	float4 PFP;
	matrix ViewMatrix;
	Light light;
	int SampleMode;
	float epsilon;
    float TextureStride;
	float color;
};

#define FAR 1.f
#define MAX_STEPS 64

// https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-intrinsic-functions

// dda https://www.shadertoy.com/view/4dX3zl



bool GetVoxel(float3 pos, inout float4 color, out uint exitLevel) 
{
    bool hazVoxel = false;
    
    uint page = 0; // level of octree offset
    uint NodeP = 0; // particular block position within layer
    uint ChildP = 0; // child position within block
    
    uint3 Bucket3d = { 0, 0, 0 };
    uint Bucket1D = 0;
    
    exitLevel = 0;
    
    [unroll]
    for (uint i = 0; i < 3; i++)
    {
        Bucket3d = uint3(saturate(pos *= 2.f)); // block position 
        pos -= Bucket3d;// update position for the next layer
        Bucket1D = Bucket3d.x << 2 | Bucket3d.y << 1 | Bucket3d.z; // get morton number of the block
        
        uint index = page + NodeP + ChildP;
        
        uint Vmask = Octree[index].Valid;
        
        hazVoxel = (Vmask & 1 << Bucket1D) ? true : false;
        if (!hazVoxel) break;
        
        exitLevel++;
        
        NodeP = Octree[index].Desc;
        ChildP = setBitNum(Bucket1D, Vmask);
        
        page += pow(8, i);
    }
    
    //if (hazVoxel) color = float4( 1, 0, 0, 0); // make voxel pretty
    //else
    //    color = float4(0,0,0, 1);
    
    return hazVoxel;
}

struct Stack
{
    uint index;
    float tmin;
    float tmax;
};


bool Raymarch(float3 rd, float3 ro, Texture3D<float> SDF, float MaxMarch, out float3 pos)
{
    float t = 0;
	float d = 0;
	pos = ro;
    
    for (int i = 0; i < 128; i++)
    {
        d = min(SDF.SampleLevel(Sampler0, pos, 0) / TextureStride, Scene(pos));
		t += d;
		if (d < 0.004f || t>MaxMarch) break;
		pos = ro + rd * t;
    }
	return d < epsilon;
}




struct Hit
{
    float3 p;
    float t; // solution to p=o+t*d
    float tmax; //distance to exit point?
    float tmin; // distance to enter point?
    float3 n; // normal
};


bool SolveCubic(float4 C, out float FirstRoot)
{
      // --- Solving a*x³ +b*x³ +c*x +d = 0. -> l = min(3 solutions)
    float a = C.x, b = C.y, c = C.z, d = C.w,
          Q, A, D, v, l, k = -1.;

    if (abs(a) < 1e-3)
    { // degenerated P3
        k = -2.;
        v = c * c - 4. * b * d;
        l = (-c - sign(b) * sqrt(v)) / (2. * b);
        FirstRoot = l;
        return true;
    }
    else
    { // true P3       
        b /= a;
        c /= a;
        d /= a;
        float p = (3. * c - b * b) / 3.,
            q = (9. * b * c - 27. * d - 2. * b * b * b) / 27., // -
            r = q / 2.;
        Q = p / 3.;
        D = Q * Q * Q + r * r;
    
        if (D < 0.)
        { // --- if 3 sol
            A = acos(r / sqrt(-Q * Q * Q)),
            k = round(1.5 - A / 6.283); // k = 0,1,2 ; we want min l
            l = 2. * sqrt(-Q) * cos((A + (k) * 6.283) / 3.) - b / 3.;
            FirstRoot = l;
            return true;
        }
        else // --- if 1 sol
            return false;
        //if (p > 0.)
        //    v = -2. * sqrt(p / 3.),
        //#define asinh(z) ( sign(z)*asinh(abs(z)) )      // fix asinh() symetry error 
        //          l = -v * sinh(asinh(3.*-q/p/v) / 3.) - b / 3.;
        //else
        //    v = -2. * sqrt(-p / 3.),
        //    l = sign(-q) * v * cosh(acosh(3. * abs(q) / p / v) / 3.) - b / 3.;
        //return true;
    }
      
    return false;
};


float4 main(InputType input) : SV_TARGET
{
    
    float4 textureColor = float4(input.tex, 1);
    float3 rd = normalize(input.worldPos.xyz - PFP.xyz);
    float3 ri = 1.f / rd;
  
    float3 maxRI = abs(ri);
    
    float t_max = min(maxRI.x, min(maxRI.y, maxRI.z));
    
    float3 ro = input.tex.xyz;
    
    float s000  = -1;
    float s001  = 1;
    float s010  = 1;
    float s100  = 1;
    float s101  = 1;
    float s110  = 1;
    float s011  = 1;
    float s111  = -1;
    
    
    float a = s101 - s001;
    
    float k0 = s000                     ;    
    float k1 = s100 - s000              ;
    float k2 = s010 - s000              ;
    float k3 = s110 - s010 - k1         ;
    float k4 = k0 - s001                ;
    float k5 = k1 - a                   ;
    float k6 = k2 - (s011 - s001)       ;
    float k7 = k3-(s111 - s011- a)      ;
    
    float3 m0 = ro.x * ro.y;
    float3 m1 = rd.x * rd.y;
    float3 m2 = ro.x * rd.y + ro.y * rd.x;
    float3 m3 = k5 * ro.z - k1;
    float3 m4 = k6 * ro.z - k2;
    float3 m5 = k7 * ro.z - k3;
    
    float c0 = (k4*ro.z- k0) + ro.x*m3 + ro.y*m4 + m0*m5;
    float c1 = rd.x*m3 + rd.y*m4 + m2*m5 + rd.z*(k4 + k5*ro.x + k6*ro.y + k7*m0);
    float c2 = m1 * m5 + rd.z * (k5*rd.x + k6*rd.y + k7*m2);
    float c3 = k7*m1*rd.z;

    
    //float3 roots = SolveCubic(float4(c3, c2, c1, c0));
    
    float root = 0;
    
    if (SolveCubic(float4(c3,c2,c1,c0),root))
        if (root > 0 & root < t_max)
            textureColor = float4(1, 1, 1, 1);

    //float minroot = min(roots.x, min(roots.y, roots.z));
    //
    //if (minroot > 0 & minroot < t_max)
    //    textureColor = float4(1, 1, 1, 1);

    
    //textureColor = float4(texture0.SampleLevel(Sampler0,ro + rd * max_dist,0),0,0, 1);

	//float3 n;
	// 
	//if (t < FAR)
	//{
    //    float3 pos = ro + rd * (t);
	//
	//    n = calcNormalVolume(Sampler0, texture0, pos, epsilon);
    //    ////n = calcNormal(pos,epsilon);
	//	textureColor = PhongShading(n, light);
    //}


    //return (input.tex.xyz + rd * epsilon).xyzz;
    //return float4(input.tex.xyz,1);
        return textureColor;
  //  return float4(rd, 1);
}
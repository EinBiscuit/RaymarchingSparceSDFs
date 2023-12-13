// Texture pixel/fragment shader
// Basic fragment shader for rendering textured geometry

#include "OctreeDefs.hlsli"

// Texture and sampler registers
Texture3D<snorm float> texture0 : register(t0);

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

struct Ray
{
    float3 ro, rd, invDir;
};

float4 Trace(Ray r)
{
    bool hazVoxel = false;
    
    float3 ro = r.ro;
    float3 rd = r.rd;
    float3 rs = sign(r.rd);
	
    float4 textureColor = float4(0, 0, 0, 0);

    float3 pos = floor(ro * 8.f);
    float3 rpos = r.ro;
    float3 ri = r.invDir;

    float3 dis = (pos - ro * 8.f + 0.5 + rs * 0.5) * ri * 0.125f;
    float3 mm = float3(0, 0, 0);
    
    uint page = 0; // level of octree offset
    uint NodeP = 0; // particular block position within layer
    uint ChildP = 0; // child position within block
    
    uint3 Bucket3d = { 0, 0, 0 };
    uint Bucket1D = 0;
    
    uint exit_lvl = 0;
    
    float t_max = min(ri.x, min(ri.y, ri.z));
    
    float t = 0;
    
    float3 cpos = float3(1, 1, 1);
    
    Stack stack[4];
    
    stack[0].index = 0;
    stack[0].tmax = t_max;
    stack[0].tmin = 0;
    
    float scale = 1;
    
    while (t < t_max)
    {
        Bucket3d = uint3(saturate(cpos *= 2.f)); // block position 
        pos -= Bucket3d; // update position for the next layer
        Bucket1D = Bucket3d.x << 2 | Bucket3d.y << 1 | Bucket3d.z; // get morton number of the block
    
        uint index = page + NodeP + ChildP;
    
        break;
    }
    
    return float4(0, 0, 0, 0);

    
}



bool Raymarch(float3 rd, float3 ro, Texture3D<snorm float> SDF, float MaxMarch, out float3 pos)
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

//struct Stack
//{
//    uint index;
//    float3 center;
//    float scale;
//};



float4 main(InputType input) : SV_TARGET
{

	float3 ro = input.tex.xyz;

    float3 rd = normalize(input.worldPos.xyz - PFP.xyz);
	
    float4 textureColor = float4(0, 0, 0, 0);

    float3 pos = floor(ro*8.f);
    float3 rpos = ro;
    float3 ri = 1.f / rd;
    float3 rs = sign(rd);
    float3 dis = (pos - ro*8.f + 0.5 + rs * 0.5) * ri;
    float3 mm = float3(0, 0, 0);
    
    float start = 0;
    float end = min(dis.x, min(dis.y, dis.z));
   
    float3 maxRI = abs(ri * 8.f);
    
    float t_max = min(maxRI.x, min(maxRI.y, maxRI.z));
    
    uint exit_lvl = 0;
    
    
    
   
    for (int i = 0; i < 64; i++)
    {
        if (end >= t_max)
            break;
        
        if (GetVoxel(pos / 8.f + 0.125 * 0.5, textureColor, exit_lvl)) // position coinverted into 01 range and contered in an 8th
        {
            float3 n = { 0,0,0 };
    
            if (Raymarch(rd, ro + rd * start * 0.125f, texture0, (end - start) * 0.125f, n))
            {
                
                
                textureColor  =  float4(calcNormalVolume(Sampler0, texture0, n, epsilon), 1);
                
                break;
            }
            //else
                //textureColor = float4(0, 0, 0, 0);
        }
    
        mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
        dis += mm * rs * ri;
        pos += mm * rs;
        
        //pos = floor(ro * 8.f + rd * start); // add small bias
        
        start = end;
        end = min(dis.x, min(dis.y, dis.z)) ;
        
        //textureColor += float4(1/64.f, 1/64.f, 1/64.f, 1/64.f); march complexity vis

    }
    
    
    
    
    
    
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

#include "Scene.hlsli"
#include "OctreeDefs.hlsli"

#define N 16 
#define EPSILON 0.001f
#define FAR 100.f

#define MAX_SHAPES 3

//BUFFERS

RWTexture2D<float4> gOutput : register(u0);

Texture3D<snorm float> Volume : register(t0);

StructuredBuffer<Node> Octree : register(t1);

SamplerState VolumeSampler : register(s0);

cbuffer Camera : register(b0)
{
    float4 PFP;
    matrix ViewMatrix;
    Light light;
    int ShapeType;
    float epsilon;
    float TextureStride; // in space
    float NormalBias;

    float4 ObjectTranslationScale;
    float3 Rotation;

    float Raymarch_boxScale;
};

struct Shape
{
    float3 pos;
    float scale;
    float tmin;
    float tmax;
};


bool Raymarch(float3 rd, float3 ro, Texture3D<snorm float> SDF, float MaxMarch, out float3 pos, in out int stepcount)
{
    float t = 0;
    float d = 0;
    pos = ro;
    
    for (int i = 0; i < MAX_STEPS; i++)
    {
        d = SDF.SampleLevel(VolumeSampler, pos, 0) / TextureStride;
        t += d;
        
        pos += rd * d;
        if (d < epsilon || t > MaxMarch)
            break;
        
        stepcount++;
    }
    return d < epsilon;
}

bool ComputeBoxIntersection(float3 ro, float3 rd, in out Shape shape)
{
    float3 BOXTRANSLATION = shape.pos * shape.scale;

    ro += BOXTRANSLATION;

    //Ray Box Intersection
    float3 bmin = float3(0, 0, 0);
    float3 bmax = float3(shape.scale, shape.scale, shape.scale);

    float3 ri = 1.f / rd;
    float3 tbot = ri * (bmin - ro);
    float3 ttop = ri * (bmax - ro);

    shape.tmin = max(max(min(ttop.x, tbot.x), min(ttop.y, tbot.y)), min(ttop.z, tbot.z));
    shape.tmax = min(min(max(ttop.x, tbot.x), max(ttop.y, tbot.y)), max(ttop.z, tbot.z));

    if (shape.tmax < 0 || shape.tmin > shape.tmax)
    {
        //shape.tmin = abs(shape.tmin);
        return true;
    }
    return false;
}

//MAIN

bool GetVoxel(float3 pos, inout float4 color, out uint exitLevel)
{
    bool hazVoxel = false;
    
    uint page = 0; // level of octree offset
    uint NodeP = 0; // particular block position within layer
    uint ChildP = 0; // child position within block
    
    uint3 Bucket3d = { 0, 0, 0 };
    uint Bucket1D = 0;
    
    exitLevel = 0;
    
    if (pos.x > 1.f | pos.x < 0.f) return false;
    if (pos.y > 1.f | pos.y < 0.f) return false;
    if (pos.z > 1.f | pos.z < 0.f) return false;

    [unroll]
    for (uint i = 0; i < 3; i++)
    {
        Bucket3d = uint3(pos *= 2.f); // block position 
        pos -= Bucket3d; // update position for the next layer
        Bucket1D = Bucket3d.x << 2 | Bucket3d.y << 1 | Bucket3d.z; // get morton number of the block
        
        uint index = page + NodeP + ChildP;
        
        uint Vmask = Octree[index].Valid;
        
        hazVoxel = (Vmask & 1 << Bucket1D) ? true : false;
        if (!hazVoxel)
            break;
        
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


[numthreads(N, N, 1)]
void main(uint3 DTid : SV_DispatchThreadID,
	int3 dispatchThreadID : SV_DispatchThreadID)
{
    int2 res;
    gOutput.GetDimensions(res.x, res.y);

    float2 uv = (2.f * dispatchThreadID.xy - (float2) res.xy) / (float2) res.yy;

    float3 ro = PFP.xyz ;
    float3 rd = normalize(float3(uv, 3));

    rd = mul(float4(rd.x, -rd.y, rd.z, 1), ViewMatrix).xyz;
	
    float t = 0.f;
    float4 textureColor = float4(0, 0, 0, 0);
    
    Shape obj;

    obj.pos = float3(0.5, 0.5, 0.5);
    obj.scale = Raymarch_boxScale;
    obj.tmin = 0;
    obj.tmax = 0;
    
    float OCTREE_SCALE = 8.f;
    float3 ri = 1.f / rd;

    //intersect Bounding box
    if (ComputeBoxIntersection(ro, rd, obj))
    {
        textureColor = float4(0, 0, 0, 0);
		gOutput[dispatchThreadID.xy] = textureColor;
        return;
    }

    //transform into box space
    obj.tmin /= obj.scale;
    obj.tmax /= obj.scale;

    //set the ray origin to the box space
    ro = ro + rd * abs(obj.tmin) + obj.pos * obj.scale;

    //normalise to the box space
    ro /= obj.scale;

    //DDA inside the box
    float3 pos = floor((ro) * OCTREE_SCALE);
    float3 rs = sign(rd);
    float3 dis = (pos - (ro * OCTREE_SCALE) + 0.5 + rs * 0.5) * ri;
    float3 mm = float3(0, 0, 0);
    
    float start = 0;
    float end = min(dis.x, min(dis.y, dis.z));
    uint exit_lvl = 0;
   
    obj.tmax = obj.tmax * OCTREE_SCALE;

    int stepcount = 0;
    
    for (int i = 0; i < 64; i++)
    {
        if (end >= obj.tmax)
              break;
        stepcount++;
        
        if (GetVoxel((pos + 0.5) / (OCTREE_SCALE), textureColor, exit_lvl)) // position coinverted into 01 range and contered in an 8th
        {
            float3 marchpos = { 0, 0, 0 };
            
            //textureColor = float4(1, 0, 0, 0);
            //break;
    
            if (Raymarch(rd, ro + rd * start * 0.125f, Volume, (end - start) * 0.125f, marchpos, stepcount))
            {
                break;
            }
           
        }
    
        mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
        dis += mm * rs * ri;
        pos += mm * rs;
        
        
        start = end;
        end = min(dis.x, min(dis.y, dis.z));
    }
    
    getHeatMapColor((float) stepcount / (MAX_STEPS), textureColor.x, textureColor.y, textureColor.z);
	
    gOutput[dispatchThreadID.xy] = textureColor;
}
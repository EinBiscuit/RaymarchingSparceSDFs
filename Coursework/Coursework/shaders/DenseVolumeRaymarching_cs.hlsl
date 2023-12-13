
#include "Scene.hlsli"
#include "OctreeDefs.hlsli"

#define N 16 
#define MAX_SHAPES 3

//BUFFERS

RWTexture2D<float4> gOutput : register(u0);

Texture3D<snorm float> Volume : register(t0);

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



bool Raymarch(float3 rd, float3 ro, Texture3D<snorm float> SDF, float MaxMarch, out float3 pos)
{
    float t = 0;
    float d = 0;
    pos = ro;
    
    for (int i = 0; i < 256; i++)
    {
        d = SDF.SampleLevel(VolumeSampler, pos, 0) / TextureStride;
        t += d;
        
        pos += rd * d;
        if (d < epsilon || t > MaxMarch)
            break;
        
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
        
    float3 marchpos = { 0, 0, 0 };
    
    textureColor = float4(1, 0, 0, 0);
    //break;
    
    if (Raymarch(rd, ro, Volume, obj.tmax, marchpos))
    {
        textureColor = float4(calcNormalVolume(VolumeSampler, Volume, marchpos, NormalBias), 1);
        //textureColor = PhongShading(textureColor, light);
    }
    else
    textureColor = float4(0, 0, 0, 0);



   
	
    gOutput[dispatchThreadID.xy] = textureColor+0.5;
}


#include "Scene.hlsli"
#include "OctreeDefs.hlsli"
// This is the compute shader that generates the volume texture

cbuffer VolumeData : register(b0)
{
    float3 Offset;
    float TextureStride;

    int nodecount;
    int ShapeType;
    float scale;
    int padding;
}

RWTexture3D<snorm float> Volume : register(u0);

[numthreads(1, 1, 1)]
void main( uint3 DTid : SV_DispatchThreadID )
{
	uint3 res;
	Volume.GetDimensions(res.x, res.y, res.z);
	float3 pos = (float3(DTid) / float3(res) - 0.5) * TextureStride;
	Volume[DTid] = Scene(pos, ShapeType, Offset,scale);
}
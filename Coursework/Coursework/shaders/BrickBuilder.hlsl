
#include "Scene.hlsli"
#include "OctreeDefs.hlsli"

cbuffer VolumeData : register(b0)
{
    float3 Offset;
    float stride;

    int nodecount_group;
    int ShapeType;
    
    float scale;
    
    int padding;
}

RWStructuredBuffer<Node> Nodes : register(u1);

RWTexture3D<snorm float> Volume : register(u0);


[numthreads(BLOCK_SIZE,BLOCK_SIZE,1)]
void main(int3 DTid : SV_DispatchThreadID, int3 gid : SV_GroupID, uint3 GID : SV_GroupThreadID, int gidx : SV_GroupIndex)
{
    uint3 StartChunkIdx = coord3D(Nodes[gid.x].Data);

	uint3 res;
    Volume.GetDimensions(res.x, res.y, res.z);


    for (int i = 0; i < BLOCK_SIZE; i++)
    {
        Volume[StartChunkIdx * BLOCK_SIZE + uint3(GID.xy, i)] = Scene((((StartChunkIdx) * BLOCK_SIZE + uint3(GID.xy, i)) / float3(res) - 0.5) * stride, ShapeType,Offset,scale);
       //Volume[StartChunkIdx * BLOCK_SIZE ] = 1;
    }
}
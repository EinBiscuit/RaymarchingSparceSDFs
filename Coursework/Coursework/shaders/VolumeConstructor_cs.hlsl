
#include "Scene.hlsli"
#include "OctreeDefs.hlsli"

cbuffer VolumeData : register(b0)
{
	float3 Offset;
	float stride;
}

StructuredBuffer<Node> IndirectionBuffer : register(t0);
RWTexture3D<float> Volume : register(u1);


[numthreads(BLOCK_SIZE,BLOCK_SIZE,1)]
void main(int3 DTid : SV_DispatchThreadID, int3 gid : SV_GroupID, int3 GID : SV_GroupThreadID, int gidx : SV_GroupIndex)
{
	Node descriptor = IndirectionBuffer[gid.x];

    int chunkID = gid.y;

    uint fidx = descriptor.Desc >> 16;
    
    uint z = fidx / (8 * 8);
    fidx -= z * 8 * 8;
    uint y = fidx / 8;
    uint x = fidx % 8;
    
    uint3 StartChunkIdx = {x, y, z};

	uint3 res;
    Volume.GetDimensions(res.x, res.y, res.z);



    if (((descriptor.Desc & (255 << 8)) >> 8)  & 1 << chunkID)   // adress16 | valid8 | leaf8
    {
        for (int i = 0; i < BLOCK_SIZE; i++)
            Volume[(StartChunkIdx + grid[chunkID]) * 32 + uint3(GID.xy, i)] = Scene((((StartChunkIdx + grid[chunkID]) * 32 + uint3(GID.xy, i)) / float3(res) - 0.5)*stride);
    }
	//else
    //{
    //    for (int i = 0; i < BLOCK_SIZE; i++)
    //        Volume[(StartChunkIdx + grid[chunkID]) * 32 + uint3(GID.xy, i)] = 1;
    //}



}
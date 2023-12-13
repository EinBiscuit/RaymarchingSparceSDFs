
#include "OctreeDefs.hlsli"
#include "Scene.hlsli"

//evaluates level 0 of the scene and outputs a node

groupshared int NodeChildren = 0;

AppendStructuredBuffer<Node> IndirectionTexture : register(u0);
RWTexture3D<float> Volume : register(u1);


globallycoherent RWStructuredBuffer<Node> OctreeRW : register(u2);


cbuffer VolumeData : register(b0)
{
	float3 Offset;
	float stride;
}

[numthreads(2, 2, 2)]
void main( uint3 DTid : SV_DispatchThreadID, uint3 GID : SV_GroupID, uint gidx : SV_GroupIndex)
{
    uint3 res;
    Volume.GetDimensions(res.x, res.y, res.z);

	uint cubeindex = 0;


	for (int i = 0; i < 8; i++)
	{
 
        float3 pos = (float3((DTid + grid[i]) * 32) / res - 0.5) * stride;

        if (Scene(pos) < 0.01f)
        {
            cubeindex++;
        }
    }

    if (cubeindex != 0 && cubeindex < 8)
	{
        InterlockedOr(NodeChildren, 1 << gidx); // chunk id

        //Node leaf;
        //leaf.Desc = 1 << (8 + gidx) | 1 << gidx; // mark leaf and
        //leaf.Data = (DTid.x + DTid.y * 8 + DTid.z * 8 * 8);
    }

	GroupMemoryBarrierWithGroupSync();

	if (gidx != 0) return;

    float3 p = float3((DTid) * 32) / res - 0.5; // debug point
    Volume[DTid * 32] = Scene(p);               // debug point
	Node n;
    n.Desc = (DTid.x + DTid.y * 8 + DTid.z * 8 * 8) << 16 | NodeChildren << 8 | 255; // pointer in grid  // adress16 | valid8 | leaf8
    n.Data = 0;
    n.Leaf = 0;
    n.Valid = 0;

	IndirectionTexture.Append(n); //unordered

    n.Data = morton3D(GID.x, GID.y, GID.z);

    OctreeRW[morton3D(GID.x, GID.y, GID.z)] = n; // ordered

  //  OctreeRW[GID.x+GID.y*4+GID.z*4*4] = n;
}
#include "OctreeDefs.hlsli"
//#include "Scene.hlsli"

//evaluates level 0 of the scene and outputs a node

cbuffer VolumeData : register(b0)
{
    float3 Offset;
    float stride;

    int nodecount_group;
    int3 padding;
}

groupshared uint counts[2][512];
groupshared uint MortonCodes[512];
groupshared uint validmasks[512];

RWStructuredBuffer<Node> OctreeRW : register(u1);

[numthreads(OCTREE_BUILDER_GP_SIZE, OCTREE_BUILDER_GP_SIZE, OCTREE_BUILDER_GP_SIZE)]
void main(uint3 DTid : SV_DispatchThreadID, uint3 GID : SV_GroupID, uint gidx : SV_GroupIndex)
{
    MortonCodes[gidx] = 0;
    counts[0][gidx] = 0;
    counts[1][gidx] = 0;
    validmasks[gidx] = 0;
    
    if (gidx < nodecount_group)
        MortonCodes[gidx] = OctreeRW[gidx].Data;

    GroupMemoryBarrierWithGroupSync();

   // OctreeRW[gidx].Data = 0;
    
    uint ParentMask = 7 << 6;
    uint ChildMask = 7 << 3;

    uint offset = 0;
    uint bucketlocation = 0;

    if (gidx < nodecount_group)
    InterlockedOr(validmasks[bucketlocation], 1 << ((MortonCodes[gidx] & ParentMask) >> 6)); // for level 0 mark all

    // for levels 1 and 2

    uint dest = 0;

    for (uint i = 0; i < 2; i++)
    {
        ParentMask >>= i * 3; //shift mask by 3 for next 3
        ParentMask |= (7 << 6); // keep original start point set

        ChildMask >>= i * 3; //child mask just shifts only level bellow current parent is required

        offset += pow(8, i); //advance to next bitty
        
        if (gidx < nodecount_group) {
            bucketlocation = ((MortonCodes[gidx] & ParentMask) >> 6-3*i) + offset; // get correct parent for the level location
            InterlockedAdd(counts[dest][bucketlocation], 1); // count eggs
   //       InterlockedAdd(OctreeRW[bucketlocation].Data, 1); // debug the eggs
            InterlockedOr(validmasks[bucketlocation], 1 << ((MortonCodes[gidx] & ChildMask) >> (3-i*3))); // convert child to from global bucket to local bucket
        }

        uint f = offset; // offset                    // scan algorithm vaariables
        uint inpt = 8 * pow(8,i);                     // input power 8  1, 8, 64, 256 etc.

        for (int j = 1; j < inpt; j *= 2)             
        {
            GroupMemoryBarrierWithGroupSync();
            counts[dest^i][gidx + f] = counts[dest][gidx + f];
            if (gidx >= j && gidx < inpt)
                counts[dest ^ i][gidx + f] += counts[dest][gidx + f - j];
            dest ^= i;                               //xor i for xor layer processed & 1 so that log input power (even odd even odd) doesnt disrupt double buffered scan
        }
    }

    GroupMemoryBarrierWithGroupSync(); // octree done
    if (validmasks[gidx])
    {
        OctreeRW[gidx].Desc = counts[dest][gidx];
        OctreeRW[gidx].Valid = validmasks[gidx];
     
    }
}

#include "OctreeDefs.hlsli"
#include "Scene.hlsli"

//evaluates level 0 of the scene and outputs a node
RWTexture3D<snorm float> Volume : register(u0);
RWStructuredBuffer<Node> ValidNodes : register(u1);


cbuffer VolumeData : register(b0)
{ 
    float3 Offset;
    float TextureStride;

    int nodecount;
    int ShapeType;
    
    float scale;
    int padding;
}

groupshared uint vIDs[512];
groupshared int appendcount = 0;

[numthreads(8,8,8)]
void main(uint3 DTid : SV_DispatchThreadID, uint3 GID : SV_GroupID, uint gidx : SV_GroupIndex)
{
    uint3 res = {TEXTURE_SIZE,TEXTURE_SIZE,TEXTURE_SIZE};
    
    Node Null = { 0, 0, 0, 0 };
    
    ValidNodes[gidx] = Null;

	uint cubeindex = 0;

    Node leaf = {0,0,0,0};

    uint morton = 0;
    
    float3 pos = ((float3(DTid * BLOCK_SIZE) + 0.5 * BLOCK_SIZE) / res - 0.5) * TextureStride; // center of a block
    
    bool node_valid = abs(Scene(pos, ShapeType, Offset, scale)) < 1.5f; // sqrt(2)
    
    if (node_valid)
    {   
        morton = morton3D(DTid.x, DTid.y, DTid.z);
   
        uint address = ValidNodes.IncrementCounter();
   
        vIDs[address] = morton; // for sorting
   
        InterlockedAdd(appendcount, 1);
   
        leaf.Desc = 0; //(morton % 8); // mark leaf and valid  and address in 3d texture
        leaf.Data = morton; // store positional index
    }
        
    GroupMemoryBarrierWithGroupSync();
    
    if (!node_valid) return;
    
    uint sorted_address = 0;
    
    for (int i = 0; i < appendcount; i++)
    {
        if (morton > vIDs[i])
            sorted_address++;
    }
    
    GroupMemoryBarrierWithGroupSync();
    
    ValidNodes[sorted_address] = leaf;


    // Do not cry eat cake and be tipsy  UWU (Jordan x)
}
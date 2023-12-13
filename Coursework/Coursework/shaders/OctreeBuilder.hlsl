
#include "OctreeDefs.hlsli"
//#include "Scene.hlsli"

//evaluates level 0 of the scene and outputs a node

//RWTexture3D<float> Volume : register(u0);

cbuffer VolumeData : register(b0)
{
	float3 Offset;
	float stride;

    int nodecount_group;
    int3 padding;
}

groupshared Node MortonCodes[OCTREE_BUILDER_GP_SIZE * OCTREE_BUILDER_GP_SIZE * OCTREE_BUILDER_GP_SIZE];
groupshared uint counts[512];
groupshared uint scratch[512];
groupshared uint morton[512];
groupshared uint validmasks[512];

RWStructuredBuffer<Node> OctreeRW : register(u1);

[numthreads(OCTREE_BUILDER_GP_SIZE, OCTREE_BUILDER_GP_SIZE, OCTREE_BUILDER_GP_SIZE)]
void main(uint3 DTid : SV_DispatchThreadID, uint3 GID : SV_GroupID, uint gidx : SV_GroupIndex)
{
	uint nodecount = nodecount_group;

	uint Child_mask = 7;    //0b 000 000 111
	uint Parent_mask = ~Child_mask; //0b 111 111 000 

	uint f = 0;
	uint i = 8 * 8;

	uint offset = 1 + 8 + 64;

	Node null = { 0, 0, 0, 0 };

	counts[gidx] = 0;
	validmasks[gidx] = 0;
	scratch[gidx] = 0;
	morton[gidx] = 0;

	if (gidx < nodecount)
	{
		morton[gidx] = OctreeRW[gidx].Data;
	}

	GroupMemoryBarrierWithGroupSync();

	[unroll(2)]
	for (int level = 0; level < 2; level++)
	{
		counts[gidx] = 0;
		validmasks[gidx] = 0;
		scratch[gidx] = 0;

		uint parentbucket = morton[gidx] & Parent_mask;

		if (gidx < nodecount)
		{
			if (gidx == 0)
			{
				counts[(parentbucket >> 3)] = gidx;
			}
			else if ((morton[gidx - 1] & Parent_mask) != parentbucket)
			{
				counts[(parentbucket >> 3)] = gidx;
			}
			InterlockedOr(validmasks[(parentbucket >> 3)], 1 << (morton[gidx] & Child_mask));
		}

		GroupMemoryBarrierWithGroupSync();

		if (validmasks[gidx]) // if node has valid children
		{
			scratch[gidx] = 1; // mark node for compression
		}
		else
			scratch[gidx] = 0;

		GroupMemoryBarrierWithGroupSync();

		for (int j = 1; j < i; j *= 2)                 //the dull not double buffered memory version
		{
			GroupMemoryBarrierWithGroupSync();
			uint temp = scratch[gidx];
			if (gidx >= j && gidx < i)
				temp += scratch[gidx - j];
			GroupMemoryBarrierWithGroupSync();
			scratch[gidx] = temp;
		}

		uint tempVM = validmasks[gidx];
		uint tempC = counts[gidx];
		uint tempMorton = morton[counts[gidx]];

		GroupMemoryBarrierWithGroupSync();

		if (validmasks[gidx]) /// perfrom stream compression 
		{
			validmasks[scratch[gidx] - 1] = tempVM;
			counts[scratch[gidx] - 1] = tempC;
			morton[scratch[gidx] - 1] = tempMorton >> 3; //  store parent start node

		}

		GroupMemoryBarrierWithGroupSync();

		//COPY TO GLOBAL MEMORY;
		if (gidx < scratch[i - 1])
		{
			OctreeRW[gidx + offset - i].Desc = counts[gidx];
			OctreeRW[gidx + offset - i].Data = morton[gidx];
			OctreeRW[gidx + offset - i].Valid = validmasks[gidx];
			if (!level) OctreeRW[gidx + offset - i].Leaf = validmasks[gidx];
		}

		nodecount = scratch[i - 1];
		offset -= i;
		i /= 8;
	}

	if (gidx < nodecount)
	{
		InterlockedOr(OctreeRW[0].Valid, 1 << (morton[gidx] & Child_mask));
	}

	if (gidx == 0)
	{
		OctreeRW[0].Desc = GID;
		OctreeRW[0].Data = 0;
	}

	return;
}
	
//Graveyard


	//if (gidx < nodecount)
	//{
	//	MortonCodes[gidx] = OctreeRW[gidx];
    //}
	//
    //    counts[gidx] = 0;
	//validmasks[gidx] = 0;
	//
	//GroupMemoryBarrierWithGroupSync();
	//
	////Level 0
   	//
	//uint Parent_mask = 504; //0b 111 111 000 
	//uint Child_mask = 7;    //0b 000 000 111
	//
	//uint parentbucket = MortonCodes[gidx].Data & Parent_mask;
	//
	//uint f = 0; // offset                    // scan algorithm vaariables
	//uint i = 8*8; // 8 inputsize;
	//uint iterations = 0;
	////
	//uint index = i;
	//
	//if (gidx < nodecount)
	//{  
	//	if ((MortonCodes[gidx - 1].Data & Parent_mask) != parentbucket);
	//	{
	//		counts[(parentbucket >> 3)] = gidx;
	//	}
	//	InterlockedOr(validmasks[(parentbucket >> 3)], 1 << (MortonCodes[gidx].Data & Child_mask));
	//}
	//
	//// STREAM COMPRESSION
	//
	//GroupMemoryBarrierWithGroupSync();
	//
	//if (validmasks[gidx]) // if node has valid children
	//{
	//	InterlockedAdd(counts[0], 1); // count the children
	//	scratch[gidx] = 1; // mark node for compression
	//}
	//else
	//	scratch[gidx] = 0;
	//
	//GroupMemoryBarrierWithGroupSync();
	//
	//
	//for (int j = 1; j < i; j *= 2)                 //the dull not double buffered memory version
	//{
	//	GroupMemoryBarrierWithGroupSync();
	//	uint temp = scratch[gidx + f];
	//	if (gidx >= j && gidx < i)
	//		temp += scratch[gidx + f - j];
	//	GroupMemoryBarrierWithGroupSync();
	//	scratch[gidx + f] = temp;
	//}
	//
	//GroupMemoryBarrierWithGroupSync();
	//
	//if (validmasks[gidx]) /// perform stream compression 
	//{
	//	//POTENTIAL RACE CONDITION?
	//	uint tempVM = validmasks[gidx];
	//	uint tempC = counts[gidx];
	//	uint tempMorton = MortonCodes[counts[gidx]].Data;
	//
	//	GroupMemoryBarrier();
	//
	//	validmasks[scratch[gidx]] = tempVM;
	//	counts[scratch[gidx]] = tempC;
    //    OctreeRW[scratch[gidx]-1].Data = tempMorton>>3; //  store parent start node
	//
    //}
	//
	//GroupMemoryBarrierWithGroupSync();
	//
	////COPY TO GLOBAL MEMORY;
	//
	//OctreeRW[gidx-1].Desc = counts[gidx];
	//OctreeRW[gidx-1].Valid = validmasks[gidx];
	//OctreeRW[gidx-1].Leaf = validmasks[gidx]; // leaf and valid masks are the same on the bottom level
	//
	////LEVEL bellow  ie 1 // could be next dispatch technically
	//
    //nodecount = counts[0];
	//
    //if (gidx < nodecount)
    //{
    //    MortonCodes[gidx] = OctreeRW[gidx];
    //}
	//
    //counts[gidx] = 0;
    //validmasks[gidx] = 0;
    //scratch[gidx] = 0;
	//
    //GroupMemoryBarrierWithGroupSync();
	//
	////Level 1
   	//
    //Parent_mask = 56; //0b 111 000 
    //Child_mask = 7; //0b 000 111
	//
    //parentbucket = (MortonCodes[gidx].Data) & Parent_mask;
	//
    //f = 0; // offset                    // scan algorithm vaariables
    //i = 8; // 8 inputsize;
    //iterations = 0;
	////
    //index = i;
	//
    //if (gidx < nodecount)
    //{
    //    if (((MortonCodes[gidx - 1].Data) & Parent_mask)  != parentbucket);
	//	{
    //        counts[(parentbucket >> 3)] = gidx;
    //    }
    //    InterlockedOr(validmasks[(parentbucket >> 3)], 1 << (MortonCodes[gidx].Data & Child_mask));
    //}
	//
	//// STREAM COMPRESSION
	//
    //GroupMemoryBarrierWithGroupSync();
	//
    //if (validmasks[gidx]) // if node has valid children
    //{
    //    InterlockedAdd(counts[0], 1); // count the children
    //    scratch[gidx] = 1; // mark node for compression
    //}
    //else
    //    scratch[gidx] = 0;
	//
    //GroupMemoryBarrierWithGroupSync();
	//
	////kogge stone Scan; for stream compression
	//
    //for (int j = 1; j < i; j *= 2)                 //the dull not double buffered memory version
    //{
    //    GroupMemoryBarrierWithGroupSync();
    //    uint temp = scratch[gidx + f];
    //    if (gidx >= j && gidx < i)
    //        temp += scratch[gidx + f - j];
    //    GroupMemoryBarrierWithGroupSync();
    //    scratch[gidx + f] = temp;
    //}
	//
    //GroupMemoryBarrierWithGroupSync();
	//
    //if (validmasks[gidx]) /// perform stream compression 
    //{
	//	//POTENTIAL RACE CONDITION?
    //    uint tempVM = validmasks[gidx];
    //    uint tempC = counts[gidx];
    //    uint tempMorton = MortonCodes[counts[gidx]].Data;
	//
    //    GroupMemoryBarrier();
	//
    //    validmasks[scratch[gidx]] = tempVM;
    //    counts[scratch[gidx]] = tempC;
    //    OctreeRW[scratch[gidx]-1].Data = tempMorton>>3; // & Parent_mask; // store parent start node
    //}
	//
    //GroupMemoryBarrierWithGroupSync();
	//
	////COPY TO GLOBAL MEMORY;
	//
    //OctreeRW[gidx-1].Desc = counts[gidx];
    //OctreeRW[gidx-1].Valid = validmasks[gidx];
    //OctreeRW[gidx].Leaf = validmasks[gidx]; // leaf and valid masks are the same on the bottom level
	
	
	// CODE GRAVEY YARD 2.0


	//if (gidx < nodecount)
	//{
	//	//(counts[(parentbucket >> 6)+1], 1); // counts number of children in a bucket
    //    //if ((MortonCodes[gidx - 1].Data & Parent_mask) != parentbucket);
    //    //{
    //    //    counts[(parentbucket >> 6) + 1] = gidx; // gives  address of first element to change the parent // effective child countl;
    //    //}
    //    InterlockedOr(validmasks[0], 1 << (parentbucket >> 6));//mark parent
	//	InterlockedOr(validmasks[(parentbucket >> 6) + 1], 1 << ((MortonCodes[gidx].Data & Child_mask) >> 3));//mark child
    //}
    //GroupMemoryBarrierWithGroupSync();
	//
    //if (gidx < nodecount)
    //{
    //    if ((MortonCodes[gidx - 1].Data & Parent_mask) != parentbucket);
    //    {
    //        counts[(parentbucket >> 6) + 2] = bitsSet(validmasks[(parentbucket >> 6) + 1]);
    //    }
    //}
	//
    //GroupMemoryBarrierWithGroupSync();
	////Small kogge stone Scan; exclusive
	//

	//while (index >>= 1)
	//    ++iterations; // log2(inputsize)
	//
	//for (int j = 1; j < i; j*=2)
	//{
	//    GroupMemoryBarrierWithGroupSync();
	//    uint temp = counts[gidx + f];
	//    if (gidx >= j && gidx < i)
	//        temp += counts[gidx+f - j];
	//	GroupMemoryBarrierWithGroupSync();
	//    counts[gidx+f] = temp;
	//}
	//
	//GroupMemoryBarrierWithGroupSync();
	

//	
//    if (gidx < nodecount)
//    {
//        if ((MortonCodes[gidx - 1].Data & Parent_mask) != parentbucket);
//        {
//           counts[counts[(parentbucket >> 3) + 2 + 8]] = bitsSet(validmasks[(parentbucket >> 3) + 1 + 8]);
//        }
//    }
//	
    
	
	
	
    //OctreeRW[gidx].Desc = scratch[gidx];
	////reduction to the rescue; naive first
	//for (int s = 1; s < nodecount; s *=2)1
    //{
	//	//int index = 2 * s * gidx;
	//	
	//	//if (index < nodecount)
	//	//MortonCodes[index].Desc += MortonCodes[index + s].Desc;
	//	
    //    if ((MortonCodes[index - 1].Data & Parent_mask) == parentbucket)
    //    {
	//		
    //    }
	//	
    //}
    //for (int i = 0; i < 3; i++)
    //{
    //    if (index < nodecount)
    //        if ((MortonCodes[index - 1].Data & Parent_mask) == parentbucket)
    //        {
    //            MortonCodes[index - 1].Desc += MortonCodes[index].Desc;
    //        }
    //}
	
   
//for (int i = 0; i < 3; i++) // MAX SUBDIVISIONS TILL REACH BOTTOM LEVEL
//{
//
//}
	//uint maxLevel = 3;
	//uint level = GID.x;
	//uint startNode = 0;
	//uint NodeCount = 0;
	//static const uint Mask = 7; //111
   	//
	//nodeCounts[gidx] = 0;
   	//
	//uint subnodeCounts[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
   	//
	//for (int i = 0; i < nodecount; i++)
	//{
 	//
	//	if ((OctreeRW[i].Data & (Mask << 6)) == (gidx << 6))
	//	{
	//		nodeCounts[gidx]++;
	//		subnodeCounts[(OctreeRW[i].Data & (Mask << 3)) >> 3]++;
	//	}
	//}
   	//
	//GroupMemoryBarrierWithGroupSync();
   	//
	//uint descaddress = 0;
   	//
	//for (int i = 0; i < gidx; i++)
	//{
	//	descaddress += nodeCounts[i];
	//}
   	//
	//OctreeRW[descaddress].Desc = nodeCounts[gidx]; //Count
   	//
	//uint subdescaddress = 1;
   	//
	//for (int i = 0; i < 8; i++)
	//{
	//	if (subnodeCounts[i])
	//	{
    //     // OctreeRW[descaddress].Desc = subnodeCounts[i];
   	//
	//		OctreeRW[descaddress + subdescaddress].Desc = subnodeCounts[i];
	//	}
	//	subdescaddress += subnodeCounts[i];
	//}

   //GroupMemoryBarrierWithGroupSync();

   ////level bellow
   //
   //uint subnodeCounts[8];
   //uint subdescAddress = descaddress+1;
   //
   //for(int i=0;i<8;i++)
   //{
   //    subnodeCounts[i] = 0;
//    for(int j = 0;j<nodeCounts[gidx];j++)
//    {
   //        if ((OctreeRW[i].Data & (Mask << 3)) == (i << 3))
   //        {
   //            subnodeCounts[i]++;
   //        }
//    }
   //}

	//}
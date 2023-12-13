#include "Scene.hlsli"


struct VertexType
{
    float3 position;
    float2 tex;
    float3 normal;
};

struct Triangle
{
    VertexType tri[3];
};

cbuffer  Params : register(b0)
{
    float isolevel;
    int gridSize;
    float gridStride;
    int SampleMode;
    
    float4 OffsetScale;

    int ShapeType;
    float3 Padding;
};    

AppendStructuredBuffer<Triangle> outTri : register(u0);
Texture2D<int> tri_Table : register(cs,t0);
Texture1D<int> edge_Table : register(cs,t1);

Texture3D<float> Brick : register(cs, t2);

SamplerState VolumeSampler : register(cs, s0);


float3 VertexInterp(float isolevel, float3 p1, float3 p2,float valp1, float valp2)
{
    float mu;
    float3 p;

    if (abs(isolevel-valp1) < 0.00001f)
        return(p1);
    if (abs(isolevel-valp2) < 0.00001f)
        return(p2);
    if (abs(valp1-valp2) < 0.00001f)
        return(p1);
    mu = (isolevel - valp1) / (valp2 - valp1);
    p.x = p1.x + mu * (p2.x - p1.x);
    p.y = p1.y + mu * (p2.y - p1.y);
    p.z = p1.z + mu * (p2.z - p1.z);

    return(p);
}

float3 TriangulateNormal(Triangle input)
{
    float3 v1 = normalize(input.tri[0].position - input.tri[1].position);
    float3 v2 = normalize(input.tri[0].position - input.tri[2].position);
    return normalize(cross(v2, v1));
}


[numthreads(1, 1, 1)]
void main(uint3 DTid : SV_DispatchThreadID,
    int3 dispatchThreadID : SV_DispatchThreadID)
{

    //debug

    //Triangle T;
    //
    //int a  = tri_Table[uint2(1,1)];
    //int b  = edge_Table[1];
    //    
	////T.tri[0].position = (float3(0, 0, 0) + ((dispatchThreadID + int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride;
    ////T.tri[1].position = (float3(0, -1, 0) + ((dispatchThreadID + int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride;
    ////T.tri[2].position = (float3(1, 0, 0) + ((dispatchThreadID + int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride;
    //
    //T.tri[0].position = (float3(0, 0, 0) + ((dispatchThreadID + int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride+float3(0.5f,0.5f,0.5f);
    //T.tri[1].position = (float3(0, -1, 0) + ((dispatchThreadID +int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride+float3(0.5f,0.5f,0.5f);
    //T.tri[2].position = (float3(1, 0, 0) + ((dispatchThreadID + int3(0, 0, 1) - int3(gridSize, 0, 0).xxx) / 2)) * gridStride+float3(0.5f,0.5f,0.5f);
    //
    //int line1[16];
    //
    //for (int i = 0; i < 16; i++)
    //{
    //    line1[i] = tri_Table[uint2(i,3)];
    //}
    //
	//T.tri[0].normal = float3(line1[0],line1[1],line1[2]);
    //T.tri[1].normal = float3(line1[3],line1[4],line1[5]);
    //T.tri[2].normal = float3(line1[6],line1[7],line1[8]);
    //
    //T.tri[0].tex = float2(line1[9], line1[10]);
    //T.tri[1].tex = float2(line1[11], line1[12]);
    //T.tri[2].tex = float2(line1[13], line1[14]);
    //
    //
    //
	//outTri.Append(T);
    //return;
    //
    //
    //MARGING CUBBEES

    float3 vertlist[12];
  
    float3 grid[8];
    float samples[8];

 
    grid[0] = ((float3) (dispatchThreadID) + (float3(-0.5f, -0.5f, 0.5f))  - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[1] = ((float3) (dispatchThreadID) + (float3(0.5f, -0.5f, 0.5f))   - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[2] = ((float3) (dispatchThreadID) + (float3(0.5f, -0.5f, -0.5f))  - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[3] = ((float3) (dispatchThreadID) + (float3(-0.5f, -0.5f, -0.5f)) - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[4] = ((float3) (dispatchThreadID) + (float3(-0.5f, 0.5f, 0.5f))   - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[5] = ((float3) (dispatchThreadID) + (float3(0.5f, 0.5f, 0.5f))    - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[6] = ((float3) (dispatchThreadID) + (float3(0.5f, 0.5f, -0.5f))   - float3(gridSize, 0, 0).xxx / 2) * gridStride;
    grid[7] = ((float3) (dispatchThreadID) + (float3(-0.5f, 0.5f, -0.5f))  - float3(gridSize, 0, 0).xxx / 2) * gridStride;



    [branch]
    if(SampleMode==0)
    {
        for (int i = 0; i < 8; i++)
        {
            samples[i] = Scene(grid[i],ShapeType,OffsetScale.xyz,OffsetScale.w);
        }
    }
    else
    {

        for (int i = 0; i < 8; i++)
        {
            samples[i] = Brick.SampleLevel(VolumeSampler, grid[i] / (gridStride * gridSize) + float3(0.5,0.5,0.5), 0);

        }
    }


  
    int cubeindex = 0;

    for (int i = 0; i < 8; i++)
    {
        if (samples[i] < isolevel)
            cubeindex |= 1 << i;
    }
  
    if (edge_Table[cubeindex] == 0)
        return;
    
    /* Find the vertices where the surface intersects the cube */
    if (edge_Table[cubeindex] & 1)
        vertlist[0] =
           VertexInterp(isolevel,grid[0],grid[1],samples[0],samples[1]);
    if (edge_Table[cubeindex] & 2)
        vertlist[1] =
           VertexInterp(isolevel,grid[1],grid[2],samples[1],samples[2]);
    if (edge_Table[cubeindex] & 4)
        vertlist[2] =
           VertexInterp(isolevel,grid[2],grid[3],samples[2],samples[3]);
    if (edge_Table[cubeindex] & 8)
        vertlist[3] =
           VertexInterp(isolevel,grid[3],grid[0],samples[3],samples[0]);
    if (edge_Table[cubeindex] & 16)
        vertlist[4] =
           VertexInterp(isolevel,grid[4],grid[5],samples[4],samples[5]);
    if (edge_Table[cubeindex] & 32)
        vertlist[5] =
           VertexInterp(isolevel,grid[5],grid[6],samples[5],samples[6]);
    if (edge_Table[cubeindex] & 64)
        vertlist[6] =
           VertexInterp(isolevel,grid[6],grid[7],samples[6],samples[7]);
    if (edge_Table[cubeindex] & 128)
        vertlist[7] =
           VertexInterp(isolevel,grid[7],grid[4],samples[7],samples[4]);
    if (edge_Table[cubeindex] & 256)
        vertlist[8] =
           VertexInterp(isolevel,grid[0],grid[4],samples[0],samples[4]);
    if (edge_Table[cubeindex] & 512)
        vertlist[9] =
           VertexInterp(isolevel,grid[1],grid[5],samples[1],samples[5]);
    if (edge_Table[cubeindex] & 1024)
        vertlist[10] =
           VertexInterp(isolevel,grid[2],grid[6],samples[2],samples[6]);
    if (edge_Table[cubeindex] & 2048)
        vertlist[11] =
           VertexInterp(isolevel,grid[3],grid[7],samples[3],samples[7]);
    
  
  /* Create the triangle */  //COPY PASTING IN PROGRESS
    //ntriang = 0;
    for (int i=0;tri_Table[uint2(i,cubeindex)]!=-1;i+=3)
    {
        Triangle tri;
        tri.tri[0].position = vertlist[tri_Table[uint2(i  ,cubeindex)]];
        tri.tri[1].position = vertlist[tri_Table[uint2(i+1,cubeindex)]];
        tri.tri[2].position = vertlist[tri_Table[uint2(i+2,cubeindex)]];

        float3 normal = TriangulateNormal(tri);

        tri.tri[0].normal = normal;
        tri.tri[1].normal = normal;
        tri.tri[2].normal = normal;
        
        tri.tri[0].tex = float2(0,0);
        tri.tri[1].tex = float2(0,0);
        tri.tri[2].tex = float2(0,0);
        
        outTri.Append(tri);
    
        if (i > 16)
            break;
    }
   
}

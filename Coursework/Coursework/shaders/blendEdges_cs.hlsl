// Horizontal compute blurr, based on Frank Luna's example.

Texture2D<float4> gInput : register(t0);
Texture2D<float4> gInputEdgeN : register(t1);
Texture2D<float4> gInputEdgeD: register(t2);
Texture2D<float4> gInputEdgeO: register(t3);

SamplerState InputSample : register(s0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer params : register(b0)
{
    float ow;
    float nw;
    float dw;
    float strength;
    
    int uniformColour;
    float3 colour;
}

#define N 16 

[numthreads(N, N, 1)]
void main(int3 groupThreadID : SV_GroupThreadID,
	int3 dispatchThreadID : SV_DispatchThreadID)
{    
    uint2 Length;
    gInput.GetDimensions(Length.x, Length.y);
    
    float texStepX = 1.f / Length.x;
    float texStepY = 1.f / Length.y;
    
    float2 texCoord = float2(texStepX * dispatchThreadID.x, texStepY * dispatchThreadID.y);
    
    //apply weights
    float4 Original = gInputEdgeO.SampleLevel(InputSample, texCoord, 0) * ow;
    float4 Normals = gInputEdgeN.SampleLevel(InputSample, texCoord, 0) * nw;
    float4 Depth = gInputEdgeD.SampleLevel(InputSample, texCoord, 0) * dw;
    
    float4 Input = gInput.SampleLevel(InputSample, texCoord, 0);

    //blend 3 edges
    
    float4 blend = sqrt((Original * Original + Normals * Normals + Depth * Depth) / (ow + nw + dw));
    
    //if uniform colour extract max brightness
    if (uniformColour)
    {
        float brightness = max(max(blend.x, blend.y), blend.z);
        
        //move colour to -1 1
        float3 diff = colour * 2 - 1;
        
        blend = float4(diff * brightness,1);
    }
  
    gOutput[dispatchThreadID.xy] = Input + (blend * strength);
    
    }
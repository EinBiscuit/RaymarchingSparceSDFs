// Horizontal compute blurr, based on Frank Luna's example.

Texture2D<float4> gInputG : register(t0);
Texture2D<float4> gInputD : register(t1);


SamplerState InputSample : register(s0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer params : register(b0)
{
    float min;
    float amplify;
    float2 pad;
}

#define N 16 
#define pi 3.14159265

[numthreads(N, N, 1)]
void main(int3 groupThreadID : SV_GroupThreadID,
	int3 dispatchThreadID : SV_DispatchThreadID)
{    
    uint2 Length;
    gInputG.GetDimensions(Length.x, Length.y);
    
    float texStepX = 1.f / Length.x;
    float texStepY = 1.f / Length.y;
    
    float2 texCoord = float2(texStepX * dispatchThreadID.x, texStepY * dispatchThreadID.y);
    
    float4 G = gInputG.SampleLevel(InputSample, texCoord, 0);

    float4 D = gInputD.SampleLevel(InputSample, texCoord, 0);
    
    //amplify or deamplify the coolour;
    G *= (amplify + 1);
    
    //for each colour
    for (int i = 0; i<4 ;i++)
    {
        float2 texDir;
        
        texDir.x = cos(D[i]) * texStepX;
        texDir.y = sin(D[i]) * texStepY;
        
        float4 nbPos = gInputD.SampleLevel(InputSample, texCoord + texDir, 0);
        float4 nbNeg = gInputD.SampleLevel(InputSample, texCoord - texDir, 0);
        
        if (G[i] < nbPos[i] || G[i] < nbNeg[i]) // if gradient is not a local maximum in the gradient direction remnove it
        {
            G[i] = 0;
        }
        
        //apply minimum
        if (G[i] < min) G[i] = 0;
    
    }
  
    gOutput[dispatchThreadID.xy] = G;
    
    }
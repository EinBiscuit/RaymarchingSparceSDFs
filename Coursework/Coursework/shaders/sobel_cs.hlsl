// Horizontal compute blurr, based on Frank Luna's example.

// Blur weightings
cbuffer cbSettings
{   
    static float3x3 SobelGx = // apply transpose for Gy
    {
       1,0,-1,
       2,0,-2,
       1,0,-1,
    };
    
    static float3x3 EdgeDetect = // comparison experimets
    {
       0, -1,  0,
       -1, 4, -1,
       0, -1,  0,
    };
    
};

Texture2D<float4> gInput : register(t0);

SamplerState InputSample : register(s0);
RWTexture2D<float4> gOutputG : register(u0);
RWTexture2D<float4> gOutputD : register(u1);


cbuffer params : register(b0)
{
    float4 params;
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
    
    float4 Gx = float4(0, 0, 0, 0);
    float4 Gy = float4(0, 0, 0, 0);
    
    float3x3 SobelGy = transpose(SobelGx);
    
    
   // int2 pixP = dispatchThreadID.xy;
    
    [unrol]
    for (int i = 0; i < 3; i++)
    {
        for (int j = 0; j < 3; j++)
        {
            float2 texCoord = float2(texStepX * (dispatchThreadID.x + i - 1), texStepY * (dispatchThreadID.y + j - 1));
            
            float4 inputSampl = gInput.SampleLevel(InputSample, texCoord, 0.f);
            
            Gx += SobelGx[j][i] * inputSampl;
            Gy += SobelGy[j][i] * inputSampl;

        }
    };
    
    
    // [unrol]
    //for (int y = 0; y < 3; y++)
    //{
    //    for (int x = 0; x < 3; x++)
    //    {
    //        float2 texCoord = float2(texStepX * (dispatchThreadID.x + x - 1), texStepY * (dispatchThreadID.y + y - 1));
    //        Gy += EdgeDetect[x][y] * gInput.SampleLevel(InputSample, texCoord, 0.f);
    //    }
    //};
    
    gOutputG[dispatchThreadID.xy] = sqrt(Gx * Gx + Gy * Gy); //Gx ...experiments
    gOutputD[dispatchThreadID.xy] = atan2(Gy,Gx);            //Gy

}
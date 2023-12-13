// Horizontal compute blurr, based on Frank Luna's example. edited to be dynamic

// peh
cbuffer cbSettings
{
    static float pi = 3.1415926535;
};

cbuffer blurParams : register(b0)
{
    int gBlurRadius;
    float deviation;
    float2 pad;
}

//in out
Texture2D gInput : register(t0);
RWTexture2D<float4> gOutput : register(u0);

#define N 256
#define CacheSize (N + 2*10) // 10 is maximum blur
groupshared float4 gCache[CacheSize];

[numthreads(N, 1, 1)]
void main(int3 groupThreadID : SV_GroupThreadID,
	int3 dispatchThreadID : SV_DispatchThreadID)
{
	//
	// Fill local thread storage to reduce bandwidth.  To blur 
	// N pixels, we will need to load N + 2*BlurRadius pixels
	// due to the blur radius.
	//

	// This thread group runs N threads.  To get the extra 2*BlurRadius pixels, 
	// have 2*BlurRadius threads sample an extra pixel.
    
   // 
    uint2 Length;
    gInput.GetDimensions(Length.x, Length.y);
    
    if (groupThreadID.x < gBlurRadius)
    {
		// Clamp out of bound samples that occur at image borders.
        int x = max(dispatchThreadID.x - gBlurRadius, 0);
        gCache[groupThreadID.x] = gInput[int2(x, dispatchThreadID.y)];
    }
    if (groupThreadID.x >= N - gBlurRadius)
    {
    	// Clamp out of bound samples that occur at image borders. // shader model five does have length ?! y oink
        int x = min(dispatchThreadID.x + gBlurRadius, Length.x - 1);
        gCache[groupThreadID.x + 2 * gBlurRadius] = gInput[int2(x, dispatchThreadID.y)];
    }
   
	// Clamp out of bound samples that occur at image borders.
    gCache[groupThreadID.x + gBlurRadius] = gInput[min(dispatchThreadID.xy, Length.xy - 1)];
   
	// Wait for all threads to finish.
    GroupMemoryBarrierWithGroupSync();
    
	// Now blur each pixel.
    float4 blurColor = float4(0, 0, 0, 0);
	//[unroll]
    for (int i = -gBlurRadius; i <= gBlurRadius; ++i)
    {
        int k = groupThreadID.x + gBlurRadius + i;
        //Gaussian function
        float weight = 1.f / (deviation * sqrt(2 * pi)) * exp(-0.5 * ((i * i) / (deviation * deviation)));
        
        blurColor += weight * gCache[k]*gCache[k];
    }

    gOutput[dispatchThreadID.xy] = sqrt(blurColor);
}
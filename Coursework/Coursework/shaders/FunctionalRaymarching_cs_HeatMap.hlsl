
#include "Scene.hlsli"

#define N 16 
#define FAR 10000.f
//BUFFERS

RWTexture2D<float4> gOutput : register(u0);

cbuffer Camera : register(b0)
{
    float4 PFP;
    matrix ViewMatrix;
    Light light;
    int ShapeType;
    float epsilon;
    float TextureStride; // in space
    float NormalBias;

    float4 ObjectTranslationScale;
    float3 Rotation;

    float Raymarch_boxScale;
};

//MAIN

[numthreads(N, N, 1)]
void main( uint3 DTid : SV_DispatchThreadID,
	int3 dispatchThreadID : SV_DispatchThreadID )
{
	int2 res;
	gOutput.GetDimensions(res.x, res.y);

	float2 uv = (2.f * dispatchThreadID.xy - (float2)res.xy) / (float2)res.yy;

	float3 ro = PFP.xyz;
	float3 rd = normalize(float3(uv,3));

	rd = mul(float4(rd.x,-rd.y,rd.z,1),ViewMatrix).xyz;
	
	float t = 0.f;

	float4 colour = float4(0, 0, 0, 1);

    int colorsteps = 0;
	

    for (int i = 0; i < MAX_STEPS;i++)
	{
		float3 pos = ro + rd * t;

        float h = Scene(pos, ShapeType, ObjectTranslationScale.xyz, ObjectTranslationScale.w);
		
        if (h < epsilon)
            break;
			
		t += h;

		if(t > FAR) break;
		
		colorsteps++;
		
	}

    float3 n = (0,0,0);

	if (t < FAR)
	{
		float3 pos = ro + rd * t;
		//float3 n;

		// + float3(0.5, 0, -0.5).xxz

        n = calcNormal(pos, NormalBias, ShapeType, ObjectTranslationScale.xyz, ObjectTranslationScale.w);
       
		//n = PhongShading(n,light);

	}
	
    float value = (float) colorsteps / MAX_STEPS;
	
    float4 sComplexity = float4(0,0,0,1);
    
    getHeatMapColor(value, sComplexity.x, sComplexity.y, sComplexity.z);
    
   
	
	
	
    gOutput[dispatchThreadID.xy] = sComplexity; //float4(n,1);
}


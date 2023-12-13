// Texture pixel/fragment shader
// Basic fragment shader for rendering textured geometry


#include "OctreeDefs.hlsli"

// Texture and sampler registers
Texture3D<snorm float> texture0 : register(t0);

StructuredBuffer<Node> Octree : register(t1);

SamplerState Sampler0 : register(s0);

#include "Scene.hlsli"

struct InputType
{
	float4 position : SV_POSITION;
	float3 tex : TEXCOORD0;
	float4 worldPos : TEXCOORD1;
};

cbuffer Control : register(b0)
{
    float4 PFP;
    matrix ViewMatrix;
    Light light;
    int ShapeType;
    float epsilon;
    float TextureStride; // in space
    float NormalBias;

    float Raymarch_boxScale;

    float3 Translation;
    float3 Rotation;
    float3 Scale;
};

#define FAR 1.f

bool Raymarch(float3 rd, float3 ro, Texture3D<snorm float> SDF, float MaxMarch, out float3 pos)
{
    float t = 0;
	float d = 0;
	pos = ro;
    
    for (int i = 0; i < MAX_STEPS; i++)
    {
        d = SDF.SampleLevel(Sampler0, pos, 0) / TextureStride;
		t += d;
		if (d < epsilon || t>MaxMarch) break;
		pos += rd * d;
    }
    return d < epsilon;
}

float4 main(InputType input) : SV_TARGET
{

	float3 ro = input.tex.xyz;

    float3 rd = normalize(input.worldPos.xyz - PFP.xyz);
	
    float4 textureColor = float4(0, 0, 0, 0);

    float3 ri = 1.f / rd;
    float3 rs = sign(rd);
   
    float3 maxRI = abs(ri);
    float t_max = min(maxRI.x, min(maxRI.y, maxRI.z));
    
	float3 n = float3(0, 0, 0);

    if (Raymarch(rd, ro, texture0, t_max, n))
    {
        textureColor = float4(calcNormalVolume(Sampler0, texture0, n, NormalBias), 1);
    }
    
    //textureColor = float4(texture0.SampleLevel(Sampler0,ro + rd * max_dist,0),0,0, 1);

	//float3 n;
	// 
	//if (t < FAR)
	//{
    //    float3 pos = ro + rd * (t);
	//
	//    n = calcNormalVolume(Sampler0, texture0, pos, epsilon);
    //    ////n = calcNormal(pos,epsilon);
	//	textureColor = PhongShading(n, light);
    //}

    //return (input.tex.xyz + rd * epsilon).xyzz;
    //return float4(input.tex.xyz,1);
	return textureColor;

}
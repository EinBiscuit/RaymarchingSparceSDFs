
struct Light
{
    float4 direction;
    float4 colour;
};

cbuffer LightBuffer : register(b0)
{
    Light light;
}

struct InputType
{
    float4 position : SV_POSITION;
    float2 tex : TEXCOORD0;
    float3 normal : NORMAL;
};

float4 PhongShading(float3 normal, Light light)
{
    return dot(normalize(-light.direction.xyz), normal) * light.colour;
}

float4 main(InputType input) : SV_TARGET
{
   // return PhongShading(input.normal, light);
    return float4(input.normal+0.5,1);
}
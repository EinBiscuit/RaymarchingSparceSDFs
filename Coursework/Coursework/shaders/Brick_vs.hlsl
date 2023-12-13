// texture vertex shader
// Basic shader for rendering textured geometry

cbuffer MatrixBuffer : register(b0)
{
	matrix worldMatrix;
	matrix viewMatrix;
	matrix projectionMatrix;
};

struct InputType
{
	float4 position : POSITION;
	float3 tex : TEXCOORD0;
};

struct OutputType
{
	float4 position : SV_POSITION;
	float3 tex : TEXCOORD0;
	float4 worldPos : TEXCOORD1;
};

OutputType main(InputType input)
{
	OutputType output;

	// Calculate the position of the vertex against the world, view, and projection matrices.
	output.position = mul(input.position, worldMatrix);

	//world pos
    output.worldPos = output.position;

	// view pos 
	output.position = mul(output.position, viewMatrix);

	// proj pos
	output.position = mul(output.position, projectionMatrix);

	// Store the texture coordinates for the pixel shader.
	output.tex = input.tex;


	

	return output;
}
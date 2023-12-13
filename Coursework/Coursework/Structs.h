#pragma once

struct VolumeData
{
    XMFLOAT3 BrickOffset;
    float stride;

    int NodeCount;
    int ShapeType;
	float scale;

	int padding;
};

struct LightData
{
	XMFLOAT4 LightDir;
	XMFLOAT4 LightColour;
};

struct Control
{
	XMFLOAT4 PFP;
	XMMATRIX ViewMatrix;
	LightData Light;
	int ShapeType;
	float epsilon;
	float TextureStride; // in space
	float normalbias;

	XMFLOAT4 ObjectTranslationScale;
	XMFLOAT3 Rotation;

	float Raymarch_boxScale;
};

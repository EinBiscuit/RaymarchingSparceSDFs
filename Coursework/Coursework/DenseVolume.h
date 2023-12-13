#pragma once
#include "DXF.h"

class DenseVolume
{
	ID3D11ShaderResourceView* VolumeSRV;
	ID3D11UnorderedAccessView* VolumeUAV;

	ID3D11Buffer* CBuffer;
	ID3D11Texture3D* Volume;

	ID3D11ComputeShader* ConstructShader;

public:
	DenseVolume(ID3D11Device* device, HWND hwnd, int size);
	~DenseVolume();
	ID3D11ShaderResourceView* GetTextureSRV() { return VolumeSRV; };
	ID3D11UnorderedAccessView* GetTexturUAV() { return VolumeUAV; };
	void Construct(ID3D11DeviceContext*, int stride = 1, int OBJtype = 0, XMFLOAT3 Offset = { 0,0,0 }, float scale = 1);
	UINT VolumeSize = 256;
};


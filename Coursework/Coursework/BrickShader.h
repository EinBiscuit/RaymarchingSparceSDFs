#pragma once

#include "BaseShader.h"
#include "RaymarchingCompute.h"

using namespace std;
using namespace DirectX;

class BrickShader : public BaseShader
{
public:
	BrickShader(ID3D11Device* device, HWND hwnd);
	~BrickShader();

	void setShaderParameters(ID3D11DeviceContext* deviceContext, const XMMATRIX& world, const XMMATRIX& view, const XMMATRIX& projection, ID3D11ShaderResourceView* Volume, ID3D11ShaderResourceView* Octree, Control* s);
	void loadUnitVertexShader(const wchar_t*);

private:
	void initShader(const wchar_t* vs, const wchar_t* ps);

private:
	ID3D11Buffer * matrixBuffer;
	ID3D11SamplerState* sampleState;

	ID3D11Buffer* controlBuffer;
};




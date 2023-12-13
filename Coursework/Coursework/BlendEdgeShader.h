#pragma once
#include "DXF.h"

struct EdgeBufferType
{
	float normalWeight;
	float depthWeight;
	float originalWeight;
	float outlineStrenght;

	int UniformColour;
	XMFLOAT3 colour;
};

class BlendEdgeShader :
    public BaseShader
{
public:
	BlendEdgeShader(ID3D11Device* device, HWND hwnd, int w, int h);
	~BlendEdgeShader();

	void setShaderParameters(ID3D11DeviceContext* dc, XMFLOAT4 Weights, XMFLOAT3 outlineColour, bool uniformColour , ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* Edge0, ID3D11ShaderResourceView* Edge1, ID3D11ShaderResourceView* Edge2);
	void createOutputUAV();
	ID3D11ShaderResourceView* getSRV() { return m_srvTexOutput; };
	void unbind(ID3D11DeviceContext* dc);

private:
	void initShader(const wchar_t* cfile, const wchar_t* blank);

	// texture set
	ID3D11Texture2D* m_tex;
	ID3D11UnorderedAccessView* m_uavAccess;
	ID3D11ShaderResourceView* m_srvTexOutput;

	ID3D11Buffer* paramBuffer;

	int sWidth;
	int sHeight;

	ID3D11SamplerState* samplerState;
};


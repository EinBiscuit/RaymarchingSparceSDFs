#pragma once
#include "DXF.h"

struct BufferType
{
	float min; //min threshold
	float amplify;
	XMFLOAT2 pad;
};

class EdgeThinShader :
    public BaseShader
{
public:
	EdgeThinShader(ID3D11Device* device, HWND hwnd, int w, int h);
	~EdgeThinShader();

	void setShaderParameters(ID3D11DeviceContext* dc, float min, float amplify, ID3D11ShaderResourceView* SobelG, ID3D11ShaderResourceView* SobelD);
	void createOutputUAV();
	ID3D11ShaderResourceView* getSRV() { return m_srvTexOutput; };
	void unbind(ID3D11DeviceContext* dc);

private:
	void initShader(const wchar_t* cfile, const wchar_t* blank);

	ID3D11ShaderResourceView* srv;
	ID3D11UnorderedAccessView* uav;

	// texture set
	ID3D11Texture2D* m_tex;
	ID3D11UnorderedAccessView* m_uavAccess;
	ID3D11ShaderResourceView* m_srvTexOutput;

	ID3D11Buffer* paramBuffer;

	int sWidth;
	int sHeight;

	ID3D11SamplerState* samplerState;
};


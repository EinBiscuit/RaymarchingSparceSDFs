#pragma once
#include "DXF.h"
class SobelShader :
    public BaseShader
{
public:
	SobelShader(ID3D11Device* device, HWND hwnd, int w, int h);
	~SobelShader();

	void setShaderParameters(ID3D11DeviceContext* dc, ID3D11ShaderResourceView* inputTexture);
	void createOutputUAV();
	ID3D11ShaderResourceView* getSRVG() { return m_srvTexOutputG; };
	ID3D11ShaderResourceView* getSRVD() { return m_srvTexOutputD; };
	void unbind(ID3D11DeviceContext* dc);

private:
	void initShader(const wchar_t* cfile, const wchar_t* blank);

	ID3D11ShaderResourceView* srv;
	ID3D11UnorderedAccessView* uav;

	// texture set
	//edge gradient
	ID3D11Texture2D* m_texG;
	ID3D11UnorderedAccessView* m_uavAccessG;
	ID3D11ShaderResourceView* m_srvTexOutputG;

	//edge direction
	ID3D11Texture2D* m_texD;
	ID3D11UnorderedAccessView* m_uavAccessD;
	ID3D11ShaderResourceView* m_srvTexOutputD;

	int sWidth;
	int sHeight;

	ID3D11SamplerState* samplerState;
};


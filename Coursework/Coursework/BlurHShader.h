#pragma once
#include "DXF.h"
class BlurHShader :
    public BaseShader
{
public:
	BlurHShader(ID3D11Device* device, HWND hwnd, int w, int h);
	~BlurHShader();

	void setShaderParameters(ID3D11DeviceContext* dc, int size, float deviation, ID3D11ShaderResourceView* texture0);
	void createOutputUAV();
	ID3D11ShaderResourceView* getSRV() { return m_srvTexOutput; };
	void unbind(ID3D11DeviceContext* dc);

	struct BlurBuff
	{
		int size;
		float deviation;

		XMFLOAT2 pad;
	};

private:
	void initShader(const wchar_t* cfile, const wchar_t* blank);

	ID3D11ShaderResourceView* srv;
	ID3D11UnorderedAccessView* uav;

	// texture set
	ID3D11Texture2D* m_tex;
	ID3D11UnorderedAccessView* m_uavAccess;
	ID3D11ShaderResourceView* m_srvTexOutput;

	int sWidth;
	int sHeight;

	ID3D11Buffer* blurbuff;
};


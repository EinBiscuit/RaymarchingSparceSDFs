#include "SobelShader.h"

SobelShader::SobelShader(ID3D11Device* device, HWND hwnd, int w, int h) : BaseShader(device, hwnd)
{
	sWidth = w;
	sHeight = h;
	initShader(L"sobel_cs.cso", NULL);
}

SobelShader::~SobelShader()
{

}

void SobelShader::initShader(const wchar_t* cfile, const wchar_t* blank)
{
	loadComputeShader(cfile);
	createOutputUAV();

	D3D11_SAMPLER_DESC samplerDesc;

	// Create a texture sampler state description.
	samplerDesc.Filter = D3D11_FILTER::D3D11_FILTER_MIN_MAG_MIP_POINT;
	samplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.MipLODBias = 0.0f;
	samplerDesc.ComparisonFunc = D3D11_COMPARISON_NEVER;
	samplerDesc.MinLOD = 0;
	samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;
	renderer->CreateSamplerState(&samplerDesc, &sampleState);
}

void SobelShader::createOutputUAV()
{
	D3D11_TEXTURE2D_DESC textureDesc;
	ZeroMemory(&textureDesc, sizeof(textureDesc));
	textureDesc.Width = sWidth;
	textureDesc.Height = sHeight;
	textureDesc.MipLevels = 1;
	textureDesc.ArraySize = 1;
	textureDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
	textureDesc.SampleDesc.Count = 1;
	textureDesc.SampleDesc.Quality = 0;
	textureDesc.Usage = D3D11_USAGE_DEFAULT;
	textureDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
	textureDesc.CPUAccessFlags = 0;
	textureDesc.MiscFlags = 0;
	m_texG = 0;
	m_texD = 0;
	renderer->CreateTexture2D(&textureDesc, 0, &m_texG);

	D3D11_UNORDERED_ACCESS_VIEW_DESC descUAV;
	ZeroMemory(&descUAV, sizeof(descUAV));
	descUAV.Format = DXGI_FORMAT_R32G32B32A32_FLOAT; ;// DXGI_FORMAT_UNKNOWN;
	descUAV.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
	descUAV.Texture2D.MipSlice = 0;
	renderer->CreateUnorderedAccessView(m_texG, &descUAV, &m_uavAccessG);

	D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
	srvDesc.Format = textureDesc.Format;
	srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	srvDesc.Texture2D.MostDetailedMip = 0;
	srvDesc.Texture2D.MipLevels = 1;
	renderer->CreateShaderResourceView(m_texG, &srvDesc, &m_srvTexOutputG);

	renderer->CreateTexture2D(&textureDesc, 0, &m_texD);
	renderer->CreateUnorderedAccessView(m_texD, &descUAV, &m_uavAccessD);
	renderer->CreateShaderResourceView(m_texD, &srvDesc, &m_srvTexOutputD);
}

void SobelShader::setShaderParameters(ID3D11DeviceContext* dc, ID3D11ShaderResourceView* inputTexture)
{
	dc->CSSetShaderResources(0, 1, &inputTexture);

	dc->CSSetUnorderedAccessViews(0, 1, &m_uavAccessG, 0);
	dc->CSSetUnorderedAccessViews(1, 1, &m_uavAccessD, 0);
	dc->CSSetSamplers(0, 1, &samplerState);
}

void SobelShader::unbind(ID3D11DeviceContext* dc)
{
	ID3D11ShaderResourceView* nullSRV[] = { NULL };
	dc->CSSetShaderResources(0, 1, nullSRV);

	// Unbind output from compute shader
	ID3D11UnorderedAccessView* nullUAV[] = { NULL };
	dc->CSSetUnorderedAccessViews(0, 1, nullUAV, 0);
	dc->CSSetUnorderedAccessViews(1, 1, nullUAV, 0);

	ID3D11SamplerState* nullSAMPL[] = { NULL };
	dc->CSSetSamplers(0, 1, nullSAMPL);

	// Disable Compute Shader
	dc->CSSetShader(nullptr, nullptr, 0);
}
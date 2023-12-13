#include "BlendEdgeShader.h"

BlendEdgeShader::BlendEdgeShader(ID3D11Device* device, HWND hwnd, int w, int h) : BaseShader(device, hwnd)
{
	sWidth = w;
	sHeight = h;
	initShader(L"blendEdges_cs.cso", NULL);
}

BlendEdgeShader::~BlendEdgeShader()
{

}

void BlendEdgeShader::initShader(const wchar_t* cfile, const wchar_t* blank)
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
	HRESULT result = renderer->CreateSamplerState(&samplerDesc, &sampleState);

	D3D11_BUFFER_DESC bufferDesc;

	bufferDesc.Usage = D3D11_USAGE_DYNAMIC;
	bufferDesc.ByteWidth = sizeof(EdgeBufferType);
	bufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	bufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	bufferDesc.MiscFlags = 0;
	bufferDesc.StructureByteStride = 0;

	renderer->CreateBuffer(&bufferDesc,NULL, &paramBuffer);

}

void BlendEdgeShader::createOutputUAV()
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
	m_tex = 0;
	renderer->CreateTexture2D(&textureDesc, 0, &m_tex);

	D3D11_UNORDERED_ACCESS_VIEW_DESC descUAV;
	ZeroMemory(&descUAV, sizeof(descUAV));
	descUAV.Format = DXGI_FORMAT_R32G32B32A32_FLOAT; ;// DXGI_FORMAT_UNKNOWN;
	descUAV.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
	descUAV.Texture2D.MipSlice = 0;
	renderer->CreateUnorderedAccessView(m_tex, &descUAV, &m_uavAccess);

	D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
	srvDesc.Format = textureDesc.Format;
	srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	srvDesc.Texture2D.MostDetailedMip = 0;
	srvDesc.Texture2D.MipLevels = 1;
	renderer->CreateShaderResourceView(m_tex, &srvDesc, &m_srvTexOutput);
}

void BlendEdgeShader::setShaderParameters(ID3D11DeviceContext* dc, XMFLOAT4 Weights, XMFLOAT3 outlineColour, bool uniformColour, ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* Edge1, ID3D11ShaderResourceView* Edge2, ID3D11ShaderResourceView* Edge3)
{
	dc->CSSetShaderResources(0, 1, &input);
	dc->CSSetShaderResources(1, 1, &Edge1);
	dc->CSSetShaderResources(2, 1, &Edge2);
	dc->CSSetShaderResources(3, 1, &Edge3);

	D3D11_MAPPED_SUBRESOURCE mappedResource;

	dc->Map(paramBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);
	EdgeBufferType* dataPtr = (EdgeBufferType*)mappedResource.pData;

	dataPtr->normalWeight = Weights.x;
	dataPtr->depthWeight = Weights.y;
	dataPtr->originalWeight = Weights.z;
	dataPtr->outlineStrenght = Weights.w;
	dataPtr->colour = outlineColour;
	dataPtr->UniformColour = uniformColour;

	dc->CSSetUnorderedAccessViews(0, 1, &m_uavAccess, 0);
	dc->CSSetSamplers(0, 1, &samplerState);

	dc->Unmap(paramBuffer,0);
	dc->CSSetConstantBuffers(0, 1, &paramBuffer);
}

void BlendEdgeShader::unbind(ID3D11DeviceContext* dc)
{
	ID3D11ShaderResourceView* nullSRV[] = { NULL };
	dc->CSSetShaderResources(0, 1, nullSRV);
	dc->CSSetShaderResources(1, 1, nullSRV);
	dc->CSSetShaderResources(2, 1, nullSRV);
	dc->CSSetShaderResources(3, 1, nullSRV);


	// Unbind output from compute shader
	ID3D11UnorderedAccessView* nullUAV[] = { NULL };
	dc->CSSetUnorderedAccessViews(0, 1, nullUAV, 0);

	ID3D11SamplerState* nullSAMPL[] = { NULL };
	dc->CSSetSamplers(0, 1, nullSAMPL);

	// Disable Compute Shader
	dc->CSSetShader(nullptr, nullptr, 0);
}
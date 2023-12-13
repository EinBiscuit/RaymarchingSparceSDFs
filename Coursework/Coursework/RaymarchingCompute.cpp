#include "RaymarchingCompute.h"
#include "StaticHelpers.h"

RaymarchingCompute::RaymarchingCompute(ID3D11Device* device, HWND hwnd, int w, int h) : BaseShader(device,hwnd)
{
	sWidth = w;
	sHeight = h;
	initShader(L"sample_raymarching_cs.cso", NULL);

	loadComputeShader(L"OctreeRaymarching_cs.cso", OctreeRaymarching);
	loadComputeShader(L"FunctionalRaymarching_cs.cso", FunctionalRaymarching);
	loadComputeShader(L"DenseVolumeRaymarching_cs.cso", VolumeRaymarching);

	loadComputeShader(L"OctreeRaymarching_cs_HeatMap.cso",     OctreeRaymarching_HeatMap);
	loadComputeShader(L"FunctionalRaymarching_cs_HeatMap.cso", FunctionalRaymarching_HeatMap);
	loadComputeShader(L"DenseVolumeRaymarching_cs_HeatMap.cso",VolumeRaymarching_HeatMap);
}

RaymarchingCompute::~RaymarchingCompute()
{

}

void RaymarchingCompute::initShader(const wchar_t* cfile, const wchar_t* blank)
{
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
	bufferDesc.ByteWidth = sizeof(Control);
	bufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	bufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	bufferDesc.MiscFlags = 0;
	bufferDesc.StructureByteStride = 0;

	renderer->CreateBuffer(&bufferDesc, NULL, &paramBuffer);
}

void RaymarchingCompute::setShaderParameters(ID3D11DeviceContext* dc, Control* params, RENDERMODE RM, ID3D11ShaderResourceView* Volume, ID3D11ShaderResourceView* Octree, ID3D11SamplerState* VolumeSampler, bool Heatmap)
{
	D3D11_MAPPED_SUBRESOURCE mappedResource;

	if(FAILED(dc->Map(paramBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource))) throw std::exception();
	Control* dataPtr = (Control*)mappedResource.pData;

	//i love to live dangerously
	memcpy(dataPtr,params,sizeof(Control));

	dc->Unmap(paramBuffer, 0);

	//switch on Rendermode and heatmap
	if(Heatmap)
	switch (RM)
	{
	case RENDERMODE::FUNCTION:
			dc->CSSetShader(FunctionalRaymarching_HeatMap, NULL, 0);
			break;
	case RENDERMODE::OCTREE:
			dc->CSSetShader(OctreeRaymarching_HeatMap, NULL, 0);
			dc->CSSetShaderResources(1, 1, &Octree);
			break;
	case RENDERMODE::VOLUME:
			dc->CSSetShader(VolumeRaymarching_HeatMap, NULL, 0);
			break;
		default:
			break;
	}
	else
	switch (RM)
	{
	case RENDERMODE::FUNCTION:
		dc->CSSetShader(FunctionalRaymarching, NULL, 0);
		break;
	case RENDERMODE::OCTREE:
		dc->CSSetShader(OctreeRaymarching, NULL, 0);
		dc->CSSetShaderResources(1, 1, &Octree);
		break;
	case RENDERMODE::VOLUME:
		dc->CSSetShader(VolumeRaymarching, NULL, 0);
		break;
	default:
		break;
	}
	
	dc->CSSetUnorderedAccessViews(0, 1, &m_uavAccess, 0);
	dc->CSSetShaderResources(0, 1, &Volume);
	
	dc->CSSetSamplers(0,1,&VolumeSampler);
	dc->CSSetConstantBuffers(0, 1, &paramBuffer);
}

void RaymarchingCompute::createOutputUAV()
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

void RaymarchingCompute::unbind(ID3D11DeviceContext* dc)
{
	// Unbind output from compute shader
	ID3D11UnorderedAccessView * nullUAV[] = { NULL };
	dc->CSSetUnorderedAccessViews(0, 1, nullUAV, 0);

	ID3D11SamplerState* nullSAMPL[] = { NULL };
	dc->CSSetSamplers(0, 1, nullSAMPL);

	// Disable Compute Shader
	dc->CSSetShader(nullptr, nullptr, 0);
}


						
#include "DenseVolume.h"
#include "StaticHelpers.h"
#include "Structs.h"

DenseVolume::DenseVolume(ID3D11Device* device, HWND hwnd, int size)
{
	loadComputeShader(device, hwnd, L"DenseVolume_cs.cso", ConstructShader);

	//Parameter Buffer
	D3D11_BUFFER_DESC cbufferDesc;

	cbufferDesc.Usage = D3D11_USAGE_DYNAMIC;
	cbufferDesc.ByteWidth = sizeof(VolumeData);
	cbufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	cbufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	cbufferDesc.MiscFlags = 0;
	cbufferDesc.StructureByteStride = 0;

	device->CreateBuffer(&cbufferDesc, NULL, &CBuffer);

	//Volume

	DXGI_FORMAT FORMAT = DXGI_FORMAT_R8_SNORM;

	D3D11_TEXTURE3D_DESC volumeDesc;

	ZeroMemory(&volumeDesc, sizeof(D3D11_TEXTURE3D_DESC));

	volumeDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
	volumeDesc.Width = volumeDesc.Height = volumeDesc.Depth = VolumeSize;
	volumeDesc.Usage = D3D11_USAGE_DEFAULT;
	volumeDesc.MipLevels = 1;
	volumeDesc.Format = FORMAT;

	if (FAILED(device->CreateTexture3D(&volumeDesc, NULL, &Volume)))throw std::exception();

	D3D11_SHADER_RESOURCE_VIEW_DESC vSRVDesc;

	ZeroMemory(&vSRVDesc, sizeof(D3D11_SHADER_RESOURCE_VIEW_DESC));

	vSRVDesc.Format = FORMAT;
	vSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE3D;
	vSRVDesc.Texture3D.MipLevels = 1;
	vSRVDesc.Texture3D.MostDetailedMip = 0;

	if (FAILED(device->CreateShaderResourceView(Volume, &vSRVDesc, &VolumeSRV)))throw std::exception();

	D3D11_UNORDERED_ACCESS_VIEW_DESC vUAVDesc;

	ZeroMemory(&vUAVDesc, sizeof(D3D11_UNORDERED_ACCESS_VIEW_DESC));

	vUAVDesc.Format = FORMAT;
	vUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE3D;
	vUAVDesc.Texture3D.MipSlice = 0;
	vUAVDesc.Texture3D.FirstWSlice = 0;
	vUAVDesc.Texture3D.WSize = volumeDesc.Depth;

	if (FAILED(device->CreateUnorderedAccessView(Volume, &vUAVDesc, &VolumeUAV)))throw std::exception();
}

DenseVolume::~DenseVolume()
{
	VolumeSRV->Release();
	VolumeUAV->Release();
	Volume->Release();
	ConstructShader->Release();
}

void DenseVolume::Construct(ID3D11DeviceContext* dc, int stride, int OBJtype, XMFLOAT3 Offset, float scale)
{
	D3D11_MAPPED_SUBRESOURCE mappedResource;

	dc->Map(CBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);
	VolumeData* dataPtr = (VolumeData*)mappedResource.pData;

	//i love to live dangerously

	ZeroMemory(dataPtr, sizeof(VolumeData));

	dataPtr->stride = stride;
	dataPtr->BrickOffset = Offset;
	dataPtr->ShapeType = OBJtype;
	dataPtr->scale = scale;

	dc->Unmap(CBuffer, 0);

	dc->CSSetShader(ConstructShader,NULL,NULL);
	dc->CSSetConstantBuffers(0, 1, &CBuffer);
	dc->CSSetUnorderedAccessViews(0, 1, &VolumeUAV, NULL);

	//construct
	dc->Dispatch(VolumeSize, VolumeSize, VolumeSize);


	//unbind
	ID3D11UnorderedAccessView* nullUAV[] = { NULL,NULL };
	dc->CSSetUnorderedAccessViews(0, 2, nullUAV, 0);

	ID3D11ShaderResourceView* nullSrv[] = { NULL };
	dc->CSSetShaderResources(0, 1, nullSrv);

	// Disable Compute Shader
	dc->CSSetShader(nullptr, nullptr, 0);
}

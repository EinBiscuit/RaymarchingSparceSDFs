#include "SparseVolume.h"

SparseVolume::SparseVolume(ID3D11Device* d, HWND hwnd, int VSize = 256) : BaseShader(d,hwnd)
{
	VolumeSize = VSize;
	initShader(L"BrickBuilder.cso", L"BrickEvaluator.cso");

	loadComputeShader(L"BrickBuilder.cso", BrickBuilder);
}

void SparseVolume::Construct(ID3D11DeviceContext* dc, int stride, int OBJtype, XMFLOAT3 Offset, float scale)
{

	setShaderParameters(dc, stride,Offset, OBJtype, scale);

	dc->CSSetShader(BrickEvaluator, 0, 0);
	dc->Dispatch(1, 1, 1 );

	dc->CopyStructureCount(DispatchArgsBuffer, 0, OctreeNodeUAV);
	dc->CopyStructureCount(paramBuffer, 16, OctreeNodeUAV); //populate node count int constant buffer

	dc->CSSetShader(computeShader, NULL, 0);
	dc->DispatchIndirect(DispatchArgsBuffer,0);

	dc->CSSetShader(OctreeBuilder, NULL, 0);
	dc->Dispatch(1, 1, 1);

	unbind(dc);
}

void SparseVolume::initShader(const wchar_t* cfile, const wchar_t* blank)
{
	loadComputeShader(cfile);
	loadComputeShader(blank, BrickEvaluator);
//	loadComputeShader(L"SimpleOctree.cso", OctreeBuilder);
	loadComputeShader(L"OctreeBuilder.cso", OctreeBuilder);

	DXGI_FORMAT FORMAT = DXGI_FORMAT_R8_SNORM; 

	//ParameterBuffer
	D3D11_BUFFER_DESC cbufferDesc;

	cbufferDesc.Usage = D3D11_USAGE_DYNAMIC;
	cbufferDesc.ByteWidth = sizeof(VolumeData);
	cbufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	cbufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	cbufferDesc.MiscFlags = 0;
	cbufferDesc.StructureByteStride = 0;

	renderer->CreateBuffer(&cbufferDesc, NULL, &paramBuffer);

	D3D11_BUFFER_DESC argBufferDesc;

	argBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	argBufferDesc.ByteWidth = sizeof(UINT)*3;
	argBufferDesc.BindFlags = 0;
	argBufferDesc.CPUAccessFlags = 0;
	argBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_DRAWINDIRECT_ARGS;
	argBufferDesc.StructureByteStride = 0;

	UINT default[3] = {1,1,1};

	D3D11_SUBRESOURCE_DATA def;

	def.pSysMem = default;

	if (FAILED(renderer->CreateBuffer(&argBufferDesc, &def, &DispatchArgsBuffer)))throw std::exception();

	D3D11_TEXTURE3D_DESC volumeDesc;

	ZeroMemory(&volumeDesc, sizeof(D3D11_TEXTURE3D_DESC));

	volumeDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
	volumeDesc.Width = volumeDesc.Height = volumeDesc.Depth = VolumeSize;
	volumeDesc.Usage = D3D11_USAGE_DEFAULT;
	volumeDesc.MipLevels = 1;
	volumeDesc.Format = FORMAT;

	if (FAILED(renderer->CreateTexture3D(&volumeDesc, NULL, &Volume)))throw std::exception();

	D3D11_SHADER_RESOURCE_VIEW_DESC vSRVDesc;

	ZeroMemory(&vSRVDesc, sizeof(D3D11_SHADER_RESOURCE_VIEW_DESC));

	vSRVDesc.Format = FORMAT;
	vSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE3D;
	vSRVDesc.Texture3D.MipLevels = 1;
	vSRVDesc.Texture3D.MostDetailedMip = 0;

	if (FAILED(renderer->CreateShaderResourceView(Volume, &vSRVDesc, &VolumeSRV)))throw std::exception();

	D3D11_UNORDERED_ACCESS_VIEW_DESC vUAVDesc;

	ZeroMemory(&vUAVDesc, sizeof(D3D11_UNORDERED_ACCESS_VIEW_DESC));

	vUAVDesc.Format = FORMAT;
	vUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE3D;
	vUAVDesc.Texture3D.MipSlice = 0;
	vUAVDesc.Texture3D.FirstWSlice = 0;
	vUAVDesc.Texture3D.WSize = volumeDesc.Depth;

	if(FAILED(renderer->CreateUnorderedAccessView(Volume, &vUAVDesc, &VolumeUAV)))throw std::exception();

	D3D11_SAMPLER_DESC v_sampler_desc;

	ZeroMemory(&v_sampler_desc, sizeof(v_sampler_desc));

	v_sampler_desc.AddressU = v_sampler_desc.AddressV = v_sampler_desc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;

	v_sampler_desc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
	v_sampler_desc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
	v_sampler_desc.MaxAnisotropy = 1;
	v_sampler_desc.MinLOD = 0;
	v_sampler_desc.MaxLOD = D3D11_FLOAT32_MAX;

	if (FAILED(renderer->CreateSamplerState(&v_sampler_desc, &VolumeSampler))) throw std::exception();


	// APPEND BUFFER vertex size
	D3D11_BUFFER_DESC abufferdesc;
	ZeroMemory(&abufferdesc, sizeof(abufferdesc));
	
	abufferdesc.ByteWidth = 1024 * sizeof(Node);
	abufferdesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	abufferdesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
	abufferdesc.StructureByteStride = sizeof(Node);
	abufferdesc.Usage = D3D11_USAGE_DEFAULT;
	abufferdesc.CPUAccessFlags = 0;
	
	if (FAILED(renderer->CreateBuffer(&abufferdesc, NULL, &Octree))) throw std::exception();

	D3D11_BUFFER_SRV srv;
	// srv
	srv.FirstElement = 0;
	srv.ElementWidth = sizeof(Node);
	srv.NumElements = 1024;
	
	D3D11_SHADER_RESOURCE_VIEW_DESC descSRV;
	ZeroMemory(&descSRV, sizeof(descSRV));
	
	descSRV.Format = DXGI_FORMAT_UNKNOWN;
	descSRV.Buffer = srv;
	descSRV.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;

	D3D11_BUFFER_UAV BlockUAV;
	//APPEND UAV
	BlockUAV.FirstElement = 0;
	BlockUAV.NumElements = 1024;
	BlockUAV.Flags = D3D11_BUFFER_UAV_FLAG_COUNTER;

	D3D11_UNORDERED_ACCESS_VIEW_DESC descBlockUAV;
	ZeroMemory(&descBlockUAV, sizeof(descBlockUAV)); 

	descBlockUAV.Format = DXGI_FORMAT_UNKNOWN;
	descBlockUAV.Buffer = BlockUAV;
	descBlockUAV.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;

	if (FAILED(renderer->CreateUnorderedAccessView(Octree, &descBlockUAV, &OctreeNodeUAV))) throw std::exception();

	if (FAILED(renderer->CreateShaderResourceView(Octree, &descSRV, &OctreeNodeSRV))) throw std::exception();
}


void SparseVolume::setShaderParameters(ID3D11DeviceContext* dc, float stride, XMFLOAT3 Offset, int ShapeType, float scale)
{
	D3D11_MAPPED_SUBRESOURCE mappedResource;

	dc->Map(paramBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);
	VolumeData* dataPtr = (VolumeData*)mappedResource.pData;


	ZeroMemory(dataPtr, sizeof(VolumeData));

	dataPtr->stride = stride;
	dataPtr->BrickOffset = Offset;
	dataPtr->ShapeType = ShapeType;
	dataPtr->scale = scale;

	dc->Unmap(paramBuffer, 0);

	dc->CSSetSamplers(0, 1, &VolumeSampler);

	dc->CSSetConstantBuffers(0, 1, &paramBuffer);

	UINT CountStart = 0;

	dc->CSSetUnorderedAccessViews(1, 1, &OctreeNodeUAV, &CountStart);

	dc->CSSetUnorderedAccessViews(0, 1, &VolumeUAV,NULL);

}

void SparseVolume::unbind(ID3D11DeviceContext* dc)
{
	// Unbind output from compute shader
	ID3D11UnorderedAccessView* nullUAV[] = { NULL,NULL };
	dc->CSSetUnorderedAccessViews(0, 2, nullUAV, 0);

	ID3D11ShaderResourceView* nullSrv[] = { NULL };
	dc->CSSetShaderResources(0, 1, nullSrv);
	// Disable Compute Shader
	dc->CSSetShader(nullptr, nullptr, 0);
}



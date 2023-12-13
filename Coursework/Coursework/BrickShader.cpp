#include "BrickShader.h"
#include "StaticHelpers.h"



BrickShader::BrickShader(ID3D11Device* device, HWND hwnd) : BaseShader(device, hwnd)
{
	initShader(L"Brick_vs.cso", L"Brick_ps_DenseVolume.cso");
}


BrickShader::~BrickShader()
{
	// Release the sampler state.
	if (sampleState)
	{
		sampleState->Release();
		sampleState = 0;
	}

	// Release the matrix constant buffer.
	if (matrixBuffer)
	{
		matrixBuffer->Release();
		matrixBuffer = 0;
	}

	// Release the layout.
	if (layout)
	{
		layout->Release();
		layout = 0;
	}

	//Release base shader components
	BaseShader::~BaseShader();
}

void BrickShader::loadUnitVertexShader(const wchar_t* filename)
{
	ID3DBlob* vertexShaderBuffer;

	unsigned int numElements;

	vertexShaderBuffer = 0;

	// check file extension for correct loading function.
	std::wstring fn(filename);
	std::string::size_type idx;
	std::wstring extension;

	idx = fn.rfind('.');

	if (idx != std::string::npos)
	{
		extension = fn.substr(idx + 1);
	}
	else
	{
		// No extension found
		MessageBox(hwnd, L"Error finding vertex shader file", L"ERROR", MB_OK);
		exit(0);
	}

	// Load the texture in.
	if (extension != L"cso")
	{
		MessageBox(hwnd, L"Incorrect vertex shader file type", L"ERROR", MB_OK);
		exit(0);
	}

	// Reads compiled shader into buffer (bytecode).
	HRESULT result = D3DReadFileToBlob(filename, &vertexShaderBuffer);
	if (result != S_OK)
	{
		MessageBox(NULL, filename, L"File ERROR", MB_OK);
		exit(0);
	}

	// Create the vertex shader from the buffer.
	renderer->CreateVertexShader(vertexShaderBuffer->GetBufferPointer(), vertexShaderBuffer->GetBufferSize(), NULL, &vertexShader);

	// Create the vertex input layout description.
	// This setup needs to match the VertexType stucture in the MeshClass and in the shader.
	D3D11_INPUT_ELEMENT_DESC polygonLayout[] = {
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "TEXCOORD", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0},
	};
	
	//// Get a count of the elements in the layout.
	numElements = sizeof(polygonLayout) / sizeof(polygonLayout[0]);
	
	// Create the vertex input layout.
	renderer->CreateInputLayout(polygonLayout, numElements, vertexShaderBuffer->GetBufferPointer(), vertexShaderBuffer->GetBufferSize(), &layout);

	// Release the vertex shader buffer and pixel shader buffer since they are no longer needed.
	vertexShaderBuffer->Release();
	vertexShaderBuffer = 0;
}

void BrickShader::initShader(const wchar_t* vsFilename, const wchar_t* psFilename)
{
	D3D11_BUFFER_DESC matrixBufferDesc;
	D3D11_SAMPLER_DESC samplerDesc;

	// Load (+ compile) shader files
	loadUnitVertexShader(vsFilename);
	loadPixelShader(psFilename);

	//ID3DBlob* pixelShaderBuffer;
	//ID3DBlob* errorMessage;

	//HRESULT rs = D3DCompileFromFile(L"shaders/Brick_ps_DenseVolume.hlsl", NULL, NULL, "PS_main", "ps_5_0", 0, 0, &pixelShaderBuffer, &errorMessage);
	//if(FAILED(renderer->CreatePixelShader(pixelShaderBuffer->GetBufferPointer(), pixelShaderBuffer->GetBufferSize(), NULL, &pixelShader))) throw std::exception();

	// Setup the description of the dynamic matrix constant buffer that is in the vertex shader.
	matrixBufferDesc.Usage = D3D11_USAGE_DYNAMIC;
	matrixBufferDesc.ByteWidth = sizeof(MatrixBufferType);
	matrixBufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	matrixBufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
	matrixBufferDesc.MiscFlags = 0;
	matrixBufferDesc.StructureByteStride = 0;

	// Create the constant buffer pointer so we can access the vertex shader constant buffer from within this class.
    if (FAILED(renderer->CreateBuffer(&matrixBufferDesc, NULL, &matrixBuffer))) throw std::exception();

	// Setup the description of the dynamic matrix constant buffer that is in the vertex shader.

	matrixBufferDesc.ByteWidth = sizeof(Control);

	// Create the constant buffer pointer so we can access the vertex shader constant buffer from within this class.
	if (FAILED(renderer->CreateBuffer(&matrixBufferDesc, NULL, &controlBuffer))) throw std::exception();

	// Create a texture sampler state description.
	samplerDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
	samplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.MipLODBias = 0.0f;
	samplerDesc.MaxAnisotropy = 1;
	samplerDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
	samplerDesc.MinLOD = 0;
	samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;

	// Create the texture sampler state.
	renderer->CreateSamplerState(&samplerDesc, &sampleState);


}


void BrickShader::setShaderParameters(ID3D11DeviceContext* deviceContext, const XMMATRIX &worldMatrix, const XMMATRIX &viewMatrix, const XMMATRIX &projectionMatrix, ID3D11ShaderResourceView* texture, ID3D11ShaderResourceView* Octree, Control* s)
{
	HRESULT result;
	D3D11_MAPPED_SUBRESOURCE mappedResource;
	MatrixBufferType* dataPtr;
	XMMATRIX tworld, tview, tproj;


	// Transpose the matrices to prepare them for the shader.
	tworld = XMMatrixTranspose(worldMatrix);
	tview = XMMatrixTranspose(viewMatrix);
	tproj = XMMatrixTranspose(projectionMatrix);

	// Sned matrix data
	result = deviceContext->Map(matrixBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);
	dataPtr = (MatrixBufferType*)mappedResource.pData;
	dataPtr->world = tworld;// worldMatrix;
	dataPtr->view = tview;
	dataPtr->projection = tproj;
	deviceContext->Unmap(matrixBuffer, 0);
	deviceContext->VSSetConstantBuffers(0, 1, &matrixBuffer);

	Control* ctrl;

	result = deviceContext->Map(controlBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource);

	memcpy(mappedResource.pData, s, sizeof(Control));

	deviceContext->Unmap(controlBuffer, 0);
	deviceContext->PSSetConstantBuffers(0, 1, &controlBuffer);

	// Set shader texture and sampler resource in the pixel shader.
	deviceContext->PSSetShaderResources(0, 1, &texture);
	deviceContext->PSSetShaderResources(1, 1, &Octree);
	deviceContext->PSSetSamplers(0, 1, &sampleState);
	//deviceContext->IASetInputLayout()
}






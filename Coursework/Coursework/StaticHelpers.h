#pragma once

#ifndef _WINDEF_
struct HWND__; 
typedef HWND__* HWND;
#endif

struct ID3D11Device;
struct ID3D11ComputeShader;
struct ID3D11PixelShader;
struct ID3D11Buffer;

static void loadComputeShader(ID3D11Device* renderer, HWND hwnd, const wchar_t* filename, ID3D11ComputeShader*& cs)
{

	ID3D10Blob* computeShaderBuffer;

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
		MessageBox(hwnd, L"Error finding geometry shader file", L"ERROR", MB_OK);
		exit(0);
	}

	// Load the texture in.
	if (extension != L"cso")
	{
		MessageBox(hwnd, L"Incorrect geometry shader file type", L"ERROR", MB_OK);
		exit(0);
	}

	// Reads compiled shader into buffer (bytecode).
	HRESULT result = D3DReadFileToBlob(filename, &computeShaderBuffer);
	if (result != S_OK)
	{
		MessageBox(NULL, filename, L"File not found", MB_OK);
		exit(0);
	}
	// Create the domain shader from the buffer.
	if (FAILED(renderer->CreateComputeShader(computeShaderBuffer->GetBufferPointer(), computeShaderBuffer->GetBufferSize(), NULL, &cs))) throw std::exception();

	computeShaderBuffer->Release();

}

static void loadPixelShader(ID3D11Device* renderer, HWND hwnd, const wchar_t* filename, ID3D11PixelShader*& ps)
{

	ID3D10Blob* pixelShaderBuffer;

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
		MessageBox(hwnd, L"Error finding geometry shader file", L"ERROR", MB_OK);
		exit(0);
	}
	
	// Load the texture in.
	if (extension != L"cso")
	{
		MessageBox(hwnd, L"Incorrect geometry shader file type", L"ERROR", MB_OK);
		exit(0);
	}
	
	// Reads compiled shader into buffer (bytecode).
	HRESULT result = D3DReadFileToBlob(filename, &pixelShaderBuffer);
	if (result != S_OK)
	{
		MessageBox(NULL, filename, L"File not found", MB_OK);
		exit(0);
	}
	// Create the domain shader from the buffer.
	if (FAILED(renderer->CreatePixelShader(pixelShaderBuffer->GetBufferPointer(), pixelShaderBuffer->GetBufferSize(), NULL, &ps))) throw std::exception();

	pixelShaderBuffer->Release();
}


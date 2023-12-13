#pragma once
#include "DXF.h"
#include "Structs.h"

enum class RENDERMODE
{
	FUNCTION,
	VOLUME,
	OCTREE
};

class RaymarchingCompute :
    public BaseShader
{
public:
	RaymarchingCompute(ID3D11Device* device, HWND hwnd, int w, int h);
	~RaymarchingCompute();

	void setShaderParameters(ID3D11DeviceContext* dc, Control* params, RENDERMODE RM, ID3D11ShaderResourceView* Volume, ID3D11ShaderResourceView* Octree, ID3D11SamplerState* VolumeSampler, bool Heatmap);
	void createOutputUAV();
	ID3D11ShaderResourceView* getSRV() { return m_srvTexOutput; };
	void unbind(ID3D11DeviceContext* dc);

private:
	void initShader(const wchar_t* cfile, const wchar_t* blank);

	// texture set
	ID3D11Texture2D* m_tex;
	ID3D11UnorderedAccessView* m_uavAccess;
	ID3D11ShaderResourceView* m_srvTexOutput;

	ID3D11Buffer* paramBuffer;

	ID3D11ComputeShader* FunctionalRaymarching;
	ID3D11ComputeShader* VolumeRaymarching;
	ID3D11ComputeShader* OctreeRaymarching;

	ID3D11ComputeShader* FunctionalRaymarching_HeatMap;
	ID3D11ComputeShader*	 VolumeRaymarching_HeatMap;
	ID3D11ComputeShader*	 OctreeRaymarching_HeatMap;

	int sWidth;
	int sHeight;
};


#pragma once
#include "DXF.h"
#include "RaymarchingCompute.h"
#include "Structs.h"


struct Node
{
    uint32_t Pointer;
    uint32_t Data;
    uint32_t Valid;
    uint32_t Leaf;
};

struct ShapeData
{
    ID3D11Buffer* Octree;
    ID3D11UnorderedAccessView* OctreeNodeUAV;
    ID3D11ShaderResourceView* OctreeNodeSRV;
};

class SparseVolume :
    public BaseShader
{
public:

    SparseVolume(ID3D11Device*, HWND, int VolumeSize);

    void setShaderParameters(ID3D11DeviceContext* dc, float stride, XMFLOAT3 Offset, int ShapeType, float scale);
    void unbind(ID3D11DeviceContext* dc);

    ID3D11ShaderResourceView* GetTextureSRV() { return VolumeSRV; };

    ID3D11ShaderResourceView* GetOctreeSRV() { return OctreeNodeSRV; };

    ID3D11SamplerState* GetSampler() { return VolumeSampler; };

    void Construct(ID3D11DeviceContext*, int stride = 1, int OBJtype = 0, XMFLOAT3 Offset = { 0,0,0 }, float scale = 1);

    UINT VolumeSize = 256;

//private:
    void initShader(const wchar_t* cfile, const wchar_t* blank) override;

    ID3D11Buffer* paramBuffer;
    ID3D11Buffer* OcupancyInfoBuffer;

    ID3D11Buffer* DispatchArgsBuffer;

    ID3D11Buffer* Octree;
    ID3D11UnorderedAccessView* OctreeNodeUAV;
    ID3D11ShaderResourceView*  OctreeNodeSRV;

    ID3D11ComputeShader* BrickEvaluator;
    ID3D11ComputeShader* BrickBuilder;
    ID3D11ComputeShader* OctreeBuilder;

    ID3D11Texture3D* Volume;
    ID3D11ShaderResourceView* VolumeSRV;
    ID3D11UnorderedAccessView* VolumeUAV;

    ID3D11SamplerState* VolumeSampler;
};


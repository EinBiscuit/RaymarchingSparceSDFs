#pragma once
#include "DXF.h"
#include "RaymarchingCompute.h"

struct VertexType
{
    XMFLOAT3 position;
    XMFLOAT2 texture;
    XMFLOAT3 normal;
};

struct Triangle
{
    VertexType tri[3];
};

struct MCParams
{
    float isolevel;
    int   gridSize;
    float gridStride;
    int SampleMode;
    
    XMFLOAT4 OffsetScale;

    int ShapeType;
    XMFLOAT3 Padding;
};

class MarchingCubesCompute : public BaseShader
{
public:
    MarchingCubesCompute(ID3D11Device* device, HWND hwnd, int voxelsPerSide);
    ~MarchingCubesCompute();

    void setShaderParameters(ID3D11DeviceContext* dc, MCParams* p, ID3D11ShaderResourceView* Brick, ID3D11SamplerState* Sampler);
    void setPixelShader(ID3D11DeviceContext* dc, LightData* light);
    void SendData(ID3D11DeviceContext* deviceContext, D3D_PRIMITIVE_TOPOLOGY top = D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    void unbind(ID3D11DeviceContext* dc);

    UINT AppendCount = 0;

private:
    void initShader(const wchar_t* cfile, const wchar_t* blank);

    int voxelCount; // uniform
    
    ID3D11UnorderedAccessView* VertUAV;
   // ID3D11UnorderedAccessView* IndUAV;

    ID3D11Texture2D* triTabletex;
    ID3D11ShaderResourceView* triTableSRV;

    ID3D11Texture1D* edgeTabletex;
    ID3D11ShaderResourceView* edgeTableSRV;
    
    ID3D11Buffer* AppendVertexBuffer;
    ID3D11Buffer* VertexBuffer;
    ID3D11Buffer* CounterBuffer;
    
    ID3D11Buffer* ParamBuffer;
    ID3D11Buffer* LightBuffer;


};


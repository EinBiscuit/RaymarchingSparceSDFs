// Cube Mesh
// Generates cube mesh at set resolution. Default res is 20.
// Mesh has texture coordinates and normals.
#include "UnitCube.h"

// Initialise vertex data, buffers and load texture.
UnitCubeMesh::UnitCubeMesh(ID3D11Device* device, ID3D11DeviceContext* deviceContext)
{
	initBuffers(device);
}

void UnitCubeMesh::sendData(ID3D11DeviceContext* deviceContext, D3D_PRIMITIVE_TOPOLOGY top)
{
	unsigned int stride;
	unsigned int offset;

		// Set vertex buffer stride and offset.
	stride = sizeof(UnitVertexType);
	offset = 0;

	deviceContext->IASetVertexBuffers(0, 1, &vertexBuffer, &stride, &offset);
	deviceContext->IASetIndexBuffer(indexBuffer, DXGI_FORMAT_R32_UINT, 0);
	deviceContext->IASetPrimitiveTopology(top);
}


UnitCubeMesh::~UnitCubeMesh()
{
	// Run parent deconstructor
	BaseMesh::~BaseMesh();
}


// Initialise geometry buffers (vertex and index).
// Generate and store cube vertices, normals and texture coordinates
void UnitCubeMesh::initBuffers(ID3D11Device* device)
{
	UnitVertexType* vertices;
	D3D11_BUFFER_DESC vertexBufferDesc, indexBufferDesc;
	D3D11_SUBRESOURCE_DATA vertexData, indexData;

	vertexCount = 8;
	indexCount = 6 * 2 * 3;

	// Create the vertex and index array.
	vertices = new UnitVertexType[vertexCount];
	///indices = new unsigned long[8*2*3];

	vertices[0].position = XMFLOAT3(-0.5f,-0.5f, 0.5f); vertices[0].texture = XMFLOAT3(0,0,1);
	vertices[1].position = XMFLOAT3( 0.5f,-0.5f, 0.5f); vertices[1].texture = XMFLOAT3(1,0,1);
	vertices[2].position = XMFLOAT3( 0.5f,-0.5f,-0.5f); vertices[2].texture = XMFLOAT3(1,0,0);
	vertices[3].position = XMFLOAT3(-0.5f,-0.5f,-0.5f); vertices[3].texture = XMFLOAT3(0,0,0);
	vertices[4].position = XMFLOAT3(-0.5f, 0.5f, 0.5f); vertices[4].texture = XMFLOAT3(0,1,1);
	vertices[5].position = XMFLOAT3( 0.5f, 0.5f, 0.5f); vertices[5].texture = XMFLOAT3(1,1,1);
	vertices[6].position = XMFLOAT3( 0.5f, 0.5f,-0.5f); vertices[6].texture = XMFLOAT3(1,1,0);
	vertices[7].position = XMFLOAT3(-0.5f, 0.5f,-0.5f); vertices[7].texture = XMFLOAT3(0,1,0);

	unsigned long* indices = new unsigned long[indexCount]
	{
		3, 6, 7,
		3, 2, 6,
		2, 5, 6,
		2, 1, 5,
		1, 4, 5,
		1, 0, 4,
		0, 7, 4,
		0, 3, 7,
		7, 5, 4,
		7, 6, 5,
		0, 2, 3,
		0, 1, 2
	};

	// Set up the description of the static vertex buffer.
	vertexBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	vertexBufferDesc.ByteWidth = sizeof(UnitVertexType)* vertexCount;
	vertexBufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	vertexBufferDesc.CPUAccessFlags = 0;
	vertexBufferDesc.MiscFlags = 0;
	vertexBufferDesc.StructureByteStride = 0;
	// Give the subresource structure a pointer to the vertex data.
	vertexData.pSysMem = vertices;
	vertexData.SysMemPitch = 0;
	vertexData.SysMemSlicePitch = 0;
	// Now create the vertex buffer.
	device->CreateBuffer(&vertexBufferDesc, &vertexData, &vertexBuffer);

	// Set up the description of the static index buffer.
	indexBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	indexBufferDesc.ByteWidth = sizeof(unsigned long)* indexCount;
	indexBufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
	indexBufferDesc.CPUAccessFlags = 0;
	indexBufferDesc.MiscFlags = 0;
	indexBufferDesc.StructureByteStride = 0;
	// Give the subresource structure a pointer to the index data.
	indexData.pSysMem = indices;
	indexData.SysMemPitch = 0;
	indexData.SysMemSlicePitch = 0;
	// Create the index buffer.
	device->CreateBuffer(&indexBufferDesc, &indexData, &indexBuffer);

	// Release the arrays now that the vertex and index buffers have been created and loaded.
	delete[] vertices;
	vertices = 0;

	delete[] indices;
	indices = 0;
}


/**
* \class unit cube
*
* \brief Simple cube mesh object with UVW
*
* Inherits from Base Mesh, Builds a simple cube with texture coordinates and normals.
*
*/

#include "BaseMesh.h"

using namespace DirectX;

struct UnitVertexType
{
	XMFLOAT3 position;
	XMFLOAT3 texture; //for uvw;
};


class UnitCubeMesh : public BaseMesh
{

public:
	/** \brief Initialises and builds a cube mesh
	*
	* Can specify resolution of cube, this deteremines how many subdivisions are on each side of the cube.
	* @param device is the renderer device
	* @param device context is the renderer device context
	* @param resolution is a int for subdivision of the cube. Default is 20.
	*/
	UnitCubeMesh(ID3D11Device* device, ID3D11DeviceContext* deviceContext);
	void sendData(ID3D11DeviceContext* deviceContext, D3D_PRIMITIVE_TOPOLOGY top = D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST) override;
	~UnitCubeMesh();

protected:
	void initBuffers(ID3D11Device* device);
};

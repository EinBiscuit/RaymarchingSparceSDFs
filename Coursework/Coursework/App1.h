// Application.h
#ifndef _APP1_H
#define _APP1_H

// Includes
#include "DXF.h"
#include "TextureShader.h"
#include "RaymarchingCompute.h"
#include "MarchingCubesCompute.h"
#include "SparseVolume.h"

#include "BrickShader.h"
#include "UnitCube.h"
#include "DenseVolume.h"
#include <stack>;

#include <fstream>
#include <string>
#include <filesystem>

//#include <gpu_performance_api/gpu_perf_api_types.h>

//struct GpaParams
//{
//	GpaSessionId sID;
//	GpaCommandListId cmdListID;
//	GpaUInt32 sampleID;
//};

class App1 : public BaseApplication
{
public:

	App1();
	~App1();
	void init(HINSTANCE hinstance, HWND hwnd, int screenWidth, int screenHeight, Input* in, bool VSYNC, bool FULL_SCREEN);

	bool frame();

protected:

	void PostProcessedOrthoMesh();
	bool render();
	void gui();

	void RaymarchingPass();
	void PolygonizationPass();

	Control Parameters;
	MCParams MarchingCubeParameters;

	int RasterMode;
	int RaymarchingMode;

	bool raystepHeatmap;

	int SamplerMode=0;
	bool rebuildVolume;
	bool rebuildVolumeOnFrame;
	
	TextureShader* shaderTexture;
	RaymarchingCompute* raymarch;
	MarchingCubesCompute* Poly;
	SparseVolume* sparseVolume;
	DenseVolume* denseVolume;

	UnitCubeMesh* Brick;
	BrickShader* shaderBrick;
	
	OrthoMesh* ppOutput;

	//Perf measuring

	ofstream* file_log;

	//std::stack<GpaParams> gpaStack;

	void GpuTimerPush();
	double GpuTimerPop();

    int frameCount;
	int framenum;
	bool startcapture;

	float gpuTime;

	bool InitializeGPA();

	void InitializeLog(string fileName, vector<string> columns);

private:

};

#endif
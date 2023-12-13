// Lab1.cpp
// Lab 1 example, simple coloured triangle mesh
#include "App1.h"

//#ifndef NV_PERF_ENABLE_INSTRUMENTATION
//#define NV_PERF_ENABLE_INSTRUMENTATION             // use macro NV_PERF_ENABLE_INSTRUMENTATION to turn on the Nsight Perf instrumentation.
//#endif
//#ifdef NV_PERF_ENABLE_INSTRUMENTATION
//#include "NvPerfReportGeneratorD3D11.h"
//#endif
//
//#ifdef NV_PERF_ENABLE_INSTRUMENTATION
//#include "nvperf_host_impl.h"
//#endif

//#include "gpu_performance_api/gpu_perf_api.h"
//#include "gpu_performance_api/gpu_perf_api_interface_loader.h"
//
//GpaApiManager* GpaApiManager::gpa_api_manager_ = nullptr;
//GpaFuncTableInfo* gpa_function_table_info = nullptr;
//GpaFunctionTable* gpa_function_table = nullptr;
//GpaContextId gpa_ctxID;

double nanoToMilliseconds = 1e+6;
double nanoToMicroseconds = 1e+3;

bool App1::InitializeGPA()
{
	bool ret_val = false;

	//if (kGpaStatusOk == GpaApiManager::Instance()->LoadApi(kGpaApiDirectx11))
	//{
	//	gpa_function_table = GpaApiManager::Instance()->GetFunctionTable(kGpaApiDirectx11);
	//
	//	if (nullptr != gpa_function_table)
	//	{
	//		ret_val = kGpaStatusOk == gpa_function_table->GpaInitialize(kGpaInitializeDefaultBit);
	//	}
	//}

	return ret_val;
}

void App1::InitializeLog(string fileName, vector<string> columns)
{

	string filename = "../Results/" + fileName;

	file_log = new std::ofstream(filename);

	for (auto column : columns)
	{
		*file_log << column << ",";
	}

	*file_log << "\n";

}

App1::App1()
{
	if (!InitializeGPA())
	{
		//throw std::exception("Failed to initialise GPA");
	}
}

void App1::init(HINSTANCE hinstance, HWND hwnd, int screenWidth, int screenHeight, Input *in, bool VSYNC, bool FULL_SCREEN)
{
	// Call super/parent init function (required!)
	BaseApplication::init(hinstance, hwnd, screenWidth, screenHeight, in, VSYNC, FULL_SCREEN);

	shaderTexture = new TextureShader(renderer->getDevice(), hwnd);
	ppOutput = new OrthoMesh(renderer->getDevice(), renderer->getDeviceContext(), screenWidth, screenHeight);

	//Raymarching
	
	raymarch = new RaymarchingCompute(renderer->getDevice(), hwnd, screenWidth, screenHeight);


	MarchingCubeParameters.gridSize = 100;
	MarchingCubeParameters.gridStride = 2.5f / (float)MarchingCubeParameters.gridSize;
	MarchingCubeParameters.isolevel = 0.01f;
	MarchingCubeParameters.SampleMode = 0;

	RasterMode = false;

	camera->setPosition(0, 30, -30);
	camera->setRotation(45, 0, 0);
	
	Poly = new MarchingCubesCompute(renderer->getDevice(),hwnd,MarchingCubeParameters.gridSize);

	sparseVolume = new SparseVolume(renderer->getDevice(), hwnd, 256);
	denseVolume = new DenseVolume(renderer->getDevice(), hwnd, 256);

	// volume stride of 32 yields 1/32 sub voxel precision range -1 to 1 is contained in 8 voxels
	// volume stride of 16 yields 1/16 sub voxel precision range -1 to 1 is contained in 32 voxels

	ZeroMemory(&Parameters, sizeof(Control));

	Parameters.epsilon = 0.001f;
	Parameters.TextureStride = 16;
	Parameters.normalbias = 0.001f;
	
	Parameters.ObjectTranslationScale = XMFLOAT4(0,0,0,3);
	Parameters.Raymarch_boxScale = 16.f;
	
	Parameters.ShapeType = 2;
	
	rebuildVolume = false;
	rebuildVolumeOnFrame = false;

	sparseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType);
	denseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType);

	Brick = new UnitCubeMesh(renderer->getDevice(), renderer->getDeviceContext());
	shaderBrick = new BrickShader(renderer->getDevice(), hwnd);
	
	Parameters.Light.LightColour = XMFLOAT4(1,1,1,0);
	Parameters.Light.LightDir = XMFLOAT4(-1,-1,0,0);


	RasterMode = 1; // brick
	RaymarchingMode = (int)RENDERMODE::VOLUME; // raymarch

	frameCount = 250;
	framenum = 0;

	gpuTime = 0;

	//FEATURE TEST AND GPA

	//gpa_function_table->GpaOpenContext(renderer->getDevice(), kGpaOpenContextDefaultBit, &gpa_ctxID);

	D3D11_FEATURE_DATA_D3D11_OPTIONS2 FeatureData;
	ZeroMemory(&FeatureData, sizeof(FeatureData));
	HRESULT hr = renderer->getDevice()->CheckFeatureSupport(D3D11_FEATURE_D3D11_OPTIONS2, &FeatureData, sizeof(FeatureData));
	if (SUCCEEDED(hr))
	{
		// TypedUAVLoadAdditionalFormats contains a Boolean that tells you whether the feature is supported or not
		if (FeatureData.TypedUAVLoadAdditionalFormats)
		{
			// Can assume “all-or-nothing” subset is supported (e.g. R32G32B32A32_FLOAT)
			// Can not assume other formats are supported, so we check:
			D3D11_FEATURE_DATA_FORMAT_SUPPORT2 FormatSupport;
			ZeroMemory(&FormatSupport, sizeof(FormatSupport));
			FormatSupport.InFormat = DXGI_FORMAT_R8_SNORM;
			hr = renderer->getDevice()->CheckFeatureSupport(D3D11_FEATURE_FORMAT_SUPPORT2, &FormatSupport, sizeof(FormatSupport));
			if (SUCCEEDED(hr) && (FormatSupport.OutFormatSupport2 & D3D11_FORMAT_SUPPORT2_UAV_TYPED_LOAD) != 0)
			{
				// DXGI_FORMAT_R8_SNORM supports UAV Typed Load!
			}
			//else
			//	throw std::exception("DXGI_FORMAT_R8_SNORM does not support UAV Typed Load");
		}
	}

	//RESULT GATHERING

	std::filesystem::create_directory("../Results");

	InitializeLog("test_results.csv", { "GPU Time for Scene" });

}


App1::~App1()
{
	// Run base application deconstructor
	BaseApplication::~BaseApplication();

	//gpa_function_table->GpaCloseContext(gpa_ctxID);
	//gpa_function_table->GpaDestroy();

	// Release the Direct3D object.
}


bool App1::frame()
{
	bool result;

	result = BaseApplication::frame();
	if (!result)
	{
		return false;
	}
	
	// Render the graphics.
	//GpuTimerPush();
	result = render();
	//gpuTime = GpuTimerPop() / nanoToMilliseconds;
	if (!result)
	{
		return false;
	}

	return true;
}


void App1::PostProcessedOrthoMesh()
{
	// Get the world, view, projection, and ortho matrices from the camera and Direct3D objects.
	XMMATRIX worldMatrix = renderer->getWorldMatrix();
	XMMATRIX orthoMatrix = renderer->getOrthoMatrix();// ortho matrix for 2D rendering
	XMMATRIX baseViewMatrix = camera->getOrthoViewMatrix();

	renderer->setZBuffer(false);
	ppOutput->sendData(renderer->getDeviceContext());
	shaderTexture->setShaderParameters(renderer->getDeviceContext(), worldMatrix, baseViewMatrix, orthoMatrix, raymarch->getSRV());
	shaderTexture->render(renderer->getDeviceContext(), ppOutput->getIndexCount());
	renderer->getDeviceContext()->DrawIndexed(6, 0, 0);
	renderer->setZBuffer(true);
}


bool App1::render()
{
	// Clear the scene. (default blue colour)
	renderer->beginScene(0.39f, 0.58f, 0.92f, 1.0f);
	//renderer->beginScene(1,1,1, 1.0f);

	// Generate the view matrix based on the camera's position.
	camera->update();

	if (rebuildVolume || rebuildVolumeOnFrame)
	{
		XMFLOAT3 offset = XMFLOAT3(Parameters.ObjectTranslationScale.x, Parameters.ObjectTranslationScale.y, Parameters.ObjectTranslationScale.z);

		float gputime = 0;

		switch ((RENDERMODE)RaymarchingMode)
		{
		case RENDERMODE::OCTREE:
	
		//	if (startcapture)
		//	{
		//		Parameters.ObjectTranslationScale.w = frameCount;
		//		GpuTimerPush();
		//	}
		
			sparseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType, offset, Parameters.ObjectTranslationScale.w);
		//
		//	sparseVolume->setShaderParameters(renderer->getDeviceContext(), Parameters.TextureStride, offset, Parameters.ShapeType, Parameters.ObjectTranslationScale.w);
		//
		//	renderer->getDeviceContext()->CSSetShader(sparseVolume->BrickEvaluator, 0, 0);
		//	renderer->getDeviceContext()->Dispatch(1, 1, 1);
		//
		//	renderer->getDeviceContext()->CopyStructureCount(sparseVolume->DispatchArgsBuffer, 0, sparseVolume->OctreeNodeUAV);
		//	renderer->getDeviceContext()->CopyStructureCount(sparseVolume->paramBuffer, 16, sparseVolume->OctreeNodeUAV); //populate node count int constant buffer
		//
		//
		//	if (startcapture)
		//	{
		//		gputime = GpuTimerPop() / nanoToMicroseconds;
		//
		//		if (file_log)
		//		{
		//			*file_log << gputime << ","; // "," indicates next comlumn
		//			//*file_log << gputime << "\n";
		//		}
		//
		//		GpuTimerPush();
		//	}
		//
		//	renderer->getDeviceContext()->CSSetShader(sparseVolume->BrickBuilder, NULL, 0);
		//	renderer->getDeviceContext()->DispatchIndirect(sparseVolume->DispatchArgsBuffer, 0);
		//	
		//	if (startcapture)
		//	{
		//		gputime = GpuTimerPop() / nanoToMicroseconds;
		//
		//		if (file_log)
		//		{
		//			*file_log << gputime << ","; // "," indicates next comlumn
		//			//*file_log << gputime << "\n";
		//		}
		//
		//		GpuTimerPush();
		//	}
		//
		//	renderer->getDeviceContext()->CSSetShader(sparseVolume->OctreeBuilder, NULL, 0);
		//	renderer->getDeviceContext()->Dispatch(1, 1, 1);
		//
		//	sparseVolume->unbind(renderer->getDeviceContext());
		//
		//	if (startcapture)
		//	{
		//		
		//		gputime = GpuTimerPop() / nanoToMicroseconds;
		//
		//		if (file_log)
		//		{
		//			//*file_log << gpuTime << ","; // "," indicates next comlumn
		//			*file_log << gputime << "\n";
		//		}
		//
		//		frameCount++;
		//		if (frameCount > 7)
		//		{
		//			startcapture = false;
		//		}
		//	}


			break;
		case RENDERMODE::VOLUME:
			denseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType, offset, Parameters.ObjectTranslationScale.w);
			break;
		}

		//rebuildVolume = false;
	}

	Parameters.PFP.x = camera->getPosition().x;
	Parameters.PFP.y = camera->getPosition().y;
	Parameters.PFP.z = camera->getPosition().z;
	Parameters.PFP.w = camera->getPosition().x;

	Parameters.ViewMatrix = camera->getViewMatrix();

	
	switch(RasterMode)
	{
	case 0:
		PolygonizationPass();
		break;
	case 1:
		RaymarchingPass();
		break;
	case 2:
		shaderBrick->setShaderParameters(renderer->getDeviceContext(), renderer->getWorldMatrix(), camera->getViewMatrix(), renderer->getProjectionMatrix(), denseVolume->GetTextureSRV(), sparseVolume->GetOctreeSRV(), &Parameters);
		Brick->sendData(renderer->getDeviceContext());
		shaderBrick->render(renderer->getDeviceContext(), Brick->getIndexCount());
		renderer->getDeviceContext()->DrawIndexed(Brick->getIndexCount(), 0, 0);

		break;
	default: ;
	}
	

	//Render GUI
	gui();

	// Present the rendered scene to the screen.
	renderer->endScene();

	return true;
}

void App1::PolygonizationPass()
{
	
	MarchingCubeParameters.SampleMode = SamplerMode;
	MarchingCubeParameters.ShapeType = Parameters.ShapeType;
	MarchingCubeParameters.OffsetScale = Parameters.ObjectTranslationScale;

	Poly->setShaderParameters(renderer->getDeviceContext(), &MarchingCubeParameters, denseVolume->GetTextureSRV(), sparseVolume->GetSampler());
	Poly->compute(renderer->getDeviceContext(), MarchingCubeParameters.gridSize, MarchingCubeParameters.gridSize, MarchingCubeParameters.gridSize);
	Poly->unbind(renderer->getDeviceContext());


	// Get the world, view, projection, and ortho matrices from the camera and Direct3D objects.
	XMMATRIX worldMatrix = renderer->getWorldMatrix();
	XMMATRIX orthoMatrix = renderer->getProjectionMatrix();// ortho matrix for 2D rendering
	XMMATRIX baseViewMatrix = camera->getViewMatrix();

	Poly->SendData(renderer->getDeviceContext());

	//ppOutput->sendData(renderer->getDeviceContext());
	shaderTexture->setShaderParameters(renderer->getDeviceContext(), worldMatrix, baseViewMatrix, orthoMatrix, raymarch->getSRV());
	shaderTexture->render(renderer->getDeviceContext(), ppOutput->getIndexCount());

	Poly->setPixelShader(renderer->getDeviceContext(), &Parameters.Light); // use different pixel shader
	renderer->getDeviceContext()->Draw(Poly->AppendCount*3, 0);
	
}

void App1::RaymarchingPass()
{
	//Raymarching yeet;

	Parameters.PFP.x = camera->getPosition().x;
	Parameters.PFP.y = camera->getPosition().y;
	Parameters.PFP.z = camera->getPosition().z;
	Parameters.PFP.w = 1;

	Parameters.ViewMatrix = camera->getViewMatrix();

	RENDERMODE RM = (RENDERMODE)RaymarchingMode;

	if(RM == RENDERMODE::OCTREE)
	raymarch->setShaderParameters(renderer->getDeviceContext(), &Parameters,RM, sparseVolume->GetTextureSRV(), sparseVolume->GetOctreeSRV(), sparseVolume->GetSampler(),raystepHeatmap);
	else
	raymarch->setShaderParameters(renderer->getDeviceContext(), &Parameters, RM, denseVolume->GetTextureSRV(),NULL, sparseVolume->GetSampler(),raystepHeatmap);

	//GpuTimerPush();
	
	//gpuTime = GpuTimerPop() / nanoToMilliseconds;
	
	//if (startcapture)
	//{
	//	if (framenum > frameCount)
	//	{
	//		startcapture = false;
	//
	//		//file_log->close()
	//		//file_log = nullptr;
	//	}
	//	GpuTimerPush();
	//}
	
	renderer->getDeviceContext()->Dispatch(ceil((float)sWidth / 16.f), ceil((float)sHeight / 16.f), 1);

	//if (startcapture)
	//{
	//
	//	gpuTime = GpuTimerPop() / nanoToMilliseconds;
	//	if (file_log)
	//	{
	//		//*file_log << gpuTime << ","; // "," indicates next comlumn
	//		*file_log << gpuTime << "\n";
	//	}
	//	framenum++;
	//}

	raymarch->unbind(renderer->getDeviceContext());

	//renderwd
	PostProcessedOrthoMesh();
}


void App1::GpuTimerPush()
{
	//GpaSessionId sID;
	//GpaUInt32 count = 0;
	//const GpaUInt32 sampleID = 0;
	//gpa_function_table->GpaCreateSession(gpa_ctxID, kGpaSessionSampleTypeDiscreteCounter, &sID);
	//gpa_function_table->GpaEnableCounterByName(sID, "GPUTime");
	//gpa_function_table->GpaBeginSession(sID);
	//gpa_function_table->GpaGetPassCount(sID, &count);
	//
	//
	//GpaCommandListId cmdListID;
	//gpa_function_table->GpaBeginCommandList(sID, 0, nullptr, kGpaCommandListNone, &cmdListID);
	//gpa_function_table->GpaBeginSample(sampleID, cmdListID);
	//
	//gpaStack.push(GpaParams{ sID, cmdListID, sampleID });
}

double App1::GpuTimerPop()
{
	//GpaParams params = gpaStack.top();
	//gpaStack.pop();
	//gpa_function_table->GpaEndSample(params.cmdListID);
	//gpa_function_table->GpaEndCommandList(params.cmdListID);
	//GpaStatus passResult;
	//
	//int i = 0;
	//
	//do
	//{
	//	passResult = gpa_function_table->GpaIsPassComplete(params.sID, 0);
	//	i++;
	//} while (kGpaStatusOk != passResult && i < 1000);
	//
	//gpa_function_table->GpaEndSession(params.sID);
	//
	//size_t resultSize = 0u;
	//gpa_function_table->GpaGetSampleResultSize(params.sID, params.sampleID, &resultSize);
	//auto* data = new unsigned char[resultSize];
	//gpa_function_table->GpaGetSampleResult(params.sID, params.sampleID, resultSize, data);
	//double nanosecondsTime = *reinterpret_cast<double*>(data);
	//delete[] data;
	//gpa_function_table->GpaDisableCounterByName(params.sID, "GPUTime");
	//gpa_function_table->GpaDeleteSession(params.sID);

	//throw std::runtime_error("Not implemented");

	return 0;
}

void App1::gui()
{
	// Force turn off unnecessary shader stages.
	renderer->getDeviceContext()->GSSetShader(NULL, NULL, 0);
	renderer->getDeviceContext()->HSSetShader(NULL, NULL, 0);
	renderer->getDeviceContext()->DSSetShader(NULL, NULL, 0);

	//ImGui::ShowDemoWindow();

	if (ImGui::Button("Start capture"))
	{
		startcapture = true;
	}

	//ImGui::InputInt("frames to capture", &frameCount);

	// Build UI
	ImGui::Text("RAYMARCHING IS FUN.. THEY SAID");
	ImGui::Text("FPS: %.3f", timer->getFPS());
	//ImGui::Text("GPU TIME: %f", gpuTime);

	XMFLOAT3 cam = camera->getRotation();
	ImGui::Text("Camera rotation: %.3f %.3f %.3f", cam.x, cam.y, cam.z);
	cam = camera->getPosition();
	ImGui::Text("Camera position: %.3f %.3f %.3f", cam.x, cam.y, cam.z);

	//ImGui::ColorEdit4("Light Colour", reinterpret_cast<float*>(&Parameters.Light.LightColour));
	//ImGui::InputFloat4("Light Direction",reinterpret_cast<float*>(&Parameters.Light.LightDir));

	ImGui::RadioButton("Marching Cubes", &RasterMode, 0); ImGui::SameLine();
	ImGui::RadioButton("Raymarching", &RasterMode, 1); //ImGui::SameLine();
	//	ImGui::RadioButton("Brick", &RasterMode, 2);

	if (ImGui::CollapsingHeader("Object Parameters", ImGuiTreeNodeFlags_DefaultOpen))
	{
		ImGui::InputFloat3("Translation", (float*)&Parameters.ObjectTranslationScale.x);
		ImGui::SliderFloat("Uniform Scale", (float*)&Parameters.ObjectTranslationScale.w, 0.1f, 10.f);
	}

	ImGui::Separator();

	if (ImGui::CollapsingHeader("VolumeConstruction", ImGuiTreeNodeFlags_DefaultOpen))
	{
		
		ImGui::SliderFloat("Volume Stride", &Parameters.TextureStride, 1, 32);

		const char* ShapeChoices[] = { "Brick", "Sphere", "Teapot","EdgeyCube", "Multi-EdgeyCube","MULTI-BALL"};
		if (ImGui::Combo("Shape Selection", &Parameters.ShapeType, ShapeChoices, 6))
		{
			XMFLOAT3 offset = XMFLOAT3(Parameters.ObjectTranslationScale.x, Parameters.ObjectTranslationScale.y, Parameters.ObjectTranslationScale.z);

			sparseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType, offset, Parameters.ObjectTranslationScale.w);
			denseVolume->Construct(renderer->getDeviceContext(), Parameters.TextureStride, Parameters.ShapeType, offset, Parameters.ObjectTranslationScale.w);
		}
		
		if (ImGui::Button("Recompute")) 
		{
			rebuildVolume = true;
		}
		else
		{
			rebuildVolume = false;
		}

		ImGui::SameLine();

		ImGui::Checkbox("Recompute On Frame", &rebuildVolumeOnFrame);
	}

	ImGui::Separator();

	if (ImGui::CollapsingHeader("Raymarching Mode", ImGuiTreeNodeFlags_DefaultOpen))
	{
		ImGui::RadioButton("Functional", &RaymarchingMode, 0); ImGui::SameLine();
		ImGui::RadioButton("DenseTexture", &RaymarchingMode, 1); ImGui::SameLine();
		ImGui::RadioButton("Octree", &RaymarchingMode, 2);
		
		ImGui::Separator();

		ImGui::SliderFloat("EPSILON", &Parameters.epsilon, 0.000001, 0.01f, " % .6f");
		ImGui::SliderFloat("NormalBias", &Parameters.normalbias, 0.000001f, 0.01f, "%.6f");

		ImGui::Separator();

		ImGui::Checkbox("Step Heatmap", &raystepHeatmap);
		ImGui::SliderFloat("Texture BoxSize", &Parameters.Raymarch_boxScale,1,64);

		//ImGui::SliderFloat("GridStride", &MarchingCubeParameters.gridStride, 0.01, 0.05);
		//ImGui::SliderFloat("Isolevel", &MarchingCubeParameters.isolevel, -1, 5);
	}

	if (ImGui::CollapsingHeader("MarchingCubes", ImGuiTreeNodeFlags_DefaultOpen))
	{
		ImGui::RadioButton("SampleVolumeTexture", &SamplerMode, 1); ImGui::SameLine();
		ImGui::RadioButton("Use functional representation", &SamplerMode, 0);

		ImGui::Text("TriangleAppendCount: %i", Poly->AppendCount);
		ImGui::Checkbox("Wireframe Mode", &wireframeToggle);
		ImGui::SliderFloat("GridStride", &MarchingCubeParameters.gridStride, 0.01, 0.05);
		ImGui::SliderFloat("Isolevel", &MarchingCubeParameters.isolevel, -1, 5);

	}
	
	// Render UI
	ImGui::Render();
	ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
}



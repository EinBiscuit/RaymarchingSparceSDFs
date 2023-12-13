
#include "SceneFunctions.hlsli"

float Scene(float3 r)
{
    
    
    //r -= float3(-1,-1,-1); // trans latte
    float3 rep;
    //opRep(r, float3(5.f, 5.0f, 5.f) ,r);
    
    //r += 0.25;
	
    //return sminCubic(Sphere(r - float3(0.7, 0.7, 0.7), 0.5), RoundBox(r, float3(0.5, 0.5, 0.5), 0.02), 0.6f);

    //return RoundBox(r, float3(0.1, 0.1, 0.1), 0.01);
    // r -= float3(0, 0, 1); // trans latte

    //return RoundBox(r, float3(0.1, 0.1, 0.1), 0.01);
    
 
    
    return max(RoundBox(r, float3(0.3, 0.3, 0.3), 0.05), -Sphere(r, 0.4));
    return Teapot(r);

}

float Scene(float3 r, uint OBJ_SELECT, float3 translation, float scale)
{
    //r += 0.25f * 64;
    //opRep(r, float3(1.f, 1.f, 1.f)*8.f, r);
    
    r -= translation;
    
    r/=scale;
    
    float h = 0;
    
    switch (OBJ_SELECT)
    {
      default:
            h = RoundBox(r, float3(0.5f, 0.5f, 0.5f), 0.05);
      break;
        
      case 1:
            h = Sphere(r, 0.75);
            break;
      case 2:
            h = Teapot(r/2.f)*2.f;
            break;
      case 3:
           h = max(RoundBox(r, float3(0.3, 0.3, 0.3), 0.05), -Sphere(r, 0.4));
           break;
        
      case 4:
         
            r -= (7, 7, 7);
        
          opRepLim(r, 2, (8, 8, 8), r);
        
          h = max(RoundBox(r, float3(0.3, 0.3, 0.3), 0.05), -Sphere(r, 0.4));
          break;
      
      case 5:
            
            r -= (7, 7, 7);
        
            opRepLim(r, 2, (8, 8, 8), r);
        
            h = Sphere(r, 0.75);
          break;
    }
    
    return h*scale;

}


struct Light
{
    float4 direction;
    float4 colour;
};

float4 PhongShading(float3 normal, Light light)
{
    return dot(normalize(-light.direction.xyz), normal) * light.colour;
}

float3 calcNormal(float3 pos, float EPSILON)
{
    float2 e = float2(EPSILON, 0.f);
	
    return normalize(float3(Scene(pos + e.xyy) - Scene(pos - e.xyy),
							Scene(pos + e.yxy) - Scene(pos - e.yxy),
							Scene(pos - e.yyx) - Scene(pos + e.yyx)));
	
}

float3 calcNormal(float3 pos, float EPSILON, uint ObjectType, float3 translation, float scale)
{
    float2 e = float2(EPSILON, 0.f);
	
    return normalize(float3(Scene(pos + e.xyy, ObjectType,translation,scale) - Scene(pos - e.xyy, ObjectType,translation,scale),
							Scene(pos + e.yxy, ObjectType,translation,scale) - Scene(pos - e.yxy, ObjectType,translation,scale),
							Scene(pos + e.yyx, ObjectType,translation,scale) - Scene(pos - e.yyx, ObjectType,translation,scale)));
	
}

float3 calcNormalVolume(SamplerState ss, Texture3D<float> v, float3 pos, float epsilon)
{
    uint3 size;

    v.GetDimensions(size.x, size.y, size.z);

    float2 e = float2(epsilon, 0.f);

    float dx = v.SampleLevel(ss, (pos + e.xyy), 0) - v.SampleLevel(ss, (pos - e.xyy), 0);;
    float dy = v.SampleLevel(ss, (pos + e.yxy), 0) - v.SampleLevel(ss, (pos - e.yxy), 0);;
    float dz = v.SampleLevel(ss, (pos + e.yyx), 0) - v.SampleLevel(ss, (pos - e.yyx), 0);;

    return normalize(float3(dx, dy, dz));
}

float3 calcNormalVolume(SamplerState ss, Texture3D<snorm float> v, float3 pos, float epsilon)
{
    uint3 size;

    v.GetDimensions(size.x, size.y, size.z);

    float2 e = float2(epsilon, 0.f);

    float dx = v.SampleLevel(ss, (pos + e.xyy), 0) - v.SampleLevel(ss, (pos - e.xyy), 0);;
    float dy = v.SampleLevel(ss, (pos + e.yxy), 0) - v.SampleLevel(ss, (pos - e.yxy), 0);;
    float dz = v.SampleLevel(ss, (pos + e.yyx), 0) - v.SampleLevel(ss, (pos - e.yyx), 0);;

    return normalize(float3(dx, dy, dz));
}
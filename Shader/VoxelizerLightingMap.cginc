#if !defined(MY_LIGHTMAPPING_INCLUDED)
#define MY_LIGHTMAPPING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "UnityMetaPass.cginc"
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Macros.hlsl"
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Random.hlsl" //in case of we want to use Hash function
#include "Packages/jp.keijiro.noiseshader/Shader/SimplexNoise3D.hlsl"
float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _EmissionMap;
float3 _Emission;


float _Paramtest;
float _Scale;
float _Density;
float _FallDist;
float _Fluctuation;
float _Stretch;
float _flythreshold;
float _effectordistance;

struct VertexData {
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};
struct lightingmapv2g{
    float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};
struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
};

float GetDetailMask (Interpolators i) {
	#if defined (_DETAIL_MASK)
		return tex2D(_DetailMask, i.uv.xy).a;
	#else
		return 1;
	#endif
}

float3 GetAlbedo (Interpolators i) {
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
	#if defined (_DETAIL_ALBEDO_MAP)
		float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
		albedo = lerp(albedo, albedo * details, GetDetailMask(i));
	#endif
	return albedo;
}

float GetMetallic (Interpolators i) {
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).r;
	#else
		return _Metallic;
	#endif
}

float GetSmoothness (Interpolators i) {
	float smoothness = 1;
	#if defined(_SMOOTHNESS_ALBEDO)
		smoothness = tex2D(_MainTex, i.uv.xy).a;
	#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
		smoothness = tex2D(_MetallicMap, i.uv.xy).a;
	#endif
	return smoothness * _Smoothness;
}

float3 GetEmission (Interpolators i) {
	#if defined(_EMISSION_MAP)
		return tex2D(_EmissionMap, i.uv.xy) * _Emission;
	#else
		return _Emission;
	#endif
}
lightingmapv2g RePackVoxelierLightVertex(float4 vertex, float2 uv, float2 uv1){
    lightingmapv2g g;
    g.vertex = vertex;
    g.uv = uv;
    g.uv1 = uv1;
    return g;

}
lightingmapv2g VoxelierLightingMapVertexProgram (VertexData v){ //pass this to gemo
    lightingmapv2g g;
    g.vertex = v.vertex;
    g.uv = v.uv;
    g.uv1 = v.uv1;
    return g;
}
Interpolators PackLightmappingVertex(lightingmapv2g v){ //this happended in geo
    Interpolators i;
	v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
	v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;

    i.pos = UnityObjectToClipPos(v.vertex);

	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	return i;
}
void randomcueposscale(float3 center, float size, float distancefromeffect, float randomnumber, float FallDist, out float3 scale, out float3 pos){
	
	float param  =  distancefromeffect >  _effectordistance ? distancefromeffect : 1 ;
	
	float4 snoise = snoise_grad(float3(randomnumber * 2378.34, _SinTime.x * 0.8 * param, 0)); 
	
	pos = center + snoise.xyz * size * lerp(0,_Fluctuation,saturate(param)); 
	
	float move = (distancefromeffect - _flythreshold) * step(_flythreshold,distancefromeffect); 
	pos.y+= move*move * _FallDist * size;
	
	float yscale = saturate(param) * _Stretch * lerp(0,1,randomnumber); 
					
	scale  = float2(1,yscale+1).xyx;
	scale*= _Scale * snoise.w  *  size; 
					
	

}
[maxvertexcount(24)]
void VoxelierLightingMapgeom(triangle lightingmapv2g IN[3], uint pid : SV_PrimitiveID, inout TriangleStream<Interpolators> outstream){ 

	float3 p0 = IN[0].vertex.xyz; //这个东西还是叫vertex，此时就是普通的点传进去没做任何事
	float3 p1 = IN[1].vertex.xyz;
	float3 p2 = IN[2].vertex.xyz;
	float3 center = (p0 + p1 + p2) / 3;  
	float3 center_ws = mul(unity_ObjectToWorld,center); //这个用于计算的不用改
	float size = distance(p0, center); 
	
	float clampdistance = clamp(0, 1, distance(float3(0,_Paramtest,0) ,center_ws));
	float param = remap(clampdistance,0,_effectordistance,0,1); 

	if(_Paramtest>center_ws.y){ //默认三角形
		outstream.Append(PackLightmappingVertex(IN[0])); 
		outstream.Append(PackLightmappingVertex(IN[1]));
		outstream.Append(PackLightmappingVertex(IN[2]));
		outstream.RestartStrip();
		return;

	}
	
	if(_Paramtest<-3){
		
		return;
	}
	if(distance(float3(0,_Paramtest,0),center_ws) > _effectordistance){ 

		param = distance(float3(0,_Paramtest,0) ,center_ws); 

	}

		if(Hash(pid*100)<_Density){
			float3 cubepos; 
			float3 cubescale;
			float randomnumber = Hash(pid*100 + 1);
			randomcueposscale(center,size,param,randomnumber,_FallDist,cubescale,cubepos);
			
			float3 pc0 = cubepos + float3(-1, -1, -1) * cubescale;
			float3 pc1 = cubepos + float3(+1, -1, -1) * cubescale; 
			float3 pc2 = cubepos + float3(-1, +1, -1) * cubescale;
			float3 pc3 = cubepos + float3(+1, +1, -1) * cubescale;
			float3 pc4 = cubepos + float3(-1, -1, +1) * cubescale;
			float3 pc5 = cubepos + float3(+1, -1, +1) * cubescale;
			float3 pc6 = cubepos + float3(-1, +1, +1) * cubescale;
			float3 pc7 = cubepos  + float3(+1, +1, +1) * cubescale;


			
			float lerpparam = param < _effectordistance ? param : 1;
			// float3 nc = (float3(-1, 0, 0));
			outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc2,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc0,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc6,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc4,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
			outstream.RestartStrip();

			// nc = (float3(1, 0, 0)); 
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc1,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc3,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc5,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc7,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
			outstream.RestartStrip();

			// nc = (float3(0, -1, 0));
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc0,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc1,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc4,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc5,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
			outstream.RestartStrip();

			// nc = (float3(0, 1, 0));
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc3,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc2,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc7,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc6,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
			outstream.RestartStrip();

			// nc = (float3(0, 0, -1));
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc1,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc0,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc3,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc2,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
			outstream.RestartStrip();

			// nc = (float3(0, 0, 1));
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc4,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc5,p2,lerpparam),IN[2].uv,IN[2].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc6,p0,lerpparam),IN[0].uv,IN[0].uv1) ) );
            outstream.Append( PackLightmappingVertex( RePackVoxelierLightVertex(lerpvertex(pc7,p1,lerpparam),IN[1].uv,IN[1].uv1) ) );
			outstream.RestartStrip();
			}
		return;
}

Interpolators MyLightmappingVertexProgram (VertexData v) {
	Interpolators i;
	v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
	v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;

    i.pos = UnityObjectToClipPos(v.vertex);

	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	return i;
}

float4 MyLightmappingFragmentProgram (Interpolators i) : SV_TARGET {
	UnityMetaInput surfaceData;
	surfaceData.Emission = GetEmission(i);
	float oneMinusReflectivity;
	surfaceData.Albedo = DiffuseAndSpecularFromMetallic(
		GetAlbedo(i), GetMetallic(i),
		surfaceData.SpecularColor, oneMinusReflectivity
	);

	float roughness = SmoothnessToRoughness(GetSmoothness(i)) * 0.5;
	surfaceData.Albedo += surfaceData.SpecularColor * roughness;

	return UnityMetaFragment(surfaceData);
}

#endif
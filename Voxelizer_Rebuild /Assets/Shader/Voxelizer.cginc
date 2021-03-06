#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
//custom include//
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Macros.hlsl"
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Random.hlsl" //in case of we want to use Hash function
#include "Packages/jp.keijiro.noiseshader/Shader/SimplexNoise3D.hlsl"
//custom include//
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	#if !defined(FOG_DISTANCE)
		#define FOG_DEPTH 1
	#endif
	#define FOG_ON 1
#endif

#if !defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
	#if defined(SHADOWS_SHADOWMASK) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)
		#define ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS 1
	#endif
#endif

#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
	#if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
		#define SUBTRACTIVE_LIGHTING 1
	#endif
#endif

float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _OcclusionMap;
float _OcclusionStrength;

sampler2D _EmissionMap;
float3 _Emission;

float _Cutoff;


float _Paramtest;
float _Scale;
float _Density;
float _FallDist;
float _Fluctuation;
float _Stretch;
float _flythreshold;
float _effectordistance;

struct fakelitv2g{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct litv2g{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct VertexData {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
};

struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;

	#if defined(BINORMAL_PER_FRAGMENT)
		float4 tangent : TEXCOORD2;
	#else
		float3 tangent : TEXCOORD2;
		float3 binormal : TEXCOORD3;
	#endif

	#if FOG_DEPTH
		float4 worldPos : TEXCOORD4;
	#else
		float3 worldPos : TEXCOORD4;
	#endif

	UNITY_SHADOW_COORDS(5)

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD6;
	#endif

	#if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
		float2 lightmapUV : TEXCOORD6;
	#endif
};
//custom function
float remap (float value, float from1, float to1, float from2, float to2) {
	return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
}
float4 lerpvertex(float3 newpos, float3 oldpos, float pragma){
	return float4(lerp(oldpos,newpos,pragma),1); 
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
//custom function
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

float GetAlpha (Interpolators i) {
	float alpha = _Color.a;
	#if !defined(_SMOOTHNESS_ALBEDO)
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	return alpha;
}

float3 GetTangentSpaceNormal (Interpolators i) {
	float3 normal = float3(0, 0, 1);
	#if defined(_NORMAL_MAP)
		normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	#endif
	#if defined(_DETAIL_NORMAL_MAP)
		float3 detailNormal =
			UnpackScaleNormal(
				tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale
			);
		detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
		normal = BlendNormals(normal, detailNormal);
	#endif
	return normal;
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

float GetOcclusion (Interpolators i) {
	#if defined(_OCCLUSION_MAP)
		return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
	#else
		return 1;
	#endif
}

float3 GetEmission (Interpolators i) {
	#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
		#if defined(_EMISSION_MAP)
			return tex2D(_EmissionMap, i.uv.xy) * _Emission;
		#else
			return _Emission;
		#endif
	#else
		return 0;
	#endif
}

void ComputeVertexLightColor (inout Interpolators i) {
	#if defined(VERTEXLIGHT_ON)
		i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos.xyz, i.normal
		);
	#endif
}

float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) *
		(binormalSign * unity_WorldTransformParams.w);
}

//this is //#vert programme
litv2g VoxelizerVertexProgram(VertexData v){
	litv2g g;
	g.vertex = v.vertex;
	g.normal = v.normal;
	g.tangent = v.tangent;
	g.uv = v.uv;
	g.uv1 = v.uv1;
	// float4 vertex : POSITION;
	// float3 normal : NORMAL;
	// float4 tangent : TANGENT;
	// float2 uv : TEXCOORD0;
	// float2 uv1 : TEXCOORD1;
	return g;
}
fakelitv2g repackVertexData(float4 vertex,float3 normal,float4 tangent,float2 uv, float2 uv1){
	//这里先打包好数据然后传给真正的vertex to interpolators程序，然后再传给fragment programme
	fakelitv2g o;
	o.vertex = vertex;
	o.normal = normal;
	o.tangent = tangent;
	o.uv = uv;
	o.uv1 = uv1;
	return o;
}
//this is use in geo programme
Interpolators g2v2i(fakelitv2g g){ 
	//这里的意思是，我们的把geo作为vertex来用，然后再在geo里面把真正的vertex输出出去
	//因为geo实际上也是做了一个vertex的作用，只不过他需要拿其他的点进行输入
	//这个程序里面唯一改变的只有顶点和法线，其他切线uv这些因为变成cube也不是很好计算。。暂时先用原来的或者给一个数值
	//要注意的是在几何着色器里面不需要在cliptopos了这里会做，那里就直接传一个模型空间的点即可
	Interpolators i;
	UNITY_INITIALIZE_OUTPUT(Interpolators, i);
	i.pos = UnityObjectToClipPos(g.vertex);
	i.worldPos.xyz = mul(unity_ObjectToWorld, g.vertex);
	#if FOG_DEPTH
		i.worldPos.w = i.pos.z;
	#endif
	i.normal = UnityObjectToWorldNormal(g.normal);

	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(g.tangent.xyz), g.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, g.tangent.w);
	#endif

	i.uv.xy = TRANSFORM_TEX(g.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(g.uv, _DetailTex);

	#if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
		i.lightmapUV = g.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
	#endif

	UNITY_TRANSFER_SHADOW(i, g.uv1);

	ComputeVertexLightColor(i);
	return i;

}
//this is use in geo programme
[maxvertexcount(24)]
void geom(triangle litv2g IN[3], uint pid : SV_PrimitiveID, inout TriangleStream<Interpolators> outstream){ 

	float3 p0 = IN[0].vertex.xyz; //这个东西还是叫vertex，此时就是普通的点传进去没做任何事
	float3 p1 = IN[1].vertex.xyz;
	float3 p2 = IN[2].vertex.xyz;
	float3 center = (p0 + p1 + p2) / 3;  
	float3 center_ws = mul(unity_ObjectToWorld,center); //这个用于计算的不用改
	float size = distance(p0, center); 
	
	float clampdistance = clamp(0, 1, distance(float3(0,_Paramtest,0) ,center_ws));
	float param = remap(clampdistance,0,_effectordistance,0,1); 

	if(_Paramtest>center_ws.y){ //默认三角形
		
		fakelitv2g o0; //这个要pass给真正的vertexprogramme用于返回interpolators
		fakelitv2g o1;
		fakelitv2g o2;
		o0.vertex = IN[0].vertex; //还是原来的vertex
		o1.vertex = IN[1].vertex;
		o2.vertex = IN[2].vertex;

		o0.normal = IN[0].normal; //还是原来的法线
		o1.normal = IN[1].normal;
		o2.normal = IN[2].normal;

		o0.tangent = IN[0].tangent; //还是原来的切线
		o1.tangent = IN[1].tangent;
		o2.tangent = IN[2].tangent;

		o0.uv = IN[0].uv; //还是原来的uv
		o1.uv = IN[1].uv;
		o2.uv = IN[2].uv;

		o0.uv1 = IN[0].uv1; //还是原来的uv1
		o1.uv1 = IN[1].uv1;
		o2.uv1 = IN[2].uv1;

		Interpolators realinput0;
		Interpolators realinput1;
		Interpolators realinput2;

		realinput0 = g2v2i(o0);
		realinput1 = g2v2i(o1);
		realinput2 = g2v2i(o2);

		//这里是我们直接传递了这个顶点，给真正的vertexprogramme，然后此时返回的是插值，这就是fragment 所需要的
		outstream.Append(realinput0); 
		outstream.Append(realinput1);
		outstream.Append(realinput2);
		outstream.RestartStrip();
		return;
		//也可以写成，不过还有一个结构体不知道是不是可以复用的 如果不行就改个名 其实内容都是一样的
		// outstream.Append( g2v2i( repackVertexData(IN[0].vertex,IN[0].normal,IN[0].tangent,IN[0].uv,IN[0].uv1) ) ); 
		// outstream.Append( g2v2i( repackVertexData(IN[1].vertex,IN[1].normal,IN[1].tangent,IN[1].uv,IN[1].uv1) ) ); 
		// outstream.Append( g2v2i( repackVertexData(IN[2].vertex,IN[2].normal,IN[2].tangent,IN[2].uv,IN[2].uv1) ) ); 
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
			float3 nc = (float3(-1, 0, 0));

			
									//lerp the vertex, then the normal,the tangent, the uv, the uv1,
			//now we get a fakelitv2g
			
			// outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc2,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc0,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc6,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc4,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.RestartStrip();

			nc = (float3(1, 0, 0));
			// outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[1].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc1,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc3,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc5,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc7,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.RestartStrip();

			nc = (float3(0, -1, 0));
			// outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc0,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc1,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc4,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc5,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.RestartStrip();

			nc = (float3(0, 1, 0));
			// outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[1].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc3,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc2,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc7,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc6,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.RestartStrip();

			nc = (float3(0, 0, -1));
			// outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc1,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc0,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc3,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc2,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.RestartStrip();

			nc = (float3(0, 0, 1));
			// outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
			// outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[0].uv));
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc4,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc5,p2,lerpparam), nc, IN[2].tangent, IN[2].uv, IN[2].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc6,p0,lerpparam), nc, IN[0].tangent, IN[0].uv, IN[0].uv1) ) );
			outstream.Append( g2v2i( repackVertexData(lerpvertex(pc7,p1,lerpparam), nc, IN[1].tangent, IN[1].uv, IN[1].uv1) ) );
			outstream.RestartStrip();
			}
		return;
}
Interpolators MyVertexProgram (VertexData v) {
	Interpolators i;
	UNITY_INITIALIZE_OUTPUT(Interpolators, i);
	i.pos = UnityObjectToClipPos(v.vertex);
	i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
	#if FOG_DEPTH
		i.worldPos.w = i.pos.z;
	#endif
	i.normal = UnityObjectToWorldNormal(v.normal);

	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
	#endif

	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

	#if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
		i.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
	#endif

	UNITY_TRANSFER_SHADOW(i, v.uv1);

	ComputeVertexLightColor(i);
	return i;
}

float FadeShadows (Interpolators i, float attenuation) {
	#if HANDLE_SHADOWS_BLENDING_IN_GI || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
		// UNITY_LIGHT_ATTENUATION doesn't fade shadows for us.
		#if ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
			attenuation = SHADOW_ATTENUATION(i);
		#endif
		float viewZ =
			dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
		float shadowFadeDistance =
			UnityComputeShadowFadeDistance(i.worldPos, viewZ);
		float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
		float bakedAttenuation =
			UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
		attenuation = UnityMixRealtimeAndBakedShadows(
			attenuation, bakedAttenuation, shadowFade
		);
	#endif

	return attenuation;
}

UnityLight CreateLight (Interpolators i) {
	UnityLight light;

	#if defined(DEFERRED_PASS) || SUBTRACTIVE_LIGHTING
		light.dir = float3(0, 1, 0);
		light.color = 0;
	#else
		#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
			light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
		#else
			light.dir = _WorldSpaceLightPos0.xyz;
		#endif

		UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
		attenuation = FadeShadows(i, attenuation);

		light.color = _LightColor0.rgb * attenuation;
	#endif

	return light;
}

float3 BoxProjection (
	float3 direction, float3 position,
	float4 cubemapPosition, float3 boxMin, float3 boxMax
) {
	#if UNITY_SPECCUBE_BOX_PROJECTION
		UNITY_BRANCH
		if (cubemapPosition.w > 0) {
			float3 factors =
				((direction > 0 ? boxMax : boxMin) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition);
		}
	#endif
	return direction;
}

void ApplySubtractiveLighting (
	Interpolators i, inout UnityIndirect indirectLight
) {
	#if SUBTRACTIVE_LIGHTING
		UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
		attenuation = FadeShadows(i, attenuation);

		float ndotl = saturate(dot(i.normal, _WorldSpaceLightPos0.xyz));
		float3 shadowedLightEstimate =
			ndotl * (1 - attenuation) * _LightColor0.rgb;
		float3 subtractedLight = indirectLight.diffuse - shadowedLightEstimate;
		subtractedLight = max(subtractedLight, unity_ShadowColor.rgb);
		subtractedLight =
			lerp(subtractedLight, indirectLight.diffuse, _LightShadowData.x);
		indirectLight.diffuse = min(subtractedLight, indirectLight.diffuse);
	#endif
}

UnityIndirect CreateIndirectLight (Interpolators i, float3 viewDir) {
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
		#if defined(LIGHTMAP_ON)
			indirectLight.diffuse =
				DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
			
			#if defined(DIRLIGHTMAP_COMBINED)
				float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(
					unity_LightmapInd, unity_Lightmap, i.lightmapUV
				);
				indirectLight.diffuse = DecodeDirectionalLightmap(
					indirectLight.diffuse, lightmapDirection, i.normal
				);
			#endif

			ApplySubtractiveLighting(i, indirectLight);
		#else
			indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
		#endif
		float3 reflectionDir = reflect(-viewDir, i.normal);
		Unity_GlossyEnvironmentData envData;
		envData.roughness = 1 - GetSmoothness(i);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos.xyz,
			unity_SpecCube0_ProbePosition,
			unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
		);
		float3 probe0 = Unity_GlossyEnvironment(
			UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
		);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos.xyz,
			unity_SpecCube1_ProbePosition,
			unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
		);
		#if UNITY_SPECCUBE_BLENDING
			float interpolator = unity_SpecCube0_BoxMin.w;
			UNITY_BRANCH
			if (interpolator < 0.99999) {
				float3 probe1 = Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
					unity_SpecCube0_HDR, envData
				);
				indirectLight.specular = lerp(probe1, probe0, interpolator);
			}
			else {
				indirectLight.specular = probe0;
			}
		#else
			indirectLight.specular = probe0;
		#endif

		float occlusion = GetOcclusion(i);
		indirectLight.diffuse *= occlusion;
		indirectLight.specular *= occlusion;

		#if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
			indirectLight.specular = 0;
		#endif
	#endif

	return indirectLight;
}

void InitializeFragmentNormal(inout Interpolators i) {
	float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif
	
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
	);
}

float4 ApplyFog (float4 color, Interpolators i) {
	#if FOG_ON
		float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
		#if FOG_DEPTH
			viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
		#endif
		UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
		float3 fogColor = 0;
		#if defined(FORWARD_BASE_PASS)
			fogColor = unity_FogColor.rgb;
		#endif
		color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
	#endif
	return color;
}

struct FragmentOutput {
	#if defined(DEFERRED_PASS)
		float4 gBuffer0 : SV_Target0;
		float4 gBuffer1 : SV_Target1;
		float4 gBuffer2 : SV_Target2;
		float4 gBuffer3 : SV_Target3;

		#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			float4 gBuffer4 : SV_Target4;
		#endif
	#else
		float4 color : SV_Target;
	#endif
};

FragmentOutput MyFragmentProgram (Interpolators i) {
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _Cutoff);
	#endif

	InitializeFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);

	float3 specularTint;
	float oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(
		GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity
	);
	#if defined(_RENDERING_TRANSPARENT)
		albedo *= alpha;
		alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
	#endif

	float4 color = UNITY_BRDF_PBS(
		albedo, specularTint,
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir,
		CreateLight(i), CreateIndirectLight(i, viewDir)
	);
	color.rgb += GetEmission(i);
	#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
		color.a = alpha;
	#endif

	FragmentOutput output;
	#if defined(DEFERRED_PASS)
		#if !defined(UNITY_HDR_ON)
			color.rgb = exp2(-color.rgb);
		#endif
		output.gBuffer0.rgb = albedo;
		output.gBuffer0.a = GetOcclusion(i);
		output.gBuffer1.rgb = specularTint;
		output.gBuffer1.a = GetSmoothness(i);
		output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
		output.gBuffer3 = color;

		#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			float2 shadowUV = 0;
			#if defined(LIGHTMAP_ON)
				shadowUV = i.lightmapUV;
			#endif
			output.gBuffer4 =
				UnityGetRawBakedOcclusions(shadowUV, i.worldPos.xyz);
		#endif
	#else
		output.color = ApplyFog(color, i);
	#endif
	return output;
}

#endif
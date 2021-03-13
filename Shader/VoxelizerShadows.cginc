#if !defined(MY_SHADOWS_INCLUDED)
#define MY_SHADOWS_INCLUDED

#include "UnityCG.cginc"
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Macros.hlsl"
#include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Random.hlsl" //in case of we want to use Hash function
#include "Packages/jp.keijiro.noiseshader/Shader/SimplexNoise3D.hlsl"
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	#if defined(_SEMITRANSPARENT_SHADOWS)
		#define SHADOWS_SEMITRANSPARENT 1
	#else
		#define _RENDERING_CUTOUT
	#endif
#endif

#if SHADOWS_SEMITRANSPARENT || defined(_RENDERING_CUTOUT)
	#if !defined(_SMOOTHNESS_ALBEDO)
		#define SHADOWS_NEED_UV 1
	#endif
#endif

float4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
float _Cutoff;

sampler3D _DitherMaskLOD;


float _Paramtest;
float _Scale;
float _Density;
float _FallDist;
float _Fluctuation;
float _Stretch;
float _flythreshold;
float _effectordistance;

struct VertexData {
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};
struct shadowv2g{ //pass this to geo
    float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};
struct InterpolatorsVertex {
	float4 position : SV_POSITION;
	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif
	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD1;
	#endif
};

struct Interpolators { //keep this in case of it return a empty struct
	#if SHADOWS_SEMITRANSPARENT
		UNITY_VPOS_TYPE vpos : VPOS;
	#else
		float4 positions : SV_POSITION;
	#endif

	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif
	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD1;
	#endif
};

float GetAlpha (Interpolators i) {
	float alpha = _Color.a;
	#if SHADOWS_NEED_UV
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	return alpha;
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
shadowv2g VoxelizerShadowVertexProgram(VertexData v){ //do nothing here;
    shadowv2g g;
    g.position = v.position;
    g.normal = v.normal;
    g.uv = v.uv;
    return g;
}
shadowv2g RePackShadowVertex(float4 position,float3 normal,float2 uv){
    shadowv2g g;
    g.position = position;
	g.normal  = normal;
	g.uv  = uv;
    return g;
}
InterpolatorsVertex PackShadowVertex (shadowv2g v) { //shadowv2g happended in geo
	InterpolatorsVertex i;
	#if defined(SHADOWS_CUBE)
		i.position = UnityObjectToClipPos(v.position);
		i.lightVec =
			mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
	#else
		i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
		i.position = UnityApplyLinearShadowBias(i.position);
	#endif

	#if SHADOWS_NEED_UV
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif
	return i;
}
[maxvertexcount(24)]
void VoxelizerShadowGeomProgram(triangle shadowv2g IN[3], uint pid : SV_PrimitiveID, inout TriangleStream<InterpolatorsVertex> outstream){ 
    float3 p0 = IN[0].position.xyz; 
	float3 p1 = IN[1].position.xyz;
	float3 p2 = IN[2].position.xyz;
	float3 center = (p0 + p1 + p2) / 3;  
	float3 center_ws = mul(unity_ObjectToWorld,center); //这个用于计算的不用改
	float size = distance(p0, center); 
	float clampdistance = clamp(0, 1, distance(float3(0,_Paramtest,0) ,center_ws));
	float param = remap(clampdistance,0,_effectordistance,0,1); 
	if(_Paramtest>center_ws.y){ //默认三角形
		//乜都5使做，直接pass回真正的vertexprograme返回真正的插值器
		outstream.Append(PackShadowVertex( IN[0] ));
		outstream.Append(PackShadowVertex( IN[1] ));
		outstream.Append(PackShadowVertex( IN[2] ));
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
			float3 nc = (float3(-1, 0, 0));
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc2,p0,lerpparam),nc,IN[0].uv) ) ); //重新打包顶点数据，然后传递给真正的顶点->插值程序
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc0,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc6,p0,lerpparam),nc,IN[0].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc4,p0,lerpparam),nc,IN[2].uv) ) );
			outstream.RestartStrip();

			nc = (float3(1, 0, 0)); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc1,p2,lerpparam),nc,IN[2].uv) ) ); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc3,p1,lerpparam),nc,IN[1].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc5,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc7,p1,lerpparam),nc,IN[1].uv) ) );
			outstream.RestartStrip();

			nc = (float3(0, -1, 0));
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc0,p2,lerpparam),nc,IN[2].uv) ) ); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc1,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc4,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc5,p2,lerpparam),nc,IN[2].uv) ) );
			outstream.RestartStrip();

			nc = (float3(0, 1, 0));
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc3,p1,lerpparam),nc,IN[1].uv) ) ); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc2,p0,lerpparam),nc,IN[0].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc7,p1,lerpparam),nc,IN[1].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc6,p0,lerpparam),nc,IN[0].uv) ) );
			outstream.RestartStrip();

			nc = (float3(0, 0, -1));
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc1,p2,lerpparam),nc,IN[2].uv) ) ); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc0,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc3,p1,lerpparam),nc,IN[1].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc2,p0,lerpparam),nc,IN[0].uv) ) );
			outstream.RestartStrip();

			nc = (float3(0, 0, 1));
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc4,p2,lerpparam),nc,IN[2].uv) ) ); 
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc5,p2,lerpparam),nc,IN[2].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc6,p0,lerpparam),nc,IN[0].uv) ) );
            outstream.Append( PackShadowVertex( RePackShadowVertex(lerpvertex(pc7,p1,lerpparam),nc,IN[1].uv) ) );
			outstream.RestartStrip();
			}
		return;
}

InterpolatorsVertex MyShadowVertexProgram (VertexData v) {
	InterpolatorsVertex i;
	#if defined(SHADOWS_CUBE)
		i.position = UnityObjectToClipPos(v.position);
		i.lightVec =
			mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
	#else
		i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
		i.position = UnityApplyLinearShadowBias(i.position);
	#endif

	#if SHADOWS_NEED_UV
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif
	return i;
}

float4 MyShadowFragmentProgram (Interpolators i) : SV_TARGET {
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _Cutoff);
	#endif

	#if SHADOWS_SEMITRANSPARENT
		float dither =
			tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a;
		clip(dither - 0.01);
	#endif
	
	#if defined(SHADOWS_CUBE)
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;
		return UnityEncodeCubeShadowDepth(depth);
	#else
		return 0;
	#endif
}

#if defined(SHADOWS_CUBE)

#endif

#endif
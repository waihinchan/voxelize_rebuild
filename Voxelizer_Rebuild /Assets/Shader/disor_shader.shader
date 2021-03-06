

Shader "Unlit/NewUnlitShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_alpha("alpha",range(0.0,1.0)) = 0.25
		_Thres("threshold", range(0.0,1.0)) = 0.5
		_Spead("spead",range(0,100)) = 5.0
		_AMP("amp",range(0,100)) = 10.0
		_Amount("amount",range(20,1000)) = 100
		_ON("on&off",float) = 1.0
		_Move("Move",float) = 0
		_TAmount("t",range(-10,10)) = 3
	}
	SubShader
	{
		Tags { "Queue" = "Transparent" "RenderType"="Transparent" }
		LOD 100
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			// vertex to graphic
			struct v2g
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};
			// graphic to fragment
			struct g2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Thres;
			float _alpha;
			float _AMP;
			float _Spead;
			float _Amount;
			float _ON;
			float _Move;
			float _TAmount;
			v2g vert (appdata v)
			{
				v2g o;
	
				o.vertex = v.vertex;
				
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				return o;
			}
			
			float4 explode(float4 position, float3 normal){   
			    float3 S = 0.5 * 1 * _TAmount * _TAmount * normal ;
				// float3 S = 0.5 * 3 * 2 * 2 * (float3(2,1,0) + normal) ;
			    return position + float4(S,0.0);
			}			

			[maxvertexcount(4)]
			void geom(triangle v2g IN[3], inout LineStream<g2f> lineStream)
			{
				
				g2f o;
				if(_Move==1.0){
				float3 v1 = IN[1].vertex - IN[0].vertex;
				float3 v2 = IN[2].vertex - IN[0].vertex;
				float3 norm = normalize(cross(v1, v2));
				for(int i =0; i<3; i++){
					g2f o;
					o.vertex = explode(IN[i].vertex, norm);
					o.vertex = UnityObjectToClipPos(o.vertex);
					o.uv = IN[i].uv;
					lineStream.Append(o);
				}						
			}
				else{
				for(int i = 0; i < 3; i++){
					float amount = 1 / _Amount;
					IN[i].vertex.x += max(0,cos(_Time.y*_Spead + IN[i].vertex.z*_AMP)) * amount * _ON ;
					IN[i].vertex.y += max(0,sin(_Time.y*_Spead + IN[i].vertex.z*_AMP)) * amount * _ON;
					o.vertex = IN[i].vertex;
					o.vertex = UnityObjectToClipPos(o.vertex);
					o.uv =  IN[i].uv ;
					lineStream.Append(o);
				}
				}

				
			}
			
			fixed4 frag (g2f i) : SV_Target
			{	
				if(_Move==1.0){
				fixed4 col = tex2D(_MainTex, i.uv);
				col.a = _alpha;
				clip(col.r - _Thres);
				clip(col.b - _Thres);
				// clip(col.g - _Thres);
				return col;
				}
				else{
					fixed4 col = tex2D(_MainTex, i.uv);
					return col;
				}
			}
			ENDCG
		}
	}
}
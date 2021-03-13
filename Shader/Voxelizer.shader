Shader "Unlit/Voxelizer"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Paramtest ("Paramtest", range(-3,3)) = 3
        _Scale("Sacle" , range(1,10)) = 1
        _Density("Density",range(0,1)) = 0.5
        _FallDist("FallDist",range(0,1000)) = 500
        _Fluctuation("Fluctuation",range(0,50)) = 1
        _Stretch("Stretch",range(0,10)) = 1
        _flythreshold("flythreshold",float) = 0.4
        _effectordistance("effectordistance",range(0.1,0.5)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM


            #pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
            // use geometry

            // make fog work
            // #pragma multi_compile_fog

            #include "UnityCG.cginc" //not sure if this will affect the lit shader
            #include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Macros.hlsl"
            #include "Library\PackageCache\com.unity.render-pipelines.core@7.5.3\ShaderLibrary\Random.hlsl" //in case of we want to use Hash function
            #include "Packages/jp.keijiro.noiseshader/Shader/SimplexNoise3D.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                // float4 normal : NORMAL; // if need a normal
                float2 uv : TEXCOORD0;
                // UNITY_VERTEX_INPUT_INSTANCE_ID
            };



            struct v2g
            {
                float2 uv : TEXCOORD0;
                // UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                // UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct g2f{
                float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
                // UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            float4 _MainTex_ST; 
            float _Paramtest;
            float _Scale;
            float _Density;
            float _FallDist;
            float _Fluctuation;
            float _Stretch;
            float _flythreshold;
            float _effectordistance;

            v2g vert(appdata v){
                v2g o;
                // o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertex = v.vertex;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // UNITY_TRANSFER_FOG(o,o.vertex);
                // UNITY_TRANSFER_INSTANCE_ID(v,o);
                return o;
            }

            g2f packvertexdata(float3 pos, float2 uv){
                g2f output;
                output.uv = uv;
                output.vertex = UnityObjectToClipPos(pos);
                
                //if need a normal
                return output;
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
            float3 lerpvertex(float3 newpos, float3 oldpos, float pragma){
                return lerp(oldpos,newpos,pragma); 
            }


            float remap (float value, float from1, float to1, float from2, float to2) {
                return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
            }

            [maxvertexcount(24)] // 6 * 4 ? 一个面需要4个点  而不是8个点
            void geom(triangle v2g IN[3], uint pid : SV_PrimitiveID, inout TriangleStream<g2f> outstream){ 
                
                
                
                
                float3 p0 = IN[0].vertex;
                float3 p1 = IN[1].vertex;
                float3 p2 = IN[2].vertex;
                float3 center = (p0 + p1 + p2) / 3;  
                float3 center_ws = mul(unity_ObjectToWorld,center);
                float size = distance(p0, center); 
                
                float clampdistance = clamp(0, 1, distance(float3(0,_Paramtest,0) ,center_ws));
                float param = remap(clampdistance,0,_effectordistance,0,1); 


                if(_Paramtest>center_ws.y){
                    
                    g2f o0;
                    g2f o1;
                    g2f o2;
                    o0.vertex = UnityObjectToClipPos(p0);
                    o1.vertex = UnityObjectToClipPos(p1);
                    o2.vertex = UnityObjectToClipPos(p2);
                    o0.uv = IN[0].uv;
                    o1.uv = IN[1].uv;
                    o2.uv = IN[2].uv;
                    outstream.Append(o0);
                    outstream.Append(o1);
                    outstream.Append(o2);
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
                        outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
                        outstream.RestartStrip();

                        outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[1].uv));
                        outstream.RestartStrip();

                        outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
                        outstream.RestartStrip();

                        outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[1].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
                        outstream.RestartStrip();

                        outstream.Append(packvertexdata(lerpvertex(pc1,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc0,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc3,p1,lerpparam),IN[1].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc2,p0,lerpparam),IN[0].uv));
                        outstream.RestartStrip();

                        outstream.Append(packvertexdata(lerpvertex(pc4,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc5,p2,lerpparam),IN[2].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc6,p0,lerpparam),IN[0].uv));
                        outstream.Append(packvertexdata(lerpvertex(pc7,p1,lerpparam),IN[0].uv));
                        outstream.RestartStrip();
                        }
                    return;
                // }




                    
                            
                    

                }





            fixed4 frag (g2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                col += fixed4(0,0.1,0.5,1); //add emmsion here.
                return col;
            }

            ENDCG
        }
    }
}

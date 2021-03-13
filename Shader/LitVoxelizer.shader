Shader "Custom/LitVoxelizer" {

	Properties {
		_Color ("Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}

		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1

		[NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" {}
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.1

		[NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {}
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1

		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {}
		_Emission ("Emission", Color) = (0, 0, 0)

		[NoScaleOffset] _DetailMask ("Detail Mask", 2D) = "white" {}
		_DetailTex ("Detail Albedo", 2D) = "gray" {}
		[NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
		_DetailBumpScale ("Detail Bump Scale", Float) = 1

		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
		_Paramtest ("Paramtest", range(-3,3)) = 3
        _Scale("Sacle" , range(1,10)) = 1
        _Density("Density",range(0,1)) = 0.5
        _FallDist("FallDist",range(0,1000)) = 500
        _Fluctuation("Fluctuation",range(0,50)) = 1
        _Stretch("Stretch",range(0,10)) = 1
        _flythreshold("flythreshold",float) = 0.4
        _effectordistance("effectordistance",range(0.1,0.5)) = 0.1

		[HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector] _DstBlend ("_DstBlend", Float) = 0
		[HideInInspector] _ZWrite ("_ZWrite", Float) = 1
		_EmissionHsvm1 ("EmissionHsvm1", Color) = (0, 0, 0,1)
		_EmissionHsvm2 ("EmissionHsvm2", Color) = (0, 0, 0,1)
		_TransitionColor ("TransitionColor", Color) = (0, 0, 0,1)
		_LineColor ("LineColor", Color) = (0, 0, 0,1)
		
		
	}

	CGINCLUDE

	#define BINORMAL_PER_FRAGMENT
	#define FOG_DISTANCE

	ENDCG

	SubShader {

		Pass {
			Tags {
				"LightMode" = "ForwardBase"
			}
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM

			#pragma target 3.0

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			// #include "My Lighting.cginc" //
			#include "Assets/Shader/utils.cginc"
			#include "Assets/Shader/Voxelizer.cginc"
			
			#define FORWARD_BASE_PASS
			#pragma vertex VoxelizerVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma geometry geom

			ENDCG
		}

		Pass {
			Tags {
				"LightMode" = "ForwardAdd"
			}

			Blend [_SrcBlend] One
			ZWrite Off

			CGPROGRAM

			#pragma target 3.0

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			
			// #include "My Lighting.cginc"
			#include "Assets/Shader/utils.cginc"
			#include "Assets/Shader/Voxelizer.cginc"
			#pragma vertex VoxelizerVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma geometry geom

			ENDCG
		}

		Pass {
			Tags {
				"LightMode" = "Deferred"
			}

			CGPROGRAM

			#pragma target 3.0
			#pragma exclude_renderers nomrt

			#pragma shader_feature _ _RENDERING_CUTOUT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma multi_compile_prepassfinal

			// #include "My Lighting.cginc"
			#include "Assets/Shader/utils.cginc"
			#include "Assets/Shader/Voxelizer.cginc"
			#pragma vertex VoxelizerVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma geometry geom

			#define DEFERRED_PASS

			ENDCG
		}

		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM

			#pragma target 3.0

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SEMITRANSPARENT_SHADOWS
			#pragma shader_feature _SMOOTHNESS_ALBEDO

			#pragma multi_compile_shadowcaster
			
			#include "Assets/Shader/utils.cginc"
			#include "Assets/Shader/VoxelizerShadows.cginc"
			#pragma vertex VoxelizerShadowVertexProgram
			#pragma fragment MyShadowFragmentProgram
			#pragma geometry VoxelizerShadowGeomProgram

			// #include "My Shadows.cginc"
			ENDCG
		}

		Pass {
			Tags {
				"LightMode" = "Meta"
			}

			Cull Off

			CGPROGRAM

			#pragma vertex VoxelierLightingMapVertexProgram
			#pragma geometry VoxelierLightingMapgeom
			#pragma fragment MyLightmappingFragmentProgram

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP

			#include "Assets/Shader/utils.cginc"
			#include "Assets/Shader/VoxelizerLightingMap.cginc"
			// #include "My Lightmapping.cginc"

			ENDCG
		}
	}

	// CustomEditor "MyLightingShaderGUI"
}
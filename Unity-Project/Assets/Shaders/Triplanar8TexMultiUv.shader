﻿//PGRTerrain: Procedural Generation and Rendering of Terrain
//DH2323 Course Project in KTH
//Triplanar8TexMultiUv.shader
//Yang Zhou: yanzho@kth.se
//Yanbo Huang: yanboh@kth.se
//Huiting Wang: huitingw@kth.se
//2015.5

// Triplanar texturing with bump mapping (up to 8 textures with their normal maps)
// * use world position scaled by tiling factor as uvw coordinate
// * project the normal vector of each fragment onto x/y/z axises to get weight
// * blend three samples (using xy, xz, yz components) based on weights
// * use 2 3D splatmaps to control blending of different textures
// * use two passes to render 2 texture groups (8 textures + 8 normal maps)
// * apply multi-UV mixing to reduce tiling artifact

Shader "PCGTerrain/Triplanar8TexMultiUv" 
{
	Properties {
		//First group of 4 tex
		_ColorTexR1 ("Color Tex (R1)", 2D) = "white" {}
		_NormalMapR1 ("Normal Map (R1)", 2D) = "bump" {}

		_ColorTexG1 ("Color Tex (G1)", 2D) = "white" {}
		_NormalMapG1 ("Normal Map (G1)", 2D) = "bump" {}

		_ColorTexB1 ("Color Tex (B1)", 2D) = "white" {}
		_NormalMapB1 ("Normal Map (B1)", 2D) = "bump" {}

		_ColorTexA1 ("Color Tex (A1)", 2D) = "white" {}
		_NormalMapA1 ("Normal Map (A1)", 2D) = "bump" {}
		
		_MatControl1("Mat Blend Weight (1)",3D) = "red" {}

		_UvOctave1("UV Scale Octave (1)",Vector) = (0.25,0.25,0.25,0.25)
		_BrightnessComp1("UV Scale Brightness Compensate (1)",Vector) = (1.5,1.5,1.5,1.5)
		_Desat1("Saturation after modulation (1)",Vector) = (0.9,0.9,0.9,0.9)

		//Second group of 4 tex
		_ColorTexR2 ("Color Tex (R2)", 2D) = "black" {}
		_NormalMapR2 ("Normal Map (R2)", 2D) = "black" {}

		_ColorTexG2 ("Color Tex (G2)", 2D) = "black" {}
		_NormalMapG2 ("Normal Map (G2)", 2D) = "bump" {}

		_ColorTexB2 ("Color Tex (B2)", 2D) = "black" {}
		_NormalMapB2 ("Normal Map (B2)", 2D) = "bump" {}

		_ColorTexA2 ("Color Tex (A2)", 2D) = "black" {}
		_NormalMapA2 ("Normal Map (A2)", 2D) = "bump" {}
		
		_MatControl2("Mat Blend Weight (2)",3D) = "black" {}

		_UvOctave2("UV Scale Octave (2)",Vector) = (0.25,0.25,0.25,0.25)
		_BrightnessComp2("UV Scale Brightness Compensate (2)",Vector) = (1.5,1.5,1.5,1.5)
		_Desat2("Saturation after modulation (2)",Vector) = (0.9,0.9,0.9,0.9)

		//Common variables
		_Tile("Texture Tile Factor",Range(0.1,1)) = 0.2
		_DetailTile("Detail Texture Tile Factor",Range(0.5, 5)) = 1
		_Offset("Terrain Origin Offset",Vector) = (0,0,0,1)
		_Scale("Terrain Scale (inv real world size)",Vector) = (1,1,1,1) //_Scale = 1 / (RealWorld Size)
		_Specular("Specular Color", Color) = (0,0,0)
		_Smoothness("Smoothness", Range(0,1)) = 0
	}
	SubShader 
	{
		CGINCLUDE
		struct Input 
		{
			float3 worldPos;
			fixed3 worldNormal;
			INTERNAL_DATA
		};

		inline fixed3 desaturate(fixed3 color, fixed amount)
		{
			//Desaturate the final color a little bit
			//grayscale coeffcient = 0.3, 0.59, 0.11
			fixed intensity = dot(color, fixed3(0.3, 0.59, 0.11));
			return lerp(fixed3(intensity, intensity, intensity), color, amount);
		}
		ENDCG

		//PASS 1
		Tags { "RenderType"="Opaque" }
		LOD 450
		Cull Off
		CGPROGRAM
		#pragma surface surf StandardSpecular fullforwardshadows
		#pragma target 3.0
		
		uniform sampler2D _ColorTexR1;
		uniform sampler2D _NormalMapR1;
		uniform sampler2D _ColorTexG1;
		uniform sampler2D _NormalMapG1;
		uniform sampler2D _ColorTexB1;
		uniform sampler2D _NormalMapB1;
		uniform sampler2D _ColorTexA1;
		uniform sampler2D _NormalMapA1;

		uniform sampler3D _MatControl1;

		uniform half4 _UvOctave1;
		uniform half4 _BrightnessComp1;
		uniform fixed4 _Desat1;

		uniform half _Tile;
		uniform half _DetailTile;
		uniform half4 _Offset;
		uniform half4 _Scale;
		uniform fixed3 _Specular;
		uniform fixed _Smoothness;

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) 
		{
			//the weight for blending different textures
			fixed4 splat_blend_weight = tex3D(_MatControl1, (IN.worldPos - _Offset.xyz) * _Scale.xyz);

			//the weight for blending three samples from the same texture (triplanar)
			//subtle notification: must use a flat float3(0,0,1) here
			//get world normal vector as blending weight
			fixed3 triplanar_blend_weight = abs(WorldNormalVector(IN,fixed3(0,0,1)));
			triplanar_blend_weight /= (triplanar_blend_weight.x + triplanar_blend_weight.y + triplanar_blend_weight.z);			
			
			//clamp the uv scale
			_UvOctave1 = clamp(_UvOctave1, half4(0.125,0.125,0.125,0.125), half4(1,1,1,1));

			float3 scaledPos = IN.worldPos * _Tile;

			o.Albedo = fixed4(0,0,0,0);
			//multiply two samples sampled by different uv scales -> desaturate the result color -> compensate the brightness
			//Color XY plane
			o.Albedo += triplanar_blend_weight.z * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR1, scaledPos.xy) * tex2D(_ColorTexR1, scaledPos.xy * -_UvOctave1.r), _Desat1.r ) * _BrightnessComp1.r + 
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG1, scaledPos.xy) * tex2D(_ColorTexG1, scaledPos.xy * -_UvOctave1.g), _Desat1.g ) * _BrightnessComp1.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB1, scaledPos.xy) * tex2D(_ColorTexB1, scaledPos.xy * -_UvOctave1.b), _Desat1.b ) * _BrightnessComp1.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA1, scaledPos.xy) * tex2D(_ColorTexA1, scaledPos.xy * -_UvOctave1.a), _Desat1.a ) * _BrightnessComp1.a 
								);
								
			//Color YZ plane
			o.Albedo += triplanar_blend_weight.x * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR1, scaledPos.yz) * tex2D(_ColorTexR1, scaledPos.yz * -_UvOctave1.r), _Desat1.r ) * _BrightnessComp1.r +
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG1, scaledPos.yz) * tex2D(_ColorTexB1, scaledPos.yz * -_UvOctave1.g), _Desat1.g ) * _BrightnessComp1.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB1, scaledPos.yz) * tex2D(_ColorTexG1, scaledPos.yz * -_UvOctave1.b), _Desat1.b ) * _BrightnessComp1.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA1, scaledPos.yz) * tex2D(_ColorTexA1, scaledPos.yz * -_UvOctave1.a), _Desat1.a ) * _BrightnessComp1.a 
								);
			//Color XZ plane
			o.Albedo += triplanar_blend_weight.y * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR1, scaledPos.xz) * tex2D(_ColorTexR1, scaledPos.xz * -_UvOctave1.r), _Desat1.r ) * _BrightnessComp1.r +
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG1, scaledPos.xz) * tex2D(_ColorTexG1, scaledPos.xz * -_UvOctave1.g), _Desat1.g ) * _BrightnessComp1.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB1, scaledPos.xz) * tex2D(_ColorTexB1, scaledPos.xz * -_UvOctave1.b), _Desat1.b ) * _BrightnessComp1.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA1, scaledPos.xz) * tex2D(_ColorTexA1, scaledPos.xz * -_UvOctave1.a), _Desat1.a ) * _BrightnessComp1.a
								);

			//apply normal maps
			fixed4 nrm = fixed4(0,0,0,0);
			//Normal XY plane
			nrm += triplanar_blend_weight.z * (
								splat_blend_weight.r * tex2D(_NormalMapR1, scaledPos.xy) +
								splat_blend_weight.g * tex2D(_NormalMapG1, scaledPos.xy) +
								splat_blend_weight.b * tex2D(_NormalMapB1, scaledPos.xy) +
								splat_blend_weight.a * tex2D(_NormalMapA1, scaledPos.xy)
								);
			//Normal YZ plane
			nrm += triplanar_blend_weight.x * (
								splat_blend_weight.r * tex2D(_NormalMapR1, scaledPos.yz) +
								splat_blend_weight.g * tex2D(_NormalMapG1, scaledPos.yz) +
								splat_blend_weight.b * tex2D(_NormalMapB1, scaledPos.yz) +
								splat_blend_weight.a * tex2D(_NormalMapA1, scaledPos.yz)
								);
			//Normal XZ plane
			nrm += triplanar_blend_weight.y * (
								splat_blend_weight.r * tex2D(_NormalMapR1, scaledPos.xz) + 
								splat_blend_weight.g * tex2D(_NormalMapG1, scaledPos.xz) + 
								splat_blend_weight.b * tex2D(_NormalMapB1, scaledPos.xz) + 
								splat_blend_weight.a * tex2D(_NormalMapA1, scaledPos.xz)
								);

			o.Normal = normalize(UnpackNormal(nrm));	
	
			o.Specular = _Specular;
			o.Smoothness = _Smoothness;
			o.Alpha = 1;
		}
		ENDCG

		//PASS 2: essentially the same as PASS 1, except that rendertype is transparent
		//and we add decal:add keyword to add the output of PASS 2 on that of PASS 1 to get the final color
		Tags { "RenderType"="Transparent" }
		LOD 450
		Cull Off

		CGPROGRAM
		#pragma surface surf StandardSpecular fullforwardshadows decal:add
		#pragma target 3.0

		uniform sampler2D _ColorTexR2;
		uniform sampler2D _NormalMapR2;
		uniform sampler2D _ColorTexG2;
		uniform sampler2D _NormalMapG2;
		uniform sampler2D _ColorTexB2;
		uniform sampler2D _NormalMapB2;
		uniform sampler2D _ColorTexA2;
		uniform sampler2D _NormalMapA2;

		uniform sampler3D _MatControl2;

		uniform half4 _UvOctave2;
		uniform half4 _BrightnessComp2;
		uniform fixed4 _Desat2;

		uniform half _Tile;
		uniform half _DetailTile;
		uniform half4 _Offset;
		uniform half4 _Scale;
		uniform fixed3 _Specular;
		uniform fixed _Smoothness;

		void surf (Input IN, inout SurfaceOutputStandardSpecular o) 
		{
			fixed4 splat_blend_weight = tex3D(_MatControl2, (IN.worldPos - _Offset.xyz) * _Scale.xyz);

			fixed3 triplanar_blend_weight = abs(WorldNormalVector(IN,fixed3(0,0,1))); //weird here, must use a flat float3(0,0,1)	
			triplanar_blend_weight /= (triplanar_blend_weight.x + triplanar_blend_weight.y + triplanar_blend_weight.z);			
			
			_UvOctave2 = clamp(_UvOctave2, half4(0.125,0.125,0.125,0.125), half4(1,1,1,1));

			float3 scaledPos = IN.worldPos * _Tile;

			o.Albedo = fixed4(0,0,0,0);
			//Color XY plane
			o.Albedo += triplanar_blend_weight.z * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR2, scaledPos.xy) * tex2D(_ColorTexR2, scaledPos.xy * -_UvOctave2.r), _Desat2.r ) * _BrightnessComp2.r + 
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG2, scaledPos.xy) * tex2D(_ColorTexG2, scaledPos.xy * -_UvOctave2.g), _Desat2.g ) * _BrightnessComp2.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB2, scaledPos.xy) * tex2D(_ColorTexB2, scaledPos.xy * -_UvOctave2.b), _Desat2.b ) * _BrightnessComp2.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA2, scaledPos.xy) * tex2D(_ColorTexA2, scaledPos.xy * -_UvOctave2.a), _Desat2.a ) * _BrightnessComp2.a 
								);
								
			//Color YZ plane
			o.Albedo += triplanar_blend_weight.x * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR2, scaledPos.yz) * tex2D(_ColorTexR2, scaledPos.yz * -_UvOctave2.r), _Desat2.r ) * _BrightnessComp2.r +
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG2, scaledPos.yz) * tex2D(_ColorTexB2, scaledPos.yz * -_UvOctave2.g), _Desat2.g ) * _BrightnessComp2.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB2, scaledPos.yz) * tex2D(_ColorTexG2, scaledPos.yz * -_UvOctave2.b), _Desat2.b ) * _BrightnessComp2.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA2, scaledPos.yz) * tex2D(_ColorTexA2, scaledPos.yz * -_UvOctave2.a), _Desat2.a ) * _BrightnessComp2.a 
								);
			//Color XZ plane
			o.Albedo += triplanar_blend_weight.y * (
								splat_blend_weight.r * desaturate( tex2D(_ColorTexR2, scaledPos.xz) * tex2D(_ColorTexR2, scaledPos.xz * -_UvOctave2.r), _Desat2.r ) * _BrightnessComp2.r +
								splat_blend_weight.g * desaturate( tex2D(_ColorTexG2, scaledPos.xz) * tex2D(_ColorTexG2, scaledPos.xz * -_UvOctave2.g), _Desat2.g ) * _BrightnessComp2.g +
								splat_blend_weight.b * desaturate( tex2D(_ColorTexB2, scaledPos.xz) * tex2D(_ColorTexB2, scaledPos.xz * -_UvOctave2.b), _Desat2.b ) * _BrightnessComp2.b +
								splat_blend_weight.a * desaturate( tex2D(_ColorTexA2, scaledPos.xz) * tex2D(_ColorTexA2, scaledPos.xz * -_UvOctave2.a), _Desat2.a ) * _BrightnessComp2.a
								);


			fixed4 nrm = fixed4(0,0,0,0);
			//Normal XY plane
			nrm += triplanar_blend_weight.z * (
								splat_blend_weight.r * tex2D(_NormalMapR2, scaledPos.xy) +
								splat_blend_weight.g * tex2D(_NormalMapG2, scaledPos.xy) +
								splat_blend_weight.b * tex2D(_NormalMapB2, scaledPos.xy) +
								splat_blend_weight.a * tex2D(_NormalMapA2, scaledPos.xy)
								);
			//Normal YZ plane
			nrm += triplanar_blend_weight.x * (
								splat_blend_weight.r * tex2D(_NormalMapR2, scaledPos.yz) +
								splat_blend_weight.g * tex2D(_NormalMapG2, scaledPos.yz) +
								splat_blend_weight.b * tex2D(_NormalMapB2, scaledPos.yz) +
								splat_blend_weight.a * tex2D(_NormalMapA2, scaledPos.yz)
								);
			//Normal XZ plane
			nrm += triplanar_blend_weight.y * (
								splat_blend_weight.r * tex2D(_NormalMapR2, scaledPos.xz) + 
								splat_blend_weight.g * tex2D(_NormalMapG2, scaledPos.xz) + 
								splat_blend_weight.b * tex2D(_NormalMapB2, scaledPos.xz) + 
								splat_blend_weight.a * tex2D(_NormalMapA2, scaledPos.xz)
								);

			o.Normal = normalize(UnpackNormal(nrm));	
	
			o.Specular = _Specular;
			o.Smoothness = _Smoothness;
			o.Alpha = 1;
		}
		ENDCG
	} 
	//comment FallBack when developing
	//FallBack "Diffuse"
}

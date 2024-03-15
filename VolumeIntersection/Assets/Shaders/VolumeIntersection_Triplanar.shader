Shader "VolumeIntersection/VisibleTriplanar"
{
    Properties
    {
        [Header(Stencil)]
        _StencilRef ("StencilRef ID [0;255]", Float) = 5
        [Enum(UnityEngine.Rendering.CompareFunction)] _Compare ("Stencil Comparison", Int) = 2
        [Enum(UnityEngine.Rendering.StencilOp)] _Pass ("Stencil Operation", Int) = 2

        [Header(Visuals)]
        _Color("Color", Color) = (1,1,1,1) 
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Sharpness ("Blend sharpness", Range(1, 64)) = 1
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }

        Pass
        {
            Stencil
			{
				Ref[_StencilRef]
				Comp[_Compare]
                Pass [_Pass]
			}

            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float4 _Color;
            float _Sharpness;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            // Reconstructs view position from just the pixel position and the camera depth texture
            float3 ViewSpacePosAtPixelPosition(float2 vpos)
            {
                float2 uv = vpos * _CameraDepthTexture_TexelSize.xy;
                float3 viewSpaceRay = mul(unity_CameraInvProjection, float4(uv * 2.0 - 1.0, 1.0, 1.0) * _ProjectionParams.z);

                float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(uv, 0.0, 0.0));
                return viewSpaceRay * Linear01Depth(rawDepth);
            }

            //Generates world normal from position
            half3 GetWorldNormal(float3 ipos)
            {
                float3 viewSpacePos_c = ViewSpacePosAtPixelPosition(ipos.xy);

                // get view space position at 1 pixel offsets in each major direction
                half3 viewSpacePos_l = ViewSpacePosAtPixelPosition(ipos.xy + float2(-1.0, 0.0));
                half3 viewSpacePos_r = ViewSpacePosAtPixelPosition(ipos.xy + float2( 1.0, 0.0));
                half3 viewSpacePos_d = ViewSpacePosAtPixelPosition(ipos.xy + float2( 0.0,-1.0));
                half3 viewSpacePos_u = ViewSpacePosAtPixelPosition(ipos.xy + float2( 0.0, 1.0));
 
                // get the difference between the current and each offset position
                half3 l = viewSpacePos_c - viewSpacePos_l;
                half3 r = viewSpacePos_r - viewSpacePos_c;
                half3 d = viewSpacePos_c - viewSpacePos_d;
                half3 u = viewSpacePos_u - viewSpacePos_c;
 
                // pick horizontal and vertical diff with the smallest z difference
                half3 h = abs(l.z) < abs(r.z) ? l : r;
                half3 v = abs(d.z) < abs(u.z) ? d : u;
 
                // get view space normal from the cross product of the two smallest offsets
                half3 viewNormal = normalize(cross(h, v));
 
                // transform normal from view space to world space
                half3 worldNormal = mul((float3x3)unity_MatrixInvV, viewNormal);
                return worldNormal;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half3 worldNormal = GetWorldNormal(i.pos);

                //Basic Triplanar Projection
                //calculate UV coordinates for three projections
                float3 viewSpacePos = ViewSpacePosAtPixelPosition(i.pos.xy);
                float3 worldPos = mul(unity_CameraToWorld, float4(viewSpacePos * float3(1.0, 1.0,-1.0), 1.0));

                /*
                //translates world pos into object pos - not always wanted
                worldPos = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
                */

				float2 uv_front = TRANSFORM_TEX(worldPos.xy, _MainTex);
				float2 uv_side = TRANSFORM_TEX(worldPos.zy, _MainTex);
				float2 uv_top = TRANSFORM_TEX(worldPos.xz, _MainTex);
				
				//read texture at uv position of the three projections
				fixed4 col_front = tex2D(_MainTex, uv_front);
				fixed4 col_side = tex2D(_MainTex, uv_side);
				fixed4 col_top = tex2D(_MainTex, uv_top);

				//generate weights from world normals
				float3 weights = worldNormal;
				//show texture on both sides of the object (positive and negative)
				weights = abs(weights);
				//make the transition sharper
				weights = pow(weights, _Sharpness);
				//make it so the sum of all components is 1
				weights = weights / (weights.x + weights.y + weights.z);

				//combine weights with projected colors
				col_front *= weights.z;
				col_side *= weights.x;
				col_top *= weights.y;

				//combine the projected colors
				fixed4 col = col_front + col_side + col_top;

				//multiply texture color with tint color
				col *= _Color;
				return col;
            }
            ENDCG
        }
    }
}
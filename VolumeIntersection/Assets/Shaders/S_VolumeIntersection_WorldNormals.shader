Shader "VolumeIntersection/WorldNormals"
{
    Properties
    {
        _StencilRef ("StencilRef ID [0;255]", Float) = 5
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }

        Pass
        {
            Stencil
			{
				Ref[_StencilRef]
				Comp Equal
			}

            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

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
                // visualize normal (assumes you're using linear space rendering)
                half3 worldNormal = GetWorldNormal(i.pos);
                half4 normalVisual = half4(GammaToLinearSpace(worldNormal.xyz * 0.5 + 0.5), 1.0);
                return normalVisual; 
            }
            ENDCG
        }
    }
}
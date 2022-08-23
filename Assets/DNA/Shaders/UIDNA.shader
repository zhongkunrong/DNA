Shader "ZXShader/UI/DNA"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("混合模式", Int) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("剔除模式", Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("深度测试", Int) = 4

        _MainTex ("序列图", 2D) = "white" { }
        _TextureXY ("XY:序列图宽高 Z:焦距 W:聚焦程度", Vector) = (1, 1, 1, 1)

        _Scale1 ("焦距大小", Range(0, 2)) = 0.25
        _Scale2 ("远近大小", Range(0, 2)) = 0.25
        _Scale3 ("总体大小", Range(0, 4)) = 1
        _Alpha1 ("焦距透明", Range(0, 1)) = 0.5
        _Alpha2 ("大小透明", Range(0, 1)) = 0.3
        _Alpha3 ("总体透明", Range(0, 1)) = 1
        _BillboardOffset ("广告牌参数", Float) = 0
    }
    SubShader
    {
        Tags { "IgnoreProjector" = "True" "Queue" = "Transparent" "RenderType" = "Transparent" "PreviewType" = "Plane" }
        LOD 100

        Pass
        {
            Blend SrcAlpha [_DstBlend]
            Cull [_CullMode]
            ZTest [_ZTest]
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;//xy:uv z:焦距 w:顶点色r
                half alpha : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half4 _TextureXY;
            half _Scale1;
            half _Scale2;
            half _Scale3;
            half _Alpha1;
            half _Alpha2;
            half _Alpha3;
            half _BillboardOffset;

            v2f vert(appdata v)
            {
                v2f o;

                VertexPositionInputs vertexPos = GetVertexPositionInputs(half4(0, 0, v.vertex.z, 1));
                half depth = vertexPos.positionWS.z - _WorldSpaceCameraPos.z;
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.z = abs(abs(depth) - _TextureXY.z);
                o.uv.w = v.color.r;
                o.alpha = saturate(pow(0.5 * depth - 1, 3) + 1);

                //广告牌
                half2 offset = (v.uv.xy - 0.5) * _BillboardOffset * v.color.r;
                half4 vertex = mul(UNITY_MATRIX_MV, float4(v.vertex.xy - offset, v.vertex.z, 1.0));

                offset *= max((_Scale1 + (1 - _Scale1) * (abs((depth - _TextureXY.z)))), 0);//焦距大小
                offset *= max(_Scale2 + (1 - _Scale2) * depth, 0);//远近大小
                offset *= _Scale3;//总体大小

                vertex += float4(offset, 0.0, 0.0);
                o.vertex = mul(UNITY_MATRIX_P, vertex);

                //广告牌(正交)
                // float3 center = float3(0, 0, 0);
                // float3 viewer = mul(unity_WorldToObject, float4(-UNITY_MATRIX_V[2].xyz , 0));
                // float3 normalDir = viewer - center;

                // normalDir = normalize(normalDir);

                // float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                // float3 rightDir = normalize(cross(upDir, normalDir));
                // upDir = normalize(cross(normalDir, rightDir));

                // float3 vertex = v.vertex * max((_Scale1 + (1 - _Scale1) * (abs((depth - _TextureXY.z)) / 10)), 0);
                // vertex *= max(_Scale2 + (1 - _Scale2) * depth, 0);

                // float3 centerOffs = vertex - center;
                // float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

                // vertexPos = GetVertexPositionInputs(v.vertex);
                // o.vertex = vertexPos.positionCS;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                //按物体与相机z轴距离取序列图
                half tile = saturate(i.uv.z / (max(_TextureXY.w, 0) + 0.001));// W为聚焦程度
                tile = floor(tile * (_TextureXY.x * _TextureXY.y - 1));

                half row = floor(tile / _TextureXY.x);
                half column = tile - row * _TextureXY.x;

                half2 uv = i.uv.xy + half2(column, -row - 1);
                uv.x /= _TextureXY.x;
                uv.y /= _TextureXY.y;

                half4 col = 1;
                col.a = tex2D(_MainTex, uv).r;

                col.a *= _Alpha1 + (1 - _Alpha1) / (i.uv.z + 0.001);//焦距透明
                col.a = saturate(col.a) * (_Alpha2 + (1 - _Alpha2) * i.uv.w);//大小透明
                col.a *= _Alpha3;//总体透明
                col.a *= i.alpha;//离相机较近时透明

                return col;
            }
            ENDHLSL

        }
    }
    CustomEditor"CustomShaderEditor"
}

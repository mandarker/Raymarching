Shader "Unlit/SpheresRaymarchShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SphereRadius("Sphere Radius", Range(0, 1)) = 0.1
        _MovementRadius("Movement Radius", Range(0, 1)) = 0.25
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define MAX_STEPS 100
            #define MAX_DIST 100
            #define SURF_DIST 0.00001
            #define PI 3.14159

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 rayOrigin : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
				float4 screenPos : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			sampler2D _CameraDepthTexture;

            float _SphereRadius;
            float _MovementRadius;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                o.hitPos = v.vertex;
				o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            // taken from inigo (and modified)
            float sdSphere(float3 o, float3 p, float s) {
                return distance(o, p) - s;
            }

            float3 RoseMovement3D(float speed, float offset) {
                float t = (_Time.y + offset) * speed;

                return float3(
                    sin(0.6 * t) * cos(t),
                    sin(0.6 * t) * sin(t),
                    sin(0.6 * t) * cos(sin(t))
                    );
            }

            // also taken from inigo
            float smin(float a, float b, float k)
            {
                float res = exp2(-k * a) + exp2(-k * b);
                return -log2(res) / k;
            }

            float GetDist(float3 p) {
                float sphere1 = sdSphere(RoseMovement3D(1, 0) * _MovementRadius, p, _SphereRadius);
                float sphere2 = sdSphere(RoseMovement3D(1, PI) * _MovementRadius, p, _SphereRadius);
                float sphere3 = sdSphere(RoseMovement3D(1, PI * 2) * _MovementRadius, p, _SphereRadius);
                float sphere4 = sdSphere(RoseMovement3D(1, PI * 3) * _MovementRadius, p, _SphereRadius);

                return smin(smin(smin(sphere1, sphere2, 32), sphere3, 32), sphere4, 32);
            }

            float Raymarch(float3 rayOrigin, float3 rayDirection) {
                float distFromOrigin = 0;
                float distFromSurface;
                for (int i = 0; i < MAX_STEPS; i++) {
                    float3 p = rayOrigin + distFromOrigin * rayDirection;
                    distFromSurface = GetDist(p);
                    distFromOrigin += distFromSurface;
                    if (distFromSurface < SURF_DIST || distFromOrigin > MAX_DIST) break;
                }

                return distFromOrigin;
            }

            float3 GetNormal(float3 p) {
                float2 e = float2(0.01, 0);
                float3 n = GetDist(p) - float3(GetDist(p - e.xyy), GetDist(p - e.yxy), GetDist(p - e.yyx));

                return normalize(n);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 rayOrigin = i.rayOrigin;
                float3 rayDirection = normalize(i.hitPos - rayOrigin);

                float d = Raymarch(rayOrigin, rayDirection);

				float2 screenUV = i.screenPos.xy / i.screenPos.w;
				float depth = tex2D(_CameraDepthTexture, screenUV).r;

                fixed4 col = 1;

				/*
                if (d < MAX_DIST && d < depth) {
                    float3 p = rayOrigin + rayDirection * d;
                    float3 normal = GetNormal(p);
                    col.rgb = normal;
					col.a = 1;
                    //col.a = d - length(i.hitPos - rayOrigin);
                }
                else
                    discard;
				*/

				col.rgb = depth;

                return col;
            }
            ENDCG
        }
    }
}

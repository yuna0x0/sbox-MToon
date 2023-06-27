//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
    Description = "Toon Shader with Global Illumination";
    Version = 3.9;
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
    Feature(F_USE_NORMAL_MAP, 0..1, "MToon Lighting");
    // Feature(F_OUTLINE_WIDTH_MODE, 0..2(0="None", 1="WorldCoordinates", 2="ScreenCoordinates"), "MToon Outline (WIP)");
    Feature(F_OUTLINE_WIDTH_MODE, 0..1(0="None", 1="WorldCoordinates"), "MToon Outline (WIP)");
    Feature(F_OUTLINE_COLOR_MODE, 0..1(0="FixedColor", 1="MixedLighting"), "MToon Outline (WIP)");
    FeatureRule(Requires1(F_OUTLINE_COLOR_MODE, F_OUTLINE_WIDTH_MODE == 1, F_OUTLINE_WIDTH_MODE == 2), "Requires outline enabled");
    #include "common/features.hlsl"
    Feature(F_RENDERING_TYPE, 0..3(0="Opaque", 1="Cutout", 2="Transparent", 3="TransparentWithZWrite"), "Rendering");
    Feature(F_DEBUGGING_OPTIONS, 0..2(0="None", 1="Normal", 2="LitShadeRate"), "MToon Debug");
}

// MODES
// {
//     Default();
//     VrForward();                                                        // Indicates this shader will be used for main rendering
//     Depth("depth_only.vfx");                                            // Shader that will be used for shadowing and depth prepass
//     ToolsVis(S_MODE_TOOLS_VIS);                                         // Ability to see in the editor
//     ToolsWireframe("vr_tools_wireframe.vfx");                           // Allows for mat_wireframe to work
//     ToolsShadingComplexity("vr_tools_shading_complexity.vfx");          // Shows how expensive drawing is in debug view
//     Reflection("high_quality_reflections.vfx");
// }

//=========================================================================================================================
COMMON
{
    #include "common/shared.hlsl"
}

//=========================================================================================================================

struct VertexInput
{
    #include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
    #include "common/pixelinput.hlsl"
    float isOutline : TEXCOORD9;
};

//=========================================================================================================================

VS
{
    #include "common/vertex.hlsl"
    //
    // Main
    //
    VertexInput MainVs(INSTANCED_SHADER_PARAMS(VertexInput i))
    {
        // PixelInput o = ProcessVertex(i);
        // Add your vertex manipulation functions here
        // o.isOutline = 0;
        // return FinalizeVertex(o);

        // i.vNormalOs = normalize(i.vNormalOs);
        return i;
    }
}

//=========================================================================================================================

GS
{
    StaticCombo(S_OUTLINE_WIDTH_MODE, F_OUTLINE_WIDTH_MODE, Sys(ALL));

    #include "common/vertex.hlsl"

    #if S_OUTLINE_WIDTH_MODE // Outline Enabled
        #ifdef F_TEXTURE_FILTERING
            SamplerState TextureFiltering < Filter((F_TEXTURE_FILTERING == 0 ? ANISOTROPIC : (F_TEXTURE_FILTERING == 1 ? BILINEAR : (F_TEXTURE_FILTERING == 2 ? TRILINEAR : (F_TEXTURE_FILTERING == 3 ? POINT : NEAREST))))); MaxAniso(8); > ;
        #else
            SamplerState TextureFiltering < Filter(ANISOTROPIC); MaxAniso(8); > ;
        #endif

        CreateInputTexture2D(InputOutlineWidthTexture, Srgb, 8, "", "", "MToon Outline,5/Width,1/1", Default4(1.0, 1.0, 1.0, 1.0));
        CreateTexture2DWithoutSampler(OutlineWidthTexture)< Channel(RGBA, Box(InputOutlineWidthTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
        float OutlineWidth < UiType(Slider); Range(0.01, 1.0); Default1(0.5); UiGroup("MToon Outline,5/Width,1/2"); >;
        #if S_OUTLINE_WIDTH_MODE == 2 // MTOON_OUTLINE_WIDTH_SCREEN
            float OutlineScaledMaxDistance < UiType(Slider); Range(1.0, 10.0); Default1(1.0); UiGroup("MToon Outline,5/Width,1/3"); >;
        #endif

        float3 CalculateOutlineVertexPosition(VertexInput v, float3 worldNormal)
        {
            float outlineTex = Tex2DLevelS(OutlineWidthTexture, TextureFiltering, v.vTexCoord.xy, 0).r;

            #if S_OUTLINE_WIDTH_MODE == 1 // MTOON_OUTLINE_WIDTH_WORLD
                // [TODO] Need fix. The outline result seems incorrect or weird (might be related to Object Space Normal or CullMode differences).
                float3 outlineOffset = 0.5 * OutlineWidth * outlineTex * length(worldNormal) * v.vNormalOs.xyz;
                float3 vertex = v.vPositionOs + outlineOffset;
            // #elif defined(MTOON_OUTLINE_WIDTH_SCREEN)
            //     float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
            //     float aspect = abs(nearUpperRight.y / nearUpperRight.x);
            //     float4 vertex = UnityObjectToClipPos(v.vertex);
            //     float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal.xyz);
            //     float3 clipNormal = TransformViewToProjection(viewNormal.xyz);
            //     float2 projectedNormal = normalize(clipNormal.xy);
            //     projectedNormal *= min(vertex.w, _OutlineScaledMaxDistance);
            //     projectedNormal.x *= aspect;
            //     vertex.xy += 0.01 * OutlineWidth * outlineTex * projectedNormal.xy * saturate(1 - abs(normalize(viewNormal).z)); // ignore offset when normal toward camera
            #else
                float3 vertex = v.vPositionOs;
            #endif
            return vertex;
        }
    #endif

    PixelInput InitializePixelInput(VertexInput i, float3 projectedVertex, float isOutline)
    {
        i.vPositionOs = projectedVertex;
        PixelInput o = ProcessVertex(i);
        o.isOutline = isOutline;
        return FinalizeVertex(o);
    }

    [maxvertexcount(6)]
    void MainGs(triangle VertexInput IN[3], inout TriangleStream<PixelInput> stream)
    {
        #if S_OUTLINE_WIDTH_MODE // Outline Enabled
            for (int i = 2; i >= 0; --i)
            {
                VertexInput v = IN[i];
                float3 worldNormal = ProcessVertex(v).vNormalWs.xyz;
                stream.Append(InitializePixelInput(v, CalculateOutlineVertexPosition(v, worldNormal), 1));
            }
            stream.RestartStrip();
        #endif

        for (int j = 0; j < 3; ++j)
        {
            VertexInput v = IN[j];
            stream.Append(InitializePixelInput(v, v.vPositionOs, 0));
        }
        stream.RestartStrip();
    }
}

//=========================================================================================================================

PS
{
    //
    // Combos
    //
    StaticCombo(S_RENDER_BACKFACES, F_RENDER_BACKFACES, Sys(ALL));

    StaticCombo(S_USE_NORMAL_MAP, F_USE_NORMAL_MAP, Sys(ALL));
    StaticCombo(S_RENDERING_TYPE, F_RENDERING_TYPE, Sys(ALL));
    StaticCombo(S_DEBUGGING_OPTIONS, F_DEBUGGING_OPTIONS, Sys(ALL));

    StaticCombo(S_OUTLINE_WIDTH_MODE, F_OUTLINE_WIDTH_MODE, Sys(ALL));
    StaticCombo(S_OUTLINE_COLOR_MODE, F_OUTLINE_COLOR_MODE, Sys(ALL));

    /*
        Currently, due to a lack of multi-pass support, when outline is enabled,

        If CullMode NONE -> Outline Pass CullMode will be NONE
        (with workaround below by using IsFrontFace to discard unwanted pixels)

        If CullMode BACK -> Outline Pass CullMode will be BACK
        which is not same as original shader.

        Original implementation is: (in Unity, not sure if applies here)
        CullMode BACK -> Outline Pass CullMode FRONT
        CullMode FRONT -> Outline Pass CullMode BACK
        CullMode NONE -> Outline Pass CullMode FRONT
    */
    // RenderState(CullMode, S_RENDER_BACKFACES ? NONE : DEFAULT);

    RenderState(DepthEnable, true);
    RenderState(DepthFunc, LESS_EQUAL);

    #if S_RENDERING_TYPE == 1 // Cutout
        #define ALPHA_TEST 1
        RenderState(AlphaTestEnable, true);
        RenderState(DepthWriteEnable, true);
    #elif S_RENDERING_TYPE == 2 // Transparent
        #define TRANSLUCENT 1
        BoolAttribute(translucent, true);
        RenderState(DepthWriteEnable, false);
    #elif S_RENDERING_TYPE == 3 // TransparentWithZWrite
        #define TRANSLUCENT 1
        BoolAttribute(translucent, true);
        RenderState(DepthWriteEnable, true);
    #else // Opaque
        RenderState(DepthWriteEnable, true);
    #endif

    //
    // Includes
    //
    #include "common/pixel.hlsl"

    //
    // Main
    //
    CreateInputTexture2D(InputLitTexture, Srgb, 8, "", "", "MToon Color,1/Texture,1/1", Default4(1.0, 1.0, 1.0, 1.0));
    CreateTexture2DWithoutSampler(LitTexture)< Channel(RGBA, Box(InputLitTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 LitColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("MToon Color,1/Texture,1/2"); >;
    CreateInputTexture2D(InputShadeTexture, Srgb, 8, "", "", "MToon Color,1/Texture,1/3", Default4(1.0, 1.0, 1.0, 1.0));
    CreateTexture2DWithoutSampler(ShadeTexture)< Channel(RGBA, Box(InputShadeTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 ShadeColor < UiType(Color); Default4(0.97, 0.81, 0.86, 1.0); UiGroup("MToon Color,1/Texture,1/4"); >;

    #if ALPHA_TEST
        float Cutoff < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("MToon Color,1/Alpha,2/1"); >;
    #endif

    float ShadingToony < UiType(Slider); Range(0.0, 1.0); Default1(0.9); UiGroup("MToon Lighting,2/1"); >;

    float ShadingShift < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("MToon Lighting,2/Advanced Settings,2/1"); >;
    CreateInputTexture2D(InputShadingGradeTexture, Srgb, 8, "", "", "MToon Lighting,2/Advanced Settings,2/2", Default4(1.0, 1.0, 1.0, 1.0));
    CreateTexture2DWithoutSampler(ShadingGradeTexture)< Channel(RGBA, Box(InputShadingGradeTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float ShadingGradeRate < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("MToon Lighting,2/Advanced Settings,2/3"); >;
    float LightColorAttenuation < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("MToon Lighting,2/Advanced Settings,2/4"); >;
    float IndirectLightIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("MToon Lighting,2/Advanced Settings,2/5"); >;

    CreateInputTexture2D(InputEmissionMap, Srgb, 8, "", "", "MToon Emission,3/1", Default4(1.0, 1.0, 1.0, 1.0));
    CreateTexture2DWithoutSampler(EmissionMap)< Channel(RGBA, Box(InputEmissionMap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 EmissionColor < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("MToon Emission,3/2"); >;
    CreateInputTexture2D(InputMatCap, Srgb, 8, "", "", "MToon Emission,3/3", Default4(0.0, 0.0, 0.0, 1.0));
    CreateTexture2DWithoutSampler(MatCap)< Channel(RGBA, Box(InputMatCap), Srgb); OutputFormat(BC7); SrgbRead(true); >;

    CreateInputTexture2D(InputRimTexture, Srgb, 8, "", "", "MToon Rim,4/1", Default4(1.0, 1.0, 1.0, 1.0));
    CreateTexture2DWithoutSampler(RimTexture)< Channel(RGBA, Box(InputRimTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 RimColor < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("MToon Rim,4/2"); >;
    float RimLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("MToon Rim,4/3"); >;
    float RimFresnelPower < UiType(Slider); Range(0.0, 100.0); Default1(1.0); UiGroup("MToon Rim,4/4"); >;
    float RimLift < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("MToon Rim,4/5"); >;

    #if S_OUTLINE_WIDTH_MODE // Outline Enabled
        float4 OutlineColor < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("MToon Outline,5/Color,2/1"); >;
        #if S_OUTLINE_COLOR_MODE == 1 // MTOON_OUTLINE_COLOR_MIXED
            float OutlineLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("MToon Outline,5/Color,2/2"); >;
        #endif
    #endif

    // const
    static const float PI_2 = 6.28318530718;
    static const float EPS_COL = 0.00001;

    static float2 mainUv;
    static float4 mainTex;
    static float alpha;
    static float isOutline;

    static float3 positionWithOffsetWs;
    static float3 positionWs;
    static float3 viewRayWs;
    static float3 normalWs;

    static float4 lit;
    static float4 shade;
    static float shadingGrade;

    static float lightIntensity;
    static float3 lighting;
    static float3 indirectLighting;

    #if S_RENDER_BACKFACES
        static bool isFrontFace;
    #endif

    class MToonShadingModel : ShadingModel
    {
        static void Init(PixelInput i, Material m)
        {
            // uv
            mainUv = i.vTextureCoords.xy;

            // main tex
            mainTex = Tex2DS(LitTexture, TextureFiltering, mainUv);

            // alpha
            alpha = 1;
            #if ALPHA_TEST
                alpha = LitColor.a * mainTex.a;
                alpha = (alpha - Cutoff) / max(fwidth(alpha), EPS_COL) + 0.5; // Alpha to Coverage
                clip(alpha - Cutoff);
                alpha = 1.0; // Discarded, otherwise it should be assumed to have full opacity
            #endif
            #if TRANSLUCENT
                alpha = LitColor.a * mainTex.a;
                #if !ALPHA_TEST // Only enable this on D3D11, where I tested it
                    clip(alpha - 0.0001); // Slightly improves rendering with layered transparency
                #endif
            #endif

            isOutline = i.isOutline;

            positionWithOffsetWs = i.vPositionWithOffsetWs;
            positionWs = positionWithOffsetWs + g_vCameraPositionWs;

            // View ray in World Space
            viewRayWs = CalculatePositionToCameraDirWs(positionWs);

            // normal
            #if S_USE_NORMAL_MAP
                normalWs = m.Normal;
            #else
                normalWs = float3(i.vNormalWs.x, i.vNormalWs.y, i.vNormalWs.z);
            #endif
            normalWs *= step(0, dot(viewRayWs, normalWs)) * 2 - 1; // flip if projection matrix is flipped
            normalWs *= lerp(+1.0, -1.0, isOutline);
            normalWs = normalize(normalWs);

            lit = LitColor * mainTex;
            shade = ShadeColor * Tex2DS(ShadeTexture, TextureFiltering, mainUv);
            shadingGrade = 1.0 - ShadingGradeRate * (1.0 - Tex2DS(ShadingGradeTexture, TextureFiltering, mainUv).r);

            #if S_RENDER_BACKFACES
                isFrontFace = IsFrontFace(i.face);
            #endif
        }

        static LightResult Direct(PixelInput i, Material m, Light l)
        {
            LightResult result = LightResult::Init();

            float dotNL = dot(l.Direction, normalWs);

            // Decide albedo color rate from Direct Light
            lightIntensity = dotNL; // [-1, +1]
            lightIntensity = lightIntensity * 0.5 + 0.5; // from [-1, +1] to [0, 1]
            lightIntensity = lightIntensity * l.Visibility * l.Attenuation; // receive shadow
            lightIntensity = lightIntensity * shadingGrade; // darker
            lightIntensity = lightIntensity * 2.0 - 1.0; // from [0, 1] to [-1, +1]
            // tooned. mapping from [minIntensityThreshold, maxIntensityThreshold] to [0, 1]
            float maxIntensityThreshold = lerp(1, ShadingShift, ShadingToony);
            float minIntensityThreshold = ShadingShift;
            lightIntensity = saturate((lightIntensity - minIntensityThreshold) / max(EPS_COL, (maxIntensityThreshold - minIntensityThreshold)));

            // Albedo color
            result.Diffuse = lerp(shade.rgb, lit.rgb, lightIntensity);

            float3 lightColor = saturate(l.Visibility * l.Attenuation * l.Color);
            // Direct Light
            lighting = lightColor;
            lighting = lerp(lighting, max(EPS_COL, max(lighting.x, max(lighting.y, lighting.z))), LightColorAttenuation); // color atten
            // base light does not darken.
            result.Diffuse *= lighting;

            // No specular
            result.Specular = 0.0f;

            return result;
        }

        static LightResult Indirect(PixelInput i, Material m)
        {
            LightResult result = LightResult::Init();

            Light light = AmbientLight::From(i, m);
            float3 vAmbientCube[6];
            SampleLightProbeVolume(vAmbientCube, light.Position);

            float3 toonedGI = 0.5 * (SampleIrradiance(vAmbientCube, float3(0, 1, 0)) + SampleIrradiance(vAmbientCube, float3(0, -1, 0)));
            indirectLighting = lerp(toonedGI, SampleIrradiance(vAmbientCube, normalWs), IndirectLightIntensity);
            indirectLighting = lerp(indirectLighting, max(EPS_COL, max(indirectLighting.x, max(indirectLighting.y, indirectLighting.z))), LightColorAttenuation); // color atten
            result.Diffuse = indirectLighting * lit.rgb;

            result.Diffuse = min(result.Diffuse, lit.rgb); // comment out if you want to PBR absolutely.

            // No specular
            result.Specular = 0.0f;

            return result;
        }

        static float4 PostProcess(float4 color)
        {
            // parametric rim lighting
            float3 staticRimLighting = 1;
            float3 mixedRimLighting = lighting + indirectLighting;
            float3 rimLighting = lerp(staticRimLighting, mixedRimLighting, RimLightingMix);
            float3 rim = pow(saturate(1.0 - dot(normalWs, viewRayWs) + RimLift), max(RimFresnelPower, EPS_COL)) * RimColor.rgb * Tex2DS(RimTexture, TextureFiltering, mainUv).rgb;
            color.rgb += lerp(rim * rimLighting, float3(0, 0, 0), isOutline);

            // additive matcap
            float3 worldCameraUp = normalize(g_vCameraUpDirWs);
            float3 worldViewUp = normalize(worldCameraUp - viewRayWs * dot(viewRayWs, worldCameraUp));
            float3 worldViewRight = normalize(cross(viewRayWs, worldViewUp));
            float2 matcapUv = float2(dot(worldViewRight, normalWs), dot(worldViewUp, normalWs)) * 0.5 + 0.5;
            float3 matcapLighting = Tex2DS(MatCap, TextureFiltering, matcapUv).rgb;
            color.rgb += lerp(matcapLighting, float3(0, 0, 0), isOutline);

            // Emission
            float3 emission = Tex2DS(EmissionMap, TextureFiltering, mainUv).rgb * EmissionColor.rgb;
            color.rgb += lerp(emission, float3(0, 0, 0), isOutline);

            // outline
            #if S_OUTLINE_WIDTH_MODE // Outline Enabled
                #if S_OUTLINE_COLOR_MODE == 0 // MTOON_OUTLINE_COLOR_FIXED
                    color.rgb = lerp(color.rgb, OutlineColor.rgb, isOutline);
                #elif S_OUTLINE_COLOR_MODE == 1 // MTOON_OUTLINE_COLOR_MIXED
                    color.rgb = lerp(color.rgb, OutlineColor.rgb * lerp(float3(1, 1, 1), color.rgb, OutlineLightingMix), isOutline);
                #else
                #endif

                // [Workaround] discard unwanted outline pixels
                #if S_RENDER_BACKFACES
                    if (isOutline && !isFrontFace)
                        discard;
                #endif
            #endif

            // debug
            #if S_DEBUGGING_OPTIONS == 1
                return float4(normalWs * 0.5 + 0.5, alpha);
            #elif S_DEBUGGING_OPTIONS == 2
                return float4(lightIntensity * lighting, alpha);
            #endif

            return float4(color.rgb, alpha);
        }

        static float4 Shade(PixelInput i, Material m)
        {
            Init(i, m);

            LightResult vLightResult = LightResult::Init();

            //
            // Shade direct lighting for dynamic and static lights
            //
            uint index;
            for (index = 0; index < DynamicLight::Count(i); index++)
            {
                Light light = DynamicLight::From(i, index);
                vLightResult = LightResult::Sum(vLightResult, Direct(i, m, light));
            }

            [unroll]
            for (index = 0; index < StaticLight::Count(i); index++)
            {
                Light light = StaticLight::From(i, index);
                if(light.Visibility > 0.0f)
                    vLightResult = LightResult::Sum(vLightResult, Direct(i, m, light));
            }

            //
            // Shade indirect lighting
            //
            vLightResult = LightResult::Sum(vLightResult, Indirect(i, m));

            float4 colorResult = PostProcess(float4(vLightResult.Diffuse + vLightResult.Specular, m.Opacity));

            return ShadingModel::Finalize(i, m, colorResult);
        }
    };

    float4 MainPs(PixelInput i) : SV_Target0
    {
        Material m = Material::From(i);
        return MToonShadingModel::Shade(i, m);
    }
}

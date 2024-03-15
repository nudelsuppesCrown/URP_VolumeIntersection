Shader "VolumeIntersection/BackfaceStencil"
{
    Properties
    {   
        [Header(Stencil)]
        _StencilRef ("StencilRef ID [0;255]", Float) = 5
        [Enum(UnityEngine.Rendering.CompareFunction)] _Compare ("Stencil Comparison", Int) = 5
        [Enum(UnityEngine.Rendering.StencilOp)] _Pass ("Stencil Operation", Int) = 2
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
        
        //pass1 writing backfaces into stencil buffer
        Pass
        {
            Stencil
			{
				Ref[_StencilRef]
				//Comp Always
                //Comp Greater
                Comp[_Compare]
				Pass [_Pass]
				ZFail Zero
			}

            Blend Zero One
            Cull Front
            ZTest GEqual
            ZWrite Off
        }
    }
}
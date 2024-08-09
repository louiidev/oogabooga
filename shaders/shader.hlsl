
// PS_INPUT is defined in the default shader in gfx_impl_d3d11.c at the bottom of the file

// BEWARE std140 packing:
// https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-packing-rules
cbuffer some_cbuffer : register(b0) {
    float2 mouse_pos_screen; // In pixels
    float2 window_size;
}

#define ENEMY_FLASH 1


// This procedure is the "entry" of our extension to the shader
// It basically just takes in the resulting color and input from vertex shader, for us to transform it
// however we want.
float4 pixel_shader_extension(PS_INPUT input, float4 color) {
    
    float detail_type = input.userdata[0].x;
    
	if (detail_type == ENEMY_FLASH) {
		float flash_amount = input.userdata[0].y; // 0f-1f
		
		// if there's an issue with the single alpha check, we should check the whole colour
		// float4 skipColor = float4(0, 0, 0, );
		// !all(color == skipColor)
		if (color.a > 0 && color.a != 90.0 / 255.0) {
			float4 whiteColor = float4(1, 1, 1, 1);
    		float4 blendedColor = lerp(color, whiteColor, flash_amount);
			return blendedColor;
		}
	
        
    }
    
	
    return color;
}
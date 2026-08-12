 ```
   1. AcquireGPUCommandBuffer
      └─ Get a blank "notepad" to write GPU instructions into

   2. WaitAndAcquireGPUSwapchainTexture
      └─ Wait for a back buffer (texture) we're allowed to draw into

   3. BeginGPURenderPass
      └─ Tell the GPU: "we're about to draw into this texture, clear it first"

   4. BindGPUGraphicsPipeline
      └─ "Use these shaders, this depth config, this blend config..."

   5. DrawGPUPrimitives(3 vertices)
      └─ Record "run the pipeline on 3 vertices" into the notepad

   6. EndGPURenderPass
      └─ "Done drawing, write the tile buffer back to the texture in VRAM"

   7. SubmitGPUCommandBuffer
      └─ Send the whole notepad over PCIe to the GPU
         GPU executes it all, then flips the swapchain → frame appears on screen

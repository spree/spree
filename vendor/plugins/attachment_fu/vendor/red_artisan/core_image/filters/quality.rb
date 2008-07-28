module RedArtisan
  module CoreImage
    module Filters
      module Quality
        
        def reduce_noise(level = 0.02, sharpness = 0.4)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.noise_reduction :inputNoiseLevel => level, :inputSharpness => sharpness do |noise_reduced|
            @target = noise_reduced
          end
        end
        
        def adjust_exposure(input_ev = 0.5)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.exposure_adjust :inputEV => input_ev do |adjusted|
            @target = adjusted
          end          
        end
        
      end
    end
  end
end
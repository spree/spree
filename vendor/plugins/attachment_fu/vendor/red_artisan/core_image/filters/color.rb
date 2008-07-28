module RedArtisan
  module CoreImage
    module Filters
      module Color
        
        def greyscale(color = nil, intensity = 1.00)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          color = OSX::CIColor.colorWithString("1.0 1.0 1.0 1.0") unless color
          
          @original.color_monochrome :inputColor => color, :inputIntensity => intensity do |greyscale|
            @target = greyscale
          end
        end
        
        def sepia(intensity = 1.00)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.sepia_tone :inputIntensity => intensity do |sepia|
            @target = sepia
          end
        end
        
      end
    end
  end
end
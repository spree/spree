module RedArtisan
  module CoreImage
    module Filters
      module Effects
        
        def spotlight(position, points_at, brightness, concentration, color)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.spot_light :inputLightPosition => vector3(*position), :inputLightPointsAt => vector3(*points_at), 
                               :inputBrightness => brightness, :inputConcentration => concentration, :inputColor => color do |spot|
            @target = spot
          end
        end
        
        def edges(intensity = 1.00)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.edges :inputIntensity => intensity do |edged|
            @target = edged
          end
        end
        
        private
        
          def vector3(x, y, w)
            OSX::CIVector.vectorWithX_Y_Z(x, y, w)
          end
      end
    end
  end
end

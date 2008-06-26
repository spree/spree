module RedArtisan
  module CoreImage
    module Filters
      module Perspective
        
        def perspective(top_left, top_right, bottom_left, bottom_right)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.perspective_transform :inputTopLeft => top_left, :inputTopRight => top_right, :inputBottomLeft => bottom_left, :inputBottomRight => bottom_right do |transformed|
            @target = transformed
          end
        end

        def perspective_tiled(top_left, top_right, bottom_left, bottom_right)
          create_core_image_context(@original.extent.size.width, @original.extent.size.height)
          
          @original.perspective_tile :inputTopLeft => top_left, :inputTopRight => top_right, :inputBottomLeft => bottom_left, :inputBottomRight => bottom_right do |tiled|
            @target = tiled
          end
        end
        
      end
    end
  end
end
module RedArtisan
  module CoreImage
    module Filters
      module Scale
        
        def resize(width, height)
          create_core_image_context(width, height)

          scale_x, scale_y = scale(width, height)

          @original.affine_clamp :inputTransform => OSX::NSAffineTransform.transform do |clamped|
            clamped.lanczos_scale_transform :inputScale => scale_x > scale_y ? scale_x : scale_y, :inputAspectRatio => scale_x / scale_y do |scaled|
              scaled.crop :inputRectangle => vector(0, 0, width, height) do |cropped|
                @target = cropped
              end
            end
          end
        end

        def thumbnail(width, height)
          create_core_image_context(width, height)

          transform = OSX::NSAffineTransform.transform
          transform.scaleXBy_yBy *scale(width, height)

          @original.affine_transform :inputTransform => transform do |scaled|
            @target = scaled
          end
        end

        def fit(size)
          original_size = @original.extent.size
          scale = size.to_f / (original_size.width > original_size.height ? original_size.width : original_size.height)
          resize (original_size.width * scale).to_i, (original_size.height * scale).to_i
        end
        
        private
        
          def scale(width, height)
            original_size = @original.extent.size
            return width.to_f / original_size.width.to_f, height.to_f / original_size.height.to_f
          end
          
      end
    end
  end
end
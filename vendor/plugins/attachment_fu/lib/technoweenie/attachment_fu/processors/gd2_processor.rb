require 'rubygems'
require 'gd2'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Processors
      module Gd2Processor
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end
        
        module ClassMethods
          # Yields a block containing a GD2 Image for the given binary data.
          def with_image(file, &block)
            im = GD2::Image.import(file)
            block.call(im)
          end
        end

        protected
          def process_attachment_with_processing
            return unless process_attachment_without_processing && image?
            with_image do |img|
              resize_image_or_thumbnail! img
              self.width  = img.width
              self.height = img.height
              callback_with_args :after_resize, img
            end
          end

          # Performs the actual resizing operation for a thumbnail
          def resize_image(img, size)
            size = size.first if size.is_a?(Array) && size.length == 1
            if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
              if size.is_a?(Fixnum)
                # Borrowed from image science's #thumbnail method and adapted 
                # for this.
                scale = size.to_f / (img.width > img.height ? img.width.to_f : img.height.to_f)
                img.resize!((img.width * scale).round(1), (img.height * scale).round(1), false)
              else
                img.resize!(size.first, size.last, false) 
              end
            else
              w, h = [img.width, img.height] / size.to_s
              img.resize!(w, h, false)
            end
            self.temp_path = random_tempfile_filename
            self.size = img.export(self.temp_path)
          end

      end
    end
  end
end
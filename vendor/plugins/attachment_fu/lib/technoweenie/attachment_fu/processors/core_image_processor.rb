require 'red_artisan/core_image/processor'

module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Processors
      module CoreImageProcessor
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end
        
        module ClassMethods
          def with_image(file, &block)
            block.call OSX::CIImage.from(file)
          end
        end
                
        protected
          def process_attachment_with_processing
            return unless process_attachment_without_processing
            with_image do |img|
              self.width  = img.extent.size.width  if respond_to?(:width)
              self.height = img.extent.size.height if respond_to?(:height)
              resize_image_or_thumbnail! img
              callback_with_args :after_resize, img
            end if image?
          end

          # Performs the actual resizing operation for a thumbnail
          def resize_image(img, size)
            processor = ::RedArtisan::CoreImage::Processor.new(img)
            size = size.first if size.is_a?(Array) && size.length == 1
            if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
              if size.is_a?(Fixnum)
                processor.fit(size)
              else
                processor.resize(size[0], size[1])
              end
            else
              new_size = [img.extent.size.width, img.extent.size.height] / size.to_s
              processor.resize(new_size[0], new_size[1])
            end
            
            processor.render do |result|
              self.width  = result.extent.size.width  if respond_to?(:width)
              self.height = result.extent.size.height if respond_to?(:height)
              
              # Get a new temp_path for the image before saving
              self.temp_path = Tempfile.new(random_tempfile_filename, Technoweenie::AttachmentFu.tempfile_path).path
              result.save self.temp_path, OSX::NSJPEGFileType
              self.size = File.size(self.temp_path)
            end
          end          
      end
    end
  end
end



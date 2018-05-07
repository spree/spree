module Spree
  class Image < Asset
    module Configuration
      module Paperclip
        extend ActiveSupport::Concern

        included do
          validate :no_attachment_errors

          def self.accepted_image_types
            %w(image/jpeg image/jpg image/png image/gif)
          end

          def self.styles
            attachment_definitions[:attachment][:styles]
          end

          has_attached_file :attachment,
            styles: { mini: '48x48>', small: '100x100>', product: '240x240>', large: '600x600>' },
            default_style: :product,
            url: '/spree/products/:id/:style/:basename.:extension',
            path: ':rails_root/public/spree/products/:id/:style/:basename.:extension',
            convert_options: { all: '-strip -auto-orient -colorspace sRGB' }

          validates_attachment :attachment,
            presence: true,
            content_type: { content_type: accepted_image_types }

          # save the w,h of the original image (from which others can be calculated)
          # we need to look at the write-queue for images which have not been saved yet
          before_save :find_dimensions, if: :attachment_updated_at_changed?

          delegate :url, to: :attachment

          # used by admin products autocomplete
          def mini_url
            url(:mini, false)
          end

          def find_dimensions
            temporary = attachment.queued_for_write[:original]
            filename = temporary.path unless temporary.nil?
            filename = attachment.path if filename.blank?
            geometry = ::Paperclip::Geometry.from_file(filename)
            self.attachment_width  = geometry.width
            self.attachment_height = geometry.height
          end

          # if there are errors from the plugin, then add a more meaningful message
          def no_attachment_errors
            unless attachment.errors.empty?
              # uncomment this to get rid of the less-than-useful interim messages
              # errors.clear
              errors.add :attachment,
                "Paperclip returned errors for file '#{attachment_file_name}' - check ImageMagick installation or image source file."

              false
            end
          end
        end
      end
    end
  end
end

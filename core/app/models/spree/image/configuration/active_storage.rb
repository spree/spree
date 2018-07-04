module Spree
  class Image < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          validate :check_attachment_presence
          validate :check_attachment_content_type

          has_one_attached :attachment

          def self.styles
            @styles ||= {
              mini:    '48x48>',
              small:   '100x100>',
              product: '240x240>',
              large:   '600x600>'
            }
          end

          def default_style
            :product
          end

          def accepted_image_types
            %w(image/jpeg image/jpg image/png image/gif)
          end

          def check_attachment_presence
            unless attachment.attached?
              attachment.purge
              errors.add(:attachment, :attachment_must_be_present)
            end
          end

          def check_attachment_content_type
            if attachment.attached? && !attachment.content_type.in?(accepted_image_types)
              attachment.purge
              errors.add(:attachment, :not_allowed_content_type)
            end
          end
        end
      end
    end
  end
end

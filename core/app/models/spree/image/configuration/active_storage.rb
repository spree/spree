module Spree
  class Image < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          if Spree.public_storage_service_name
            has_one_attached :attachment, service: Spree.public_storage_service_name
          else
            has_one_attached :attachment
          end

          validates :attachment, attached: true, content_type: /\Aimage\/.*\z/

          default_scope { includes(attachment_attachment: :blob) }

          def self.styles
            @styles ||= {
              mini: '48x48>',
              small: '100x100>',
              product: '240x240>',
              pdp_thumbnail: '160x200>',
              plp_and_carousel: '448x600>',
              plp_and_carousel_xs: '254x340>',
              plp_and_carousel_sm: '350x468>',
              plp_and_carousel_md: '222x297>',
              plp_and_carousel_lg: '278x371>',
              large: '600x600>',
              plp: '278x371>',
              zoomed: '650x870>'
            }
          end

          def default_style
            :product
          end
        end
      end
    end
  end
end

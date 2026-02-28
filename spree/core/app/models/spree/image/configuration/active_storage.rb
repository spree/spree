module Spree
  class Image < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          # Returns image styles derived from Spree::Config.product_image_variant_sizes
          # Format: { variant_name: 'WxH>' } for API compatibility
          def self.styles
            @styles ||= Spree::Config.product_image_variant_sizes.transform_values do |dimensions|
              "#{dimensions[0]}x#{dimensions[1]}>"
            end
          end

          def default_style
            :small
          end
        end
      end
    end
  end
end

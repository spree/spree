module Spree
  module Api
    module V3
      class ImageSerializer < BaseSerializer
        attributes :id, :position, :alt, :viewable_type, :viewable_id

        attribute :original_url do |image|
          image_url(image)
        end

        # Dynamically define attributes for each configured image variant
        # Uses named variants from Spree::Config.product_image_variant_sizes
        # (e.g., mini, small, medium, large, xlarge)
        Spree::Config.product_image_variant_sizes.each_key do |variant_name|
          attribute :"#{variant_name}_url" do |image|
            variant_url(image, variant_name)
          end
        end

        private

        def image_url(image)
          return nil unless image&.attachment&.attached?

          Rails.application.routes.url_helpers.cdn_image_url(image.attachment)
        end

        def variant_url(image, variant_name)
          return nil unless image&.attachment&.attached?

          Rails.application.routes.url_helpers.cdn_image_url(
            image.attachment.variant(variant_name)
          )
        end
      end
    end
  end
end

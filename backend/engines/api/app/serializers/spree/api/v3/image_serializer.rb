module Spree
  module Api
    module V3
      class ImageSerializer < BaseSerializer
        typelize position: :number, alt: 'string | null', viewable_type: :string, viewable_id: :string,
                 original_url: 'string | null', mini_url: 'string | null',
                 small_url: 'string | null', medium_url: 'string | null',
                 large_url: 'string | null', xlarge_url: 'string | null',
                 og_image_url: 'string | null'

        attribute :viewable_id do |image|
          image.viewable&.prefix_id
        end

        attributes :position, :alt, :viewable_type,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :original_url do |image|
          image_url_for(image)
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

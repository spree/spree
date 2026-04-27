module Spree
  module Api
    module V3
      class MediaSerializer < BaseSerializer
        typelize position: :number, alt: [:string, nullable: true],
                 product_id: [:string, nullable: true],
                 variant_ids: [:string, multi: true],
                 media_type: :string,
                 focal_point_x: [:number, nullable: true],
                 focal_point_y: [:number, nullable: true],
                 external_video_url: [:string, nullable: true],
                 original_url: [:string, nullable: true], mini_url: [:string, nullable: true],
                 small_url: [:string, nullable: true], medium_url: [:string, nullable: true],
                 large_url: [:string, nullable: true], xlarge_url: [:string, nullable: true],
                 og_image_url: [:string, nullable: true]

        attribute :product_id do |asset|
          asset.product&.prefixed_id
        end

        # Returns prefixed IDs of variants this media is associated with.
        # Currently: single variant via viewable (legacy). In 6.0: multiple via VariantMedia join table.
        attribute :variant_ids do |asset|
          if asset.viewable_type == 'Spree::Variant'
            [asset.viewable&.prefixed_id].compact
          else
            []
          end
        end

        attributes :position, :alt, :media_type,
                   :focal_point_x, :focal_point_y, :external_video_url

        attribute :original_url do |asset|
          image_url_for(asset)
        end

        # Dynamically define attributes for each configured image variant
        # Uses named variants from Spree::Config.product_image_variant_sizes
        # (e.g., mini, small, medium, large, xlarge)
        Spree::Config.product_image_variant_sizes.each_key do |variant_name|
          attribute :"#{variant_name}_url" do |asset|
            variant_url(asset, variant_name)
          end
        end

        private

        def variant_url(asset, variant_name)
          return nil unless asset&.attachment&.attached?

          Rails.application.routes.url_helpers.cdn_image_url(
            asset.attachment.variant(variant_name)
          )
        rescue NoMethodError => e
          raise unless e.name == :cdn_image_url
          nil
        end
      end
    end
  end
end

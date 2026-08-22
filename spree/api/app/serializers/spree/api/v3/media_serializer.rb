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
                 external_media_url: [:string, nullable: true],
                 video_provider: [:string, nullable: true],
                 video_embed_url: [:string, nullable: true],
                 video_url: [:string, nullable: true],
                 poster_url: [:string, nullable: true],
                 original_url: [:string, nullable: true], mini_url: [:string, nullable: true],
                 small_url: [:string, nullable: true], medium_url: [:string, nullable: true],
                 large_url: [:string, nullable: true], xlarge_url: [:string, nullable: true],
                 og_image_url: [:string, nullable: true]

        attribute :product_id do |asset|
          asset.product&.prefixed_id
        end

        # Returns prefixed IDs of variants this media is associated with.
        # Two paths coexist in 5.5:
        #   - legacy: asset.viewable IS the variant (direct upload, viewable_type 'Spree::Variant')
        #   - new:    asset.variants — product-level asset linked via VariantMedia rows
        # Both are reported so the admin can show a unified "assigned variants" list.
        attribute :variant_ids do |asset|
          ids = []
          ids << asset.viewable&.prefixed_id if asset.viewable_type == 'Spree::Variant' && asset.viewable
          ids.concat(asset.variants.map(&:prefixed_id)) if asset.viewable_type == 'Spree::Product'
          ids.compact.uniq
        end

        attributes :position, :alt, :media_type,
                   :focal_point_x, :focal_point_y, :external_video_url, :external_media_url

        # Spree parses the YouTube/Vimeo link once, here, so no storefront has
        # to reimplement it. Nil on anything that isn't an external video.
        attribute :video_provider do |asset|
          asset.external_video&.provider
        end

        attribute :video_embed_url do |asset|
          asset.external_video&.embed_url
        end

        # The uploaded video file itself. Served as-is — Spree does not
        # transcode.
        attribute :video_url do |asset|
          next nil unless asset.video? && asset.attachment.attached?

          url_helpers.cdn_image_url(asset.attachment)
        end

        # Still frame for a video tile: the merchant's upload when there is one,
        # otherwise the provider's own thumbnail.
        attribute :poster_url do |asset|
          next nil unless asset.playable_video?

          still_url(asset)
        end

        # Nil for video rows — there is no image to size.
        attribute :original_url do |asset|
          next nil if asset.playable_video?

          image_url_for(asset)
        end

        # Dynamically define attributes for each configured image variant
        # Uses named variants from Spree::Config.product_image_variant_sizes
        # (e.g., mini, small, medium, large, xlarge)
        Spree::Config.product_image_variant_sizes.each_key do |variant_name|
          attribute :"#{variant_name}_url" do |asset|
            still_url(asset, variant_name)
          end
        end

        private

        # The row's still frame, sized when it's an attachment we control — an
        # image's own file, or a video's poster, so a gallery that only knows
        # how to draw an image still renders the right picture. A hosted still
        # (an external image, a provider's thumbnail) is served as-is: it isn't
        # ours to resize, so every size resolves to the same URL.
        def still_url(asset, variant_name = nil)
          source = asset&.still_image
          return asset&.hosted_still_url if source.nil?

          url_helpers.cdn_image_url(variant_name ? source.variant(variant_name) : source)
        end

        def url_helpers
          Rails.application.routes.url_helpers
        end
      end
    end
  end
end

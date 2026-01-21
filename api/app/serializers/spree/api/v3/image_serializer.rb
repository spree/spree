module Spree
  module Api
    module V3
      class ImageSerializer < BaseSerializer
        attributes :id, :position, :alt, :viewable_type, :viewable_id

        attribute :original_url do |image|
          image_url(image)
        end

        attribute :large_url do |image|
          image_url(image, size: [1200, 1200])
        end

        attribute :medium_url do |image|
          image_url(image, size: [600, 600])
        end

        attribute :small_url do |image|
          image_url(image, size: [300, 300])
        end

        attribute :thumbnail_url do |image|
          image_url(image, size: [150, 150])
        end

        private

        def image_url(image, size: nil)
          unless image&.attachment&.attached?
            return nil
          end

          if size
            Rails.application.routes.url_helpers.cdn_image_url(
              image.attachment.variant(resize_to_limit: size)
            )
          else
            Rails.application.routes.url_helpers.cdn_image_url(image.attachment)
          end
        end
      end
    end
  end
end

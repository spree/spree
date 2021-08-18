module Spree
  module V2
    module Storefront
      class ImageSerializer < BaseSerializer
        include Rails.application.routes.url_helpers

        set_type :image

        attributes :styles, :original_url

        attribute :transformed_url do |image, params|
          image.generate_url(size: params.dig(:image_transformation, :size))
        end
      end
    end
  end
end

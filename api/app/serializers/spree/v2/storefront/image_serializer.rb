module Spree
  module V2
    module Storefront
      class ImageSerializer < BaseSerializer
        set_type :image

        attributes :viewable_type, :viewable_id, :styles

        attribute :transformed_url do |image, params|
          image.generate_url(size: params.dig(:image_transformation, :size))
        end
      end
    end
  end
end

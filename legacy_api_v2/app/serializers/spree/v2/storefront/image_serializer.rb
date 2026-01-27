module Spree
  module V2
    module Storefront
      class ImageSerializer < BaseSerializer
        include ::Spree::Api::V2::ImageTransformationConcern

        set_type :image

        attributes :styles, :position, :alt, :original_url
      end
    end
  end
end

module Spree
  module V2
    module Storefront
      class ImageSerializer < BaseSerializer
        set_type :image

        attributes :viewable_type, :viewable_id, :styles
      end
    end
  end
end

module Spree
  module V2
    module Storefront
      class ShippingCategorySerializer < BaseSerializer
        set_type  :shipping_category
        attribute :name
      end
    end
  end
end

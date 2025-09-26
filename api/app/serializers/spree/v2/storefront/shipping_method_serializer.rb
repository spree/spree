module Spree
  module V2
    module Storefront
      class ShippingMethodSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type   :shipping_method
        attributes :name, :public_metadata
      end
    end
  end
end

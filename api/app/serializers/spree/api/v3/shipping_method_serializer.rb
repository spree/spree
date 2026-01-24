module Spree
  module Api
    module V3
      class ShippingMethodSerializer < BaseSerializer
        typelize_from Spree::ShippingMethod

        attributes :id, :name, :code
      end
    end
  end
end

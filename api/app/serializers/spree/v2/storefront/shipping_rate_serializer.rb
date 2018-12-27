module Spree
  module V2
    module Storefront
      class ShippingRateSerializer < BaseSerializer
        set_type :shipping_rate

        attributes :name, :cost, :selected, :display_cost, :tax_amount,
                   :display_tax_amount, :shipping_method_id
      end
    end
  end
end

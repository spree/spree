module Spree
  module V2
    module Storefront
      class ShippingRateSerializer < BaseSerializer
        set_type :shipping_rate

        attributes :name, :selected, :final_price, :display_final_price, :cost,
                   :display_cost, :tax_amount, :display_tax_amount, :shipping_method_id

        attribute :free, &:free?
      end
    end
  end
end

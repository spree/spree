module Spree
  module V2
    module Storefront
      class ShippingRateSerializer < BaseSerializer
        set_type :shipping_rate

        attributes :name, :selected, :final_price, :display_final_price, :cost,
                   :display_cost, :tax_amount, :display_tax_amount

        attribute :shipping_method_id do |shipping_rate|
          shipping_rate.shipping_method_id.to_s
        end

        belongs_to :shipping_method, serializer: Spree::Api::Dependencies.storefront_shipping_method_serializer.constantize

        attribute :free do |shipping_rate|
          shipping_rate.free?
        end

        attribute :final_price_cents do |shipping_rate|
          shipping_rate.display_final_price.cents
        end
      end
    end
  end
end

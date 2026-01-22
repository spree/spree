module Spree
  module Api
    module V3
      module Store
        class ShippingRateSerializer < BaseSerializer
          attributes :id, :name, :selected, :shipping_method_id

          attribute :cost do |shipping_rate|
            shipping_rate.cost.to_f
          end

          attribute :display_cost do |shipping_rate|
            shipping_rate.display_cost.to_s
          end

          one :shipping_method, resource: Spree.api.v3_store_shipping_method_serializer
        end
      end
    end
  end
end

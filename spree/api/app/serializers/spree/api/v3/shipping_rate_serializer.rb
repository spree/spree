module Spree
  module Api
    module V3
      class ShippingRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, shipping_method_id: :string,
                 cost: :string, display_cost: :string

        attribute :shipping_method_id do |shipping_rate|
          shipping_rate.shipping_method&.prefixed_id
        end

        attributes :name, :selected, :cost

        attribute :display_cost do |shipping_rate|
          shipping_rate.display_cost.to_s
        end

        one :shipping_method, resource: Spree.api.shipping_method_serializer
      end
    end
  end
end

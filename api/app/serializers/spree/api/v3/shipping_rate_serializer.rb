module Spree
  module Api
    module V3
      class ShippingRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, shipping_method_id: :string,
                 cost: :number, display_cost: :string

        attribute :shipping_method_id do |shipping_rate|
          shipping_rate.shipping_method&.prefix_id
        end

        attributes :name, :selected

        attribute :cost do |shipping_rate|
          shipping_rate.cost.to_f
        end

        attribute :display_cost do |shipping_rate|
          shipping_rate.display_cost.to_s
        end

        one :shipping_method, resource: Spree.api.shipping_method_serializer
      end
    end
  end
end

module Spree
  module Api
    module V3
      class DeliveryRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, delivery_method_id: :string,
                 cost: :string, display_cost: :string,
                 final_price: :string, display_final_price: :string, free: :boolean

        attribute :delivery_method_id do |shipping_rate|
          shipping_rate.shipping_method&.prefixed_id
        end

        attributes :name, :selected, :cost, :final_price

        attribute :display_cost do |shipping_rate|
          shipping_rate.display_cost.to_s
        end

        attribute :display_final_price do |shipping_rate|
          shipping_rate.display_final_price.to_s
        end

        attribute :free do |shipping_rate|
          shipping_rate.free?
        end

        one :shipping_method, key: :delivery_method, resource: Spree.api.delivery_method_serializer
      end
    end
  end
end

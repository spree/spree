module Spree
  module Api
    module V3
      class ShipmentSerializer < BaseSerializer
        typelize number: :string, state: :string, tracking: [:string, nullable: true],
                 tracking_url: [:string, nullable: true], shipped_at: [:string, nullable: true],
                 cost: :string, display_cost: :string

        attributes :number, :state, :tracking, :tracking_url,
                   :cost, :display_cost,
                   shipped_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        one :shipping_method, resource: Spree.api.shipping_method_serializer
        one :stock_location, resource: Spree.api.stock_location_serializer
        many :shipping_rates, resource: Spree.api.shipping_rate_serializer
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class ShipmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :tracking_url

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :address, serializer: Spree.api.platform_address_serializer
          belongs_to :stock_location, serializer: Spree.api.platform_stock_location_serializer
          has_many :adjustments, serializer: Spree.api.platform_adjustment_serializer
          has_many :inventory_units, serializer: Spree.api.platform_inventory_unit_serializer
          has_many :shipping_rates, serializer: Spree.api.platform_shipping_rate_serializer
          has_many :state_changes, serializer: Spree.api.platform_state_change_serializer
          has_one :selected_shipping_rate, serializer: Spree.api.platform_shipping_rate_serializer, type: :shipping_rate
        end
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class ShipmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :tracking_url

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :address, serializer: Spree::Api::Dependencies.platform_address_serializer.constantize
          belongs_to :stock_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          has_many :adjustments, serializer: Spree::Api::Dependencies.platform_adjustment_serializer.constantize
          has_many :inventory_units, serializer: Spree::Api::Dependencies.platform_inventory_unit_serializer.constantize
          has_many :shipping_rates, serializer: Spree::Api::Dependencies.platform_shipping_rate_serializer.constantize
          has_many :state_changes, serializer: Spree::Api::Dependencies.platform_state_change_serializer.constantize
          has_one :selected_shipping_rate, serializer: Spree::Api::Dependencies.platform_shipping_rate_serializer.constantize, type: :shipping_rate
        end
      end
    end
  end
end

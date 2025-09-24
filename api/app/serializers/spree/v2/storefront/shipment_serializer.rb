module Spree
  module V2
    module Storefront
      class ShipmentSerializer < BaseSerializer
        set_type :shipment

        attributes :number, :final_price, :display_final_price,
                   :state, :shipped_at, :tracking_url, :public_metadata

        attribute :free do |shipment|
          shipment.free?
        end

        has_many :shipping_rates, serializer: Spree::Api::Dependencies.storefront_shipping_rate_serializer.constantize
        has_one :selected_shipping_rate, serializer: Spree::Api::Dependencies.storefront_shipping_rate_serializer.constantize

        belongs_to :stock_location, serializer: Spree::Api::Dependencies.storefront_stock_location_serializer.constantize
        has_many :line_items, serializer: Spree::Api::Dependencies.storefront_line_item_serializer.constantize do |shipment|
          shipment.line_items
        end
      end
    end
  end
end

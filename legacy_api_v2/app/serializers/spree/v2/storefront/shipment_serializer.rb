module Spree
  module V2
    module Storefront
      class ShipmentSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type :shipment

        attributes :number, :final_price, :display_final_price,
                   :state, :shipped_at, :tracking_url, :public_metadata

        attribute :free do |shipment|
          shipment.free?
        end

        has_many :shipping_rates, serializer: Spree.api.storefront_shipping_rate_serializer
        has_one :selected_shipping_rate, serializer: Spree.api.storefront_shipping_rate_serializer

        belongs_to :stock_location, serializer: Spree.api.storefront_stock_location_serializer
        has_many :line_items, serializer: Spree.api.storefront_line_item_serializer do |shipment|
          shipment.line_items
        end
      end
    end
  end
end

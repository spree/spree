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

        has_many :shipping_rates
        has_one :selected_shipping_rate, serializer: :shipping_rate

        belongs_to :stock_location
        has_many :line_items do |shipment|
          shipment.line_items
        end
      end
    end
  end
end

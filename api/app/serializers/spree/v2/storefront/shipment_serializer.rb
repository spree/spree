module Spree
  module V2
    module Storefront
      class ShipmentSerializer < BaseSerializer
        set_type :shipment

        attributes :number, :final_price, :display_final_price,
                   :state, :shipped_at, :tracking_url

        attribute :free, &:free?

        has_many :shipping_rates, if: proc { |_record, params| params&.dig(:show_rates) }

        belongs_to :stock_location
      end
    end
  end
end

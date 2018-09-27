module Spree
  module V2
    module Storefront
      class ShipmentSerializer < BaseSerializer
        set_type :shipment

        attributes :tracking, :number, :cost, :display_cost, :discounted_cost, :display_discounted_cost,
                   :final_price, :display_final_price, :item_cost, :display_item_cost, :shipped_at
      end
    end
  end
end

module Spree
  module Api
    module V3
      class ShipmentSerializer < BaseSerializer
        attributes :id, :number, :state, :tracking, :tracking_url, :shipped_at,
                   :cost, :display_cost, :adjustment_total, :display_adjustment_total,
                   :additional_tax_total, :display_additional_tax_total, :promo_total, :display_promo_total,
                   :included_tax_total, :display_included_tax_total, :total, :display_total

        one :shipping_method, resource: Spree.api.v3_storefront_shipping_method_serializer
        one :stock_location, resource: Spree.api.v3_storefront_stock_location_serializer

        many :shipping_rates, resource: Spree.api.v3_storefront_shipping_rate_serializer
      end
    end
  end
end

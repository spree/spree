module Spree
  module Api
    module V3
      class ShipmentSerializer < BaseSerializer
        typelize number: :string, state: :string, tracking: 'string | null',
                 tracking_url: 'string | null', shipped_at: 'string | null',
                 cost: :number, display_cost: :string,
                 adjustment_total: :number, display_adjustment_total: :string,
                 additional_tax_total: :number, display_additional_tax_total: :string,
                 promo_total: :number, display_promo_total: :string,
                 included_tax_total: :number, display_included_tax_total: :string,
                 total: :number, display_total: :string

        attributes :number, :state, :tracking, :tracking_url, :shipped_at,
                   :cost, :display_cost, :adjustment_total, :display_adjustment_total,
                   :additional_tax_total, :display_additional_tax_total, :promo_total, :display_promo_total,
                   :included_tax_total, :display_included_tax_total, :total, :display_total,
                   created_at: :iso8601, updated_at: :iso8601

        one :shipping_method, resource: Spree.api.shipping_method_serializer
        one :stock_location, resource: Spree.api.stock_location_serializer
        many :shipping_rates, resource: Spree.api.shipping_rate_serializer
      end
    end
  end
end

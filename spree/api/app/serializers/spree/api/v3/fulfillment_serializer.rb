module Spree
  module Api
    module V3
      class FulfillmentSerializer < BaseSerializer
        typelize number: :string, status: :string, fulfillment_type: :string,
                 tracking: [:string, nullable: true],
                 tracking_url: [:string, nullable: true], fulfilled_at: [:string, nullable: true],
                 cost: :string, display_cost: :string,
                 total: :string, display_total: :string,
                 discount_total: :string, display_discount_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 items: 'Array<{ item_id: string; variant_id: string; quantity: number }>'

        attributes :number, :tracking, :tracking_url,
                   :cost, :display_cost,
                   :total, :display_total,
                   :discount_total, :display_discount_total,
                   :additional_tax_total, :display_additional_tax_total,
                   :included_tax_total, :display_included_tax_total,
                   :tax_total, :display_tax_total

        attribute :status do |shipment|
          shipment.state
        end

        attribute :fulfillment_type do |shipment|
          shipment.digital? ? 'digital' : 'shipping'
        end

        attribute :fulfilled_at do |shipment|
          shipment.shipped_at&.iso8601
        end

        # Which items (and how many) are in this fulfillment.
        # A line item can be split across fulfillments with different quantities.
        attribute :items do |shipment|
          shipment.manifest.map do |item|
            {
              item_id: item.line_item.prefixed_id,
              variant_id: item.variant.prefixed_id,
              quantity: item.quantity
            }
          end
        end

        one :shipping_method, key: :delivery_method, resource: Spree.api.delivery_method_serializer
        one :stock_location, resource: Spree.api.stock_location_serializer
        many :shipping_rates, key: :delivery_rates, resource: Spree.api.delivery_rate_serializer
      end
    end
  end
end

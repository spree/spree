module Spree
  module Api
    module V3
      class FulfillmentSerializer < BaseSerializer
        typelize number: :string,
                 status: [:string, enum: Spree::Fulfillment.statuses, enum_type_name: 'FulfillmentStatus'],
                 fulfillment_type: [:string, enum: %w[shipping digital pickup pickup_point], enum_type_name: 'FulfillmentType'],
                 tracking: [:string, nullable: true], tracking_url: [:string, nullable: true],
                 fulfilled_at: [:string, nullable: true], delivered_at: [:string, nullable: true], unpriced: :boolean,
                 pickup_point_data: ['Record<string, unknown>', nullable: true],
                 selected_delivery_rate_id: [:string, nullable: true],
                 pickup_location: { nullable: true,
                                    comment: 'Where the customer collects a pickup — the counter chosen at checkout, ' \
                                             'which can differ from the stock location it ships from. ' \
                                             'Null unless the delivery is a pickup.' }

        # +tracking+ and +tracking_url+ summarize the primary delivery; every
        # consignment is listed under +deliveries+.
        attributes :number, :tracking, :tracking_url, :pickup_point_data, :selected_delivery_rate_id

        # Nulled for gated (prices_hidden) guests so a fulfillment can't leak the
        # shipping/tax amounts the cart/order totals already withhold.
        # Says the shipping price is still to come, so a client need not
        # infer it from a zero cost. Not price-gated — a flag, not an amount.
        attribute :unpriced, &:unpriced?

        money_attributes :cost, :display_cost,
                         :total, :display_total,
                         :discount_total, :display_discount_total,
                         :additional_tax_total, :display_additional_tax_total,
                         :included_tax_total, :display_included_tax_total,
                         :tax_total, :display_tax_total

        attributes :status

        attributes :fulfillment_type

        attributes fulfilled_at: :iso8601, delivered_at: :iso8601

        # Which items (and how many) are in this fulfillment.
        # A line item can be split across fulfillments with different quantities.
        typelize({ item_id: [:string, comment: 'Line item ID'],
                   variant_id: [:string, comment: 'Variant ID'],
                   quantity: [:number, comment: 'Quantity in this fulfillment'] },
                 multi: true, comment: 'Which line items, and how many units of each, are in this fulfillment')
        attribute :items do |fulfillment|
          fulfillment.manifest.filter_map do |item|
            next unless item.line_item

            {
              item_id: item.line_item.prefixed_id,
              variant_id: item.variant.prefixed_id,
              quantity: item.quantity
            }
          end
        end

        # Where each parcel is, as the carrier last reported it — the
        # customer's question, so always embedded.
        many :deliveries, resource: proc { Spree.api.delivery_serializer }
        one :delivery_method, resource: proc { Spree.api.delivery_method_serializer }
        one :stock_location, resource: proc { Spree.api.stock_location_serializer }
        one :pickup_location, resource: proc { Spree.api.stock_location_serializer }
        many :delivery_rates, resource: proc { Spree.api.delivery_rate_serializer }
        many :tax_lines, resource: proc { Spree.api.tax_line_serializer }, if: proc { expand?('tax_lines') }

        expandable_custom_fields
      end
    end
  end
end

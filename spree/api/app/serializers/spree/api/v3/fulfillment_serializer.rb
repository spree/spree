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
                 selected_delivery_rate_id: [:string, nullable: true]

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

        # Column-backed since 6.0; the fallback covers rows created before the
        # fulfillment_type backfill ran.
        attribute :fulfillment_type do |fulfillment|
          fulfillment.fulfillment_type.presence || (fulfillment.digital? ? 'digital' : 'shipping')
        end

        attributes fulfilled_at: :iso8601, delivered_at: :iso8601

        # Which items (and how many) are in this fulfillment, one row per line
        # item. A line item can be split across fulfillments with different
        # quantities, and within one fulfillment across several units.
        #
        # With the `returnability` param (the Store order page asks for it),
        # each row also says what the customer may still send back:
        # `returnable_quantity`, `non_returnable_reason` when that is nothing,
        # and its shipped `units`, whose `fulfillment_item_id` is what opening a
        # return takes. It is the customer's view — every rule is advisory for
        # staff — so nothing else asks for it.
        typelize({ item_id: :string, variant_id: :string, quantity: :number, returnable_quantity?: :number,
                   non_returnable_reason?: [:string, { nullable: true }],
                   units?: [[{ fulfillment_item_id: :string, quantity: :number, returnable_quantity: :number,
                               non_returnable_reason: [:string, { nullable: true }] }], { multi: true }] }, multi: true)
        attribute :items do |fulfillment|
          fulfillment.manifest.filter_map do |item|
            next unless item.line_item

            row = { item_id: item.line_item.prefixed_id, variant_id: item.variant.prefixed_id, quantity: item.quantity }
            params[:returnability] ? row.merge(fulfillment.returnability(item.units)) : row
          end
        end

        # Where each parcel is, as the carrier last reported it — the
        # customer's question, so always embedded.
        many :deliveries, resource: proc { Spree.api.delivery_serializer }
        one :delivery_method, resource: proc { Spree.api.delivery_method_serializer }
        one :stock_location, resource: proc { Spree.api.stock_location_serializer }
        many :delivery_rates, resource: proc { Spree.api.delivery_rate_serializer }
        many :tax_lines, resource: proc { Spree.api.tax_line_serializer }, if: proc { expand?('tax_lines') }

        expandable_custom_fields
      end
    end
  end
end

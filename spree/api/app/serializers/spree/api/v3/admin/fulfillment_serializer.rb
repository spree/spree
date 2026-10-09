module Spree
  module Api
    module V3
      module Admin
        class FulfillmentSerializer < V3::FulfillmentSerializer
          without_formatted_money

          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize cost: [:string, nullable: false],
                   total: [:string, nullable: false],
                   discount_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false],
                   included_tax_total: [:string, nullable: false],
                   tax_total: [:string, nullable: false]

          typelize metadata: 'Record<string, unknown>',
                   documents: "Array<{ kind: string; url: string }>",
                   provider_generates_labels: :boolean,
                   order_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true]

          attributes :metadata, created_at: :iso8601, updated_at: :iso8601

          money_attributes :adjustment_total, :pre_tax_amount
          typelize adjustment_total: [:string, nullable: false], pre_tax_amount: [:string, nullable: false]

          prefixed_id_attributes :order, :stock_location

          # Customs forms and other paperwork the provider produced beside the
          # label; the labels themselves are listed under +labels+.
          attribute :documents do |fulfillment|
            fulfillment.provider.documents(fulfillment).map(&:as_json)
          end

          # Every label bought or uploaded for this parcel, refunded ones
          # included — the postage history of the box.
          many :shipping_labels, key: :labels, resource: proc { Spree.api.admin_shipping_label_serializer }

          # Whether the buy-label step applies to this parcel's provider.
          attribute :provider_generates_labels do |fulfillment|
            fulfillment.provider.class.generates_labels?
          end

          # Override inherited associations to use admin serializers
          many :deliveries, resource: proc { Spree.api.admin_delivery_serializer }
          one :delivery_method, resource: proc { Spree.api.admin_delivery_method_serializer }, if: proc { expand?('delivery_method') }
          one :stock_location, resource: proc { Spree.api.admin_stock_location_serializer }, if: proc { expand?('stock_location') }
          many :delivery_rates, resource: proc { Spree.api.admin_delivery_rate_serializer }, if: proc { expand?('delivery_rates') }
          many :tax_lines, resource: proc { Spree.api.admin_tax_line_serializer }, if: proc { expand?('tax_lines') }

          # The units in this fulfillment — the dashboard needs them to offer
          # what can actually be returned or exchanged.
          many :fulfillment_items,
               resource: proc { Spree.api.admin_fulfillment_item_serializer },
               if: proc { expand?('fulfillment_items') }

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }

        end
      end
    end
  end
end

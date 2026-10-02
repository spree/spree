module Spree
  module Api
    module V3
      module Admin
        class FulfillmentSerializer < V3::FulfillmentSerializer
          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize cost: [:string, nullable: false], display_cost: [:string, nullable: false],
                   total: [:string, nullable: false], display_total: [:string, nullable: false],
                   discount_total: [:string, nullable: false], display_discount_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false], display_additional_tax_total: [:string, nullable: false],
                   included_tax_total: [:string, nullable: false], display_included_tax_total: [:string, nullable: false],
                   tax_total: [:string, nullable: false], display_tax_total: [:string, nullable: false]

          typelize metadata: 'Record<string, unknown>',
                   documents: "Array<{ kind: string; url: string }>",
                   provider_generates_labels: :boolean,
                   order_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   adjustment_total: :string,
                   pre_tax_amount: :string

          attributes :metadata, :adjustment_total, :pre_tax_amount,
                     created_at: :iso8601, updated_at: :iso8601

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
          expandable :one, :delivery_method, :admin_delivery_method_serializer
          expandable :one, :stock_location, :admin_stock_location_serializer
          expandable :many, :delivery_rates, :admin_delivery_rate_serializer
          expandable :many, :tax_lines, :admin_tax_line_serializer

          # The units in this fulfillment — the dashboard needs them to offer
          # what can actually be returned or exchanged.
          expandable :many, :fulfillment_items, :admin_fulfillment_item_serializer

          expandable :one, :order, :admin_order_serializer

        end
      end
    end
  end
end

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
                   order_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   adjustment_total: :string,
                   pre_tax_amount: :string

          attributes :metadata, :adjustment_total, :pre_tax_amount,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :order_id do |shipment|
            shipment.order&.prefixed_id
          end

          attribute :stock_location_id do |shipment|
            shipment.stock_location&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          one :shipping_method, key: :delivery_method, resource: proc { Spree.api.admin_delivery_method_serializer }, if: proc { expand?('delivery_method') }
          one :stock_location, resource: proc { Spree.api.admin_stock_location_serializer }, if: proc { expand?('stock_location') }
          many :shipping_rates, key: :delivery_rates, resource: proc { Spree.api.admin_delivery_rate_serializer }, if: proc { expand?('delivery_rates') }

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }

          many :adjustments,
               resource: proc { Spree.api.admin_adjustment_serializer },
               if: proc { expand?('adjustments') }
        end
      end
    end
  end
end

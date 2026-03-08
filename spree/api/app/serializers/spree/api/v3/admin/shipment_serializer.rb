module Spree
  module Api
    module V3
      module Admin
        class ShipmentSerializer < V3::ShipmentSerializer
          typelize metadata: 'Record<string, unknown> | null',
                   order_id: [:string, nullable: true],
                   stock_location_id: [:string, nullable: true],
                   adjustment_total: :string, additional_tax_total: :string,
                   included_tax_total: :string, promo_total: :string,
                   pre_tax_amount: :string

          attributes :adjustment_total, :additional_tax_total,
                     :included_tax_total, :promo_total, :pre_tax_amount

          attribute :metadata do |shipment|
            shipment.metadata.presence
          end

          attribute :order_id do |shipment|
            shipment.order&.prefixed_id
          end

          attribute :stock_location_id do |shipment|
            shipment.stock_location&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          one :shipping_method, resource: Spree.api.admin_shipping_method_serializer, if: proc { expand?('shipping_method') }
          one :stock_location, resource: Spree.api.admin_stock_location_serializer, if: proc { expand?('stock_location') }
          many :shipping_rates, resource: Spree.api.admin_shipping_rate_serializer, if: proc { expand?('shipping_rates') }

          one :order,
              resource: Spree.api.admin_order_serializer,
              if: proc { expand?('order') }

          many :adjustments,
               resource: Spree.api.admin_adjustment_serializer,
               if: proc { expand?('adjustments') }
        end
      end
    end
  end
end

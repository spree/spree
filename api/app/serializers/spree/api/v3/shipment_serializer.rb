module Spree
  module Api
    module V3
      class ShipmentSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            number: resource.number,
            state: resource.state,
            tracking: resource.tracking,
            cost: resource.cost.to_f,
            display_cost: resource.display_cost.to_s,
            shipped_at: timestamp(resource.shipped_at),
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at),
            shipping_method: serialize_shipping_method,
            stock_location: serialize_stock_location
          }

          # Conditionally include associations
          base_attrs[:shipping_rates] = serialize_shipping_rates if include?('shipping_rates')

          base_attrs
        end

        private

        def serialize_shipping_method
          return unless resource.shipping_method

          {
            id: resource.shipping_method.id,
            name: resource.shipping_method.name,
            code: resource.shipping_method.code
          }
        end

        def serialize_stock_location
          return unless resource.stock_location

          {
            id: resource.stock_location.id,
            name: resource.stock_location.name
          }
        end

        def serialize_shipping_rates
          resource.shipping_rates.map do |shipping_rate|
            shipping_rate_serializer.new(shipping_rate, nested_context('shipping_rates')).as_json
          end
        end

        # Serializer dependencies
        def shipping_rate_serializer
          Spree::Api::Dependencies.v3_storefront_shipping_rate_serializer.constantize
        end
      end
    end
  end
end

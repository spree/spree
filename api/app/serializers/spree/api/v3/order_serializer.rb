module Spree
  module Api
    module V3
      class OrderSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            number: resource.number,
            state: resource.state,
            token: resource.token,
            email: resource.email,
            special_instructions: resource.special_instructions,
            currency: resource.currency,
            item_count: resource.item_count,

            # Totals
            item_total: resource.item_total.to_f,
            display_item_total: resource.display_item_total.to_s,

            ship_total: resource.ship_total.to_f,
            display_ship_total: resource.display_ship_total.to_s,

            adjustment_total: resource.adjustment_total.to_f,
            display_adjustment_total: resource.display_adjustment_total.to_s,

            promo_total: resource.promo_total.to_f,
            display_promo_total: resource.display_promo_total.to_s,

            tax_total: resource.tax_total.to_f,
            display_tax_total: resource.display_tax_total.to_s,

            included_tax_total: resource.included_tax_total.to_f,
            display_included_tax_total: resource.display_included_tax_total.to_s,

            additional_tax_total: resource.additional_tax_total.to_f,
            display_additional_tax_total: resource.display_additional_tax_total.to_s,

            total: resource.total.to_f,
            display_total: resource.display_total.to_s,

            # States
            shipment_state: resource.shipment_state,
            payment_state: resource.payment_state,

            # Timestamps
            completed_at: timestamp(resource.completed_at),
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include associations
          base_attrs[:line_items] = serialize_line_items if include?('line_items')
          base_attrs[:payments] = serialize_payments if include?('payments')
          base_attrs[:shipments] = serialize_shipments if include?('shipments')
          base_attrs[:billing_address] = serialize_billing_address if include?('billing_address')
          base_attrs[:shipping_address] = serialize_shipping_address if include?('shipping_address')

          base_attrs
        end

        private

        def serialize_line_items
          resource.line_items.map do |line_item|
            line_item_serializer.new(line_item, nested_context('line_items')).as_json
          end
        end

        def serialize_payments
          resource.payments.valid.map do |payment|
            payment_serializer.new(payment, nested_context('payments')).as_json
          end
        end

        def serialize_shipments
          resource.shipments.map do |shipment|
            shipment_serializer.new(shipment, nested_context('shipments')).as_json
          end
        end

        def serialize_billing_address
          address_serializer.new(resource.bill_address, nested_context('billing_address')).as_json if resource.bill_address
        end

        def serialize_shipping_address
          address_serializer.new(resource.ship_address, nested_context('shipping_address')).as_json if resource.ship_address
        end

        # Serializer dependencies
        def line_item_serializer
          Spree::Api::Dependencies.v3_storefront_line_item_serializer.constantize
        end

        def payment_serializer
          Spree::Api::Dependencies.v3_storefront_payment_serializer.constantize
        end

        def shipment_serializer
          Spree::Api::Dependencies.v3_storefront_shipment_serializer.constantize
        end

        def address_serializer
          Spree::Api::Dependencies.v3_storefront_address_serializer.constantize
        end
      end
    end
  end
end

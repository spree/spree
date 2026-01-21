module Spree
  module Api
    module V3
      class OrderSerializer < BaseSerializer
        attributes :id, :number, :state, :token, :email, :special_instructions,
                   :currency, :item_count, :shipment_state, :payment_state

        # Totals
        attribute :item_total do |order|
          order.item_total.to_f
        end

        attribute :display_item_total do |order|
          order.display_item_total.to_s
        end

        attribute :ship_total do |order|
          order.ship_total.to_f
        end

        attribute :display_ship_total do |order|
          order.display_ship_total.to_s
        end

        attribute :adjustment_total do |order|
          order.adjustment_total.to_f
        end

        attribute :display_adjustment_total do |order|
          order.display_adjustment_total.to_s
        end

        attribute :promo_total do |order|
          order.promo_total.to_f
        end

        attribute :display_promo_total do |order|
          order.display_promo_total.to_s
        end

        attribute :tax_total do |order|
          order.tax_total.to_f
        end

        attribute :display_tax_total do |order|
          order.display_tax_total.to_s
        end

        attribute :included_tax_total do |order|
          order.included_tax_total.to_f
        end

        attribute :display_included_tax_total do |order|
          order.display_included_tax_total.to_s
        end

        attribute :additional_tax_total do |order|
          order.additional_tax_total.to_f
        end

        attribute :display_additional_tax_total do |order|
          order.display_additional_tax_total.to_s
        end

        attribute :total do |order|
          order.total.to_f
        end

        attribute :display_total do |order|
          order.display_total.to_s
        end

        # Timestamps
        attributes completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        # Conditional associations
        many :line_items,
             resource: Spree.api.v3_storefront_line_item_serializer,
             if: proc { params[:includes]&.include?('line_items') }

        many :shipments,
             resource: Spree.api.v3_storefront_shipment_serializer,
             if: proc { params[:includes]&.include?('shipments') }

        many :payments,
             resource: Spree.api.v3_storefront_payment_serializer,
             if: proc { params[:includes]&.include?('payments') } do |order|
          order.payments.valid
        end

        one :billing_address,
            resource: Spree.api.v3_storefront_address_serializer,
            if: proc { params[:includes]&.include?('billing_address') } do |order|
          order.bill_address
        end

        one :shipping_address,
            resource: Spree.api.v3_storefront_address_serializer,
            if: proc { params[:includes]&.include?('shipping_address') } do |order|
          order.ship_address
        end
      end
    end
  end
end

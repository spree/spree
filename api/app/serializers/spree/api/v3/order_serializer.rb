module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Customer-facing order data
      class OrderSerializer < BaseSerializer
        typelize number: :string, state: :string, token: :string, email: 'string | null',
                 special_instructions: 'string | null', currency: :string, item_count: :number,
                 shipment_state: 'string | null', payment_state: 'string | null',
                 item_total: :number, display_item_total: :string,
                 ship_total: :number, display_ship_total: :string,
                 adjustment_total: :number, display_adjustment_total: :string,
                 promo_total: :number, display_promo_total: :string,
                 tax_total: :number, display_tax_total: :string,
                 included_tax_total: :number, display_included_tax_total: :string,
                 additional_tax_total: :number, display_additional_tax_total: :string,
                 total: :number, display_total: :string, completed_at: 'string | null'

        attributes :number, :state, :token, :email, :special_instructions,
                   :currency, :item_count, :shipment_state, :payment_state,
                   :item_total, :display_item_total, :ship_total, :display_ship_total,
                   :adjustment_total, :display_adjustment_total, :promo_total, :display_promo_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        many :order_promotions,
             resource: Spree.api.order_promotion_serializer,
             if: proc { params[:includes]&.include?('order_promotions') }

        many :line_items,
             resource: Spree.api.line_item_serializer,
             if: proc { params[:includes]&.include?('line_items') }

        many :shipments,
             resource: Spree.api.shipment_serializer,
             if: proc { params[:includes]&.include?('shipments') }

        many :payments,
             resource: Spree.api.payment_serializer,
             if: proc { params[:includes]&.include?('payments') }

        one :bill_address,
            resource: Spree.api.address_serializer,
            if: proc { params[:includes]&.include?('bill_address') }

        one :ship_address,
            resource: Spree.api.address_serializer,
            if: proc { params[:includes]&.include?('ship_address') }

        many :payment_methods,
             resource: Spree.api.payment_method_serializer
      end
    end
  end
end

module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Customer-facing order data
      class OrderSerializer < BaseSerializer
        typelize number: :string, state: :string, token: :string, email: [:string, nullable: true],
                 special_instructions: [:string, nullable: true], currency: :string, locale: [:string, nullable: true], item_count: :number,
                 shipment_state: [:string, nullable: true], payment_state: [:string, nullable: true],
                 item_total: :string, display_item_total: :string,
                 ship_total: :string, display_ship_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 promo_total: :string, display_promo_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 total: :string, display_total: :string, completed_at: [:string, nullable: true],
                 bill_address: { nullable: true }, ship_address: { nullable: true }

        attributes :number, :state, :token, :email, :special_instructions,
                   :currency, :locale, :item_count, :shipment_state, :payment_state,
                   :item_total, :display_item_total, :ship_total, :display_ship_total,
                   :adjustment_total, :display_adjustment_total, :promo_total, :display_promo_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        many :order_promotions, resource: Spree.api.order_promotion_serializer
        many :line_items, resource: Spree.api.line_item_serializer
        many :shipments, resource: Spree.api.shipment_serializer
        many :payments, resource: Spree.api.payment_serializer
        one :bill_address, resource: Spree.api.address_serializer
        one :ship_address, resource: Spree.api.address_serializer

        many :payment_methods, resource: Spree.api.payment_method_serializer
      end
    end
  end
end

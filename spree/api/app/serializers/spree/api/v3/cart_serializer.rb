module Spree
  module Api
    module V3
      # Store API Cart Serializer
      # Pre-purchase cart data with checkout progression info
      class CartSerializer < BaseSerializer
        typelize number: :string, state: :string, checkout_steps: 'string[]', token: :string, email: [:string, nullable: true],
                 special_instructions: [:string, nullable: true], currency: :string, locale: [:string, nullable: true], item_count: :number,
                 state_lock_version: :number,
                 item_total: :string, display_item_total: :string,
                 ship_total: :string, display_ship_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 promo_total: :string, display_promo_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 total: :string, display_total: :string,
                 bill_address: { nullable: true }, ship_address: { nullable: true }

        # Override ID to use cart_ prefix
        attribute :id do |order|
          "cart_#{Spree::PrefixedId::SQIDS.encode([order.id])}"
        end

        attributes :number, :state, :checkout_steps, :token, :email, :special_instructions,
                   :currency, :locale, :item_count, :state_lock_version,
                   :item_total, :display_item_total, :ship_total, :display_ship_total,
                   :adjustment_total, :display_adjustment_total, :promo_total, :display_promo_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   created_at: :iso8601, updated_at: :iso8601

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

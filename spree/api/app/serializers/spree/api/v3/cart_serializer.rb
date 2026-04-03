module Spree
  module Api
    module V3
      # Store API Cart Serializer
      # Pre-purchase cart data with checkout progression info
      class CartSerializer < BaseSerializer
        typelize number: :string, current_step: :string, completed_steps: 'string[]', token: :string, email: [:string, nullable: true],
                 customer_note: [:string, nullable: true], market_id: [:string, nullable: true],
                 currency: :string, locale: [:string, nullable: true], total_quantity: :number,
                 requirements: 'Array<{step: string, field: string, message: string}>',
                 item_total: :string, display_item_total: :string,
                 delivery_total: :string, display_delivery_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 discount_total: :string, display_discount_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 store_credit_total: :string, display_store_credit_total: :string,
                 gift_card_total: :string, display_gift_card_total: :string,
                 covered_by_store_credit: :boolean,
                 total: :string, display_total: :string,
                 amount_due: :string, display_amount_due: :string,
                 shipping_eq_billing_address: :boolean,
                 warnings: 'Array<{code: string, message: string, line_item_id?: string, variant_id?: string}>',
                 billing_address: { nullable: true }, shipping_address: { nullable: true },
                 gift_card: { nullable: true }, market: { nullable: true }

        # Override ID to use cart_ prefix
        attribute :id do |order|
          "cart_#{Spree::PrefixedId::SQIDS.encode([order.id])}"
        end

        attribute :market_id do |order|
          order.market&.prefixed_id
        end

        attributes :number, :token, :email, :customer_note,
                   :currency, :locale, :total_quantity,
                   :item_total, :display_item_total,
                   :adjustment_total, :display_adjustment_total,
                   :discount_total, :display_discount_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   :gift_card_total, :display_gift_card_total,
                   :amount_due, :display_amount_due,
                   :delivery_total, :display_delivery_total, :warnings

        attribute :store_credit_total do |order|
          order.total_applied_store_credit.to_s
        end

        attribute :display_store_credit_total do |order|
          order.display_total_applied_store_credit.to_s
        end

        attribute :covered_by_store_credit do |order|
          order.covered_by_store_credit?
        end

        attribute :current_step do |order|
          order.current_checkout_step
        end

        attribute :completed_steps do |order|
          order.completed_checkout_steps
        end

        attribute :requirements do |order|
          Spree::Checkout::Requirements.new(order).call
        end

        attribute :shipping_eq_billing_address do |order|
          order.shipping_eq_billing_address?
        end

        many :discounts, resource: Spree.api.discount_serializer
        many :line_items, key: :items, resource: Spree.api.line_item_serializer
        many :fulfillments, resource: Spree.api.fulfillment_serializer
        many :payments, resource: Spree.api.payment_serializer
        one :billing_address, resource: Spree.api.address_serializer
        one :shipping_address, resource: Spree.api.address_serializer

        many :payment_methods, resource: Spree.api.payment_method_serializer
        one :gift_card, resource: Spree.api.gift_card_serializer
        one :market, resource: Spree.api.market_serializer
      end
    end
  end
end

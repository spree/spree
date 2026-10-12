module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Post-purchase order data (completed orders)
      class OrderSerializer < BaseSerializer
        typelize cart_id: [:string, nullable: true], number: :string, email: :string,
                 customer_note: [:string, nullable: true], market_id: [:string, nullable: true],
                 channel_id: [:string, nullable: true], company_id: [:string, nullable: true],
                 company_name: [:string, nullable: true], po_number: [:string, nullable: true],
                 po_document_filename: [:string, nullable: true], po_document_byte_size: ['number | null'],
                 currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'], locale: [:string, nullable: true], total_quantity: :number,
                 coupon_code: [:string, nullable: true],
                 fulfillment_status: [:string, nullable: true, enum: Spree::Order::FULFILLMENT_STATUSES],
                 payment_status: [:string, nullable: true, enum: Spree::Order::PAYMENT_STATUSES],
                 completed_at: [:string, nullable: true],
                 withdrawal_period_ends_at: [:string, nullable: true], within_withdrawal_period: :boolean,
                 billing_address: { nullable: true }, shipping_address: { nullable: true },
                 gift_card: { nullable: true }, market: { nullable: true }

        prefixed_id_attributes :market

        # The EU cooling-off deadline. Customer-facing by design: a buyer
        # deciding whether they can still send something back should not have
        # to work the date out from a policy page.
        attribute :withdrawal_period_ends_at do |order|
          order.withdrawal_period_ends_at&.iso8601
        end

        attribute :within_withdrawal_period, &:within_withdrawal_period?

        # The checkout handle this order was born from (nil for admin drafts).
        # Lets abandonment tooling match cart.* events to the conversion.
        # Encoded from the FK — loading the cart row just for its id would be
        # an N+1 on order lists.
        attribute :cart_id do |order|
          Spree::Cart.prefixed_id_for(order.cart_id)
        end

        prefixed_id_attributes :channel

        # Which company node the order was placed for — frozen at completion.
        prefixed_id_attributes :company

        attribute :company_name do |order|
          order.company&.name
        end

        # The buyer's own purchase-order reference, carried from the cart. Their
        # accounting reconciles against it, so it stays on the order forever.
        attribute :po_document_filename do |order|
          order.po_document.blob&.filename&.to_s if order.po_document.attached?
        end

        attribute :po_document_byte_size do |order|
          order.po_document.blob&.byte_size if order.po_document.attached?
        end

        attributes :number, :email, :customer_note, :po_number,
                   :currency, :locale, :total_quantity, :coupon_code,
                   :fulfillment_status, :payment_status,
                   completed_at: :iso8601

        # Nulled for gated (prices_hidden) guests, consistent with cart and
        # catalog price hiding.
        include Spree::Api::V3::PurchaseSummary
        money_attributes :adjustment_total, :display_adjustment_total

        many :order_promotions, key: :discounts, resource: proc { Spree.api.applied_promotion_serializer }
        # Itemized charges (duties, surcharges, COD, handling) — see the cart
        # serializer; the order keeps them visible after placement.
        many :fees, resource: proc { Spree.api.fee_serializer }
        many :line_items, key: :items, resource: proc { Spree.api.line_item_serializer }
        many :fulfillments, resource: proc { Spree.api.fulfillment_serializer }
        one :billing_address, resource: proc { Spree.api.address_serializer }
        one :shipping_address, resource: proc { Spree.api.address_serializer }
        one :gift_card, resource: proc { Spree.api.gift_card_serializer }
        one :market, resource: proc { Spree.api.market_serializer }
      end
    end
  end
end

module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Post-purchase order data (completed orders)
      class OrderSerializer < BaseSerializer
        typelize cart_id: [:string, nullable: true],
                 number: :string, email: :string,
                 customer_note: [:string, nullable: true],
                 market_id: [:string, nullable: true], channel_id: [:string, nullable: true],
                 company_id: [:string, nullable: true], company_name: [:string, nullable: true],
                 po_number: [:string, nullable: true],
                 po_document_filename: [:string, nullable: true],
                 po_document_byte_size: ['number | null'],
                 freight_summary: ['Record<string, unknown>', nullable: true],
                 currency: :string, locale: [:string, nullable: true], total_quantity: :number,
                 coupon_code: [:string, nullable: true],
                 fulfillment_status: [:string, nullable: true], payment_status: [:string, nullable: true],
                 item_total: [:string, nullable: true], display_item_total: [:string, nullable: true],
                 delivery_total: [:string, nullable: true], display_delivery_total: [:string, nullable: true],
                 adjustment_total: [:string, nullable: true], display_adjustment_total: [:string, nullable: true],
                 discount_total: [:string, nullable: true], display_discount_total: [:string, nullable: true],
                 tax_total: [:string, nullable: true], display_tax_total: [:string, nullable: true],
                 included_tax_total: [:string, nullable: true], display_included_tax_total: [:string, nullable: true],
                 additional_tax_total: [:string, nullable: true], display_additional_tax_total: [:string, nullable: true],
                 fee_total: [:string, nullable: true], display_fee_total: [:string, nullable: true],
                 store_credit_total: [:string, nullable: true], display_store_credit_total: [:string, nullable: true],
                 gift_card_total: [:string, nullable: true], display_gift_card_total: [:string, nullable: true],
                 covered_by_store_credit: :boolean,
                 total: [:string, nullable: true], display_total: [:string, nullable: true],
                 amount_due: [:string, nullable: true], display_amount_due: [:string, nullable: true],
                 completed_at: [:string, nullable: true],
                 withdrawal_period_ends_at: [:string, nullable: true],
                 within_withdrawal_period: :boolean,
                 billing_address: { nullable: true }, shipping_address: { nullable: true },
                 gift_card: { nullable: true }, market: { nullable: true }

        attribute :market_id do |order|
          order.market&.prefixed_id
        end

        # The EU cooling-off deadline. Customer-facing by design: a buyer
        # deciding whether they can still send something back should not have
        # to work the date out from a policy page.
        attribute :withdrawal_period_ends_at do |order|
          order.withdrawal_period_ends_at&.iso8601
        end

        attribute :within_withdrawal_period do |order|
          order.within_withdrawal_period?
        end

        # The checkout handle this order was born from (nil for admin drafts).
        # Lets abandonment tooling match cart.* events to the conversion.
        # Encoded from the FK — loading the cart row just for its id would be
        # an N+1 on order lists.
        attribute :cart_id do |order|
          Spree::Cart.prefixed_id_for(order.cart_id)
        end

        attribute :channel_id do |order|
          order.channel&.prefixed_id
        end

        # Which company node the order was placed for — frozen at completion.
        attribute :company_id do |order|
          order.company&.prefixed_id
        end

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

        # The shipment as the freight forwarder read it, frozen onto the rates
        # this order shipped under. Never re-derived, so repacking a product
        # cannot rewrite what an order that already left the warehouse held.
        # Per-line identity is withheld where prices are, as on the cart.
        attribute :freight_summary do |order|
          order.freight_summary&.as_json(identify_lines: !params[:hide_prices])
        end

        attributes :number, :email, :customer_note, :po_number,
                   :currency, :locale, :total_quantity, :coupon_code,
                   :fulfillment_status, :payment_status,
                   completed_at: :iso8601

        # Nulled for gated (prices_hidden) guests, consistent with cart and
        # catalog price hiding.
        money_attributes :item_total, :display_item_total,
                         :adjustment_total, :display_adjustment_total,
                         :discount_total, :display_discount_total,
                         :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                         :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                         :gift_card_total, :display_gift_card_total,
                         :amount_due, :display_amount_due,
                         :delivery_total, :display_delivery_total,
                         :fee_total, :display_fee_total

        attribute :store_credit_total do |order|
          order.total_applied_store_credit.to_s unless params[:hide_prices]
        end

        attribute :display_store_credit_total do |order|
          order.display_total_applied_store_credit.to_s unless params[:hide_prices]
        end

        attribute :covered_by_store_credit do |order|
          order.covered_by_store_credit?
        end

        many :order_promotions, key: :discounts, resource: proc { Spree.api.applied_promotion_serializer }
        # Itemized charges (duties, surcharges, COD, handling) — see the cart
        # serializer; the order keeps them visible after placement.
        many :fees, resource: proc { Spree.api.fee_serializer }
        many :line_items, key: :items, resource: proc { Spree.api.line_item_serializer }
        many :fulfillments, resource: proc { Spree.api.fulfillment_serializer }
        many :payments, resource: proc { Spree.api.payment_serializer }
        one :billing_address, resource: proc { Spree.api.address_serializer }
        one :shipping_address, resource: proc { Spree.api.address_serializer }
        one :gift_card, resource: proc { Spree.api.gift_card_serializer }
        one :market, resource: proc { Spree.api.market_serializer }
      end
    end
  end
end

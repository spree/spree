module Spree
  module Api
    module V3
      # Store API Cart Serializer
      # Pre-purchase cart data with checkout progression info
      class CartSerializer < BaseSerializer
        typelize number: :string, current_step: :string, completed_steps: 'string[]', token: :string, email: [:string, nullable: true],
                 customer_note: [:string, nullable: true], market_id: [:string, nullable: true], channel_id: [:string, nullable: true],
                 currency: :string, locale: [:string, nullable: true], total_quantity: :number,
                 coupon_code: [:string, nullable: true],
                 preferred_stock_location_id: [:string, nullable: true],
                 company_id: [:string, nullable: true], company_name: [:string, nullable: true],
                 po_number: [:string, nullable: true], po_number_required: :boolean,
                 po_document_filename: [:string, nullable: true],
                 po_document_byte_size: ['number | null'],
                 order_minimum: ['number | null'], order_minimum_shortfall: ['number | null'],
                 below_order_minimum: ['boolean | null'],
                 freight_summary: ['Record<string, unknown>', nullable: true],
                 requirements: 'Array<{step: string, field: string, code: string, message: string}>',
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
                 shipping_eq_billing_address: :boolean,
                 warnings: 'Array<{code: string, message: string, line_item_id?: string, variant_id?: string, item_index?: number}>',
                 billing_address: { nullable: true }, shipping_address: { nullable: true },
                 gift_card: { nullable: true }, market: { nullable: true }

        attribute :market_id do |order|
          order.market&.prefixed_id
        end

        # Which surface this cart belongs to — lets a multi-channel storefront
        # verify a cookie-persisted cart against its own channel before
        # adopting it (see the wholesale reference storefront's cart guard).
        attribute :channel_id do |order|
          order.channel&.prefixed_id
        end

        # Pickup selection — mirrors the writable param on cart update.
        attribute :preferred_stock_location_id do |cart|
          cart.preferred_stock_location&.prefixed_id
        end

        # Which company node the purchase is for — mirrors the writable
        # `company_id` param. Read from the column, never re-resolved.
        attribute :company_id do |cart|
          cart.company&.prefixed_id
        end

        attribute :company_name do |cart|
          cart.company&.name
        end

        # The buyer's own purchase-order reference, and whether their company
        # demands one — the storefront marks the field required from this
        # rather than fetching the company to ask.
        attribute :po_number_required do |cart|
          cart.po_number_required?
        end

        attribute :po_document_filename do |cart|
          cart.po_document.blob&.filename&.to_s if cart.po_document.attached?
        end

        attribute :po_document_byte_size do |cart|
          cart.po_document.blob&.byte_size if cart.po_document.attached?
        end

        # @deprecated `number` mirrors `id` (carts have no order-style
        #   number) — kept one release for 5.x clients; removed in 6.1.
        attributes :number, :token, :email, :customer_note, :po_number,
                   :currency, :locale, :total_quantity, :warnings, :coupon_code

        # Nulled for gated (prices_hidden) guests so the cart can't leak the
        # prices that product/variant serializers already withhold.
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

        attribute :current_step do |order|
          order.current_checkout_step
        end

        attribute :completed_steps do |order|
          order.completed_checkout_steps
        end

        # The order-minimum requirement names both amounts in its message, so
        # it is dropped rather than redacted for a gated guest: a requirement
        # with its numbers stripped tells them nothing they can act on.
        attribute :requirements do |order|
          requirements = Spree::Checkout::Requirements.new(order).call
          next requirements unless params[:hide_prices]

          requirements.reject { |requirement| requirement[:code] == 'order_minimum_not_met' }
        end

        # The order minimum in force for this buyer, or nil when their
        # agreements state none. Exposed alongside the shortfall so a
        # storefront can render "$180 to reach the $500 minimum" without
        # doing the arithmetic or knowing where the number came from.
        #
        # Gated with the rest of the price surface: a threshold and a
        # shortfall are amounts, and a storefront that hides prices from
        # guests must not hand them "$180 short of $500" instead.
        attribute :order_minimum do |order|
          order.order_minimum_amount&.to_f unless params[:hide_prices]
        end

        attribute :order_minimum_shortfall do |order|
          order.order_minimum_shortfall&.to_f unless params[:hide_prices]
        end

        attribute :below_order_minimum do |order|
          order.below_order_minimum? unless params[:hide_prices]
        end

        # The shipment as a freight forwarder reads it: cartons, pallets,
        # cubic meters, gross weight. Null for anything the store never
        # measured that way, which is every retail cart.
        #
        # The totals are logistics rather than amounts, so they survive a
        # storefront that hides prices; the per-line SKU and product name do
        # not, being the catalog identity such a storefront exists to
        # withhold.
        attribute :freight_summary do |purchase|
          purchase.freight_summary&.as_json(identify_lines: !params[:hide_prices])
        end

        attribute :shipping_eq_billing_address do |order|
          order.shipping_eq_billing_address?
        end

        many :order_promotions, key: :discounts, resource: proc { Spree.api.applied_promotion_serializer }
        # Itemized charges (duties, surcharges, COD, handling). Storefronts
        # group and label these themselves — cross-border duty in particular
        # has to be shown broken out rather than folded into a total.
        many :fees, resource: proc { Spree.api.fee_serializer }
        many :line_items, key: :items, resource: proc { Spree.api.line_item_serializer }
        many :fulfillments, resource: proc { Spree.api.fulfillment_serializer }
        many :payments, resource: proc { Spree.api.payment_serializer }
        one :billing_address, resource: proc { Spree.api.address_serializer }
        one :shipping_address, resource: proc { Spree.api.address_serializer }

        many :payment_methods, resource: proc { Spree.api.payment_method_serializer }
        one :gift_card, resource: proc { Spree.api.gift_card_serializer }
        one :market, resource: proc { Spree.api.market_serializer }
      end
    end
  end
end

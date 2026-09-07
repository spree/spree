module Spree
  module Api
    module V3
      module Seller
        # An order placed with this seller.
        #
        # Built from the base rather than the store serializer: that one is
        # written for the shopper who placed the order, and carries payments —
        # how the customer paid the marketplace is not the seller's business.
        # What they are owed overall is still the commission ledger; this
        # carries only what this one sale was charged.
        #
        # The addresses are here because the seller is merchant of record for
        # their child order (docs/plans/6.0-multi-vendor-marketplace.md): the
        # shipping address to post the parcel, the billing address because the
        # invoice for that sale is theirs to issue. Both marketplace platforms
        # we surveyed give a seller the same two.
        #
        # The buyer's email is not. A seller reaching the customer about a
        # delivery has the phone on the shipping address; an email address is
        # the one contact detail that lets a marketplace's customer be taken
        # off it, and it is not needed to pack, post or invoice.
        class OrderSerializer < V3::BaseSerializer
          typelize number: :string,
                   customer_note: [:string, nullable: true],
                   currency: :string,
                   total_quantity: :number,
                   fulfillment_status: [:string, nullable: true],
                   payment_status: [:string, nullable: true],
                   status: :string,
                   item_total: [:string, nullable: true], display_item_total: [:string, nullable: true],
                   delivery_total: [:string, nullable: true], display_delivery_total: [:string, nullable: true],
                   discount_total: [:string, nullable: true], display_discount_total: [:string, nullable: true],
                   adjustment_total: [:string, nullable: true], display_adjustment_total: [:string, nullable: true],
                   included_tax_total: [:string, nullable: true], display_included_tax_total: [:string, nullable: true],
                   additional_tax_total: [:string, nullable: true], display_additional_tax_total: [:string, nullable: true],
                   tax_total: [:string, nullable: true], display_tax_total: [:string, nullable: true],
                   total: [:string, nullable: true], display_total: [:string, nullable: true],
                   payment_total: [:string, nullable: true], display_payment_total: [:string, nullable: true],
                   amount_due: [:string, nullable: true], display_amount_due: [:string, nullable: true],
                   commission_amount_total: [:string, nullable: true],
                   display_commission_amount_total: [:string, nullable: true],
                   commission_tax_total: [:string, nullable: true],
                   display_commission_tax_total: [:string, nullable: true],
                   commission_total: [:string, nullable: true],
                   display_commission_total: [:string, nullable: true],
                   canceled_at: [:string, nullable: true],
                   cancel_reason_name: [:string, nullable: true],
                   cancel_note: [:string, nullable: true],
                   internal_note: [:string, nullable: true],
                   internal_note_html: [:string, nullable: true]

          attributes :number, :customer_note, :currency, :total_quantity,
                     :status, :fulfillment_status, :payment_status,
                     completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          # The seller's own working note. A marketplace basket is split into
          # one order per seller, so this row — and the note on it — is theirs
          # alone; it is never the operator's note about the whole sale.
          attribute :internal_note do |order|
            Spree::RichTextHelper.to_plain_text(order.internal_note).presence
          end

          attribute :internal_note_html do |order|
            order.internal_note.presence
          end

          # What this seller is owed for the goods, and what the buyer paid for
          # them. Deliberately not the whole money surface: gift cards, store
          # credit and the payment breakdown belong to the marketplace.
          money_attributes :item_total, :display_item_total,
                           :delivery_total, :display_delivery_total,
                           :discount_total, :display_discount_total,
                           :adjustment_total, :display_adjustment_total,
                           :included_tax_total, :display_included_tax_total,
                           :additional_tax_total, :display_additional_tax_total,
                           :tax_total, :display_tax_total,
                           :total, :display_total,
                           :payment_total, :display_payment_total,
                           :amount_due, :display_amount_due

          # What the marketplace charged the seller on this sale, and the tax
          # on that charge. The ledger remains where a seller sees what they
          # are owed overall, but the tax belongs on the order itself: the
          # commission is a B2B supply from the platform, so this is the
          # seller's input tax to reclaim, and it has to be attributable to
          # the sale that produced it.
          money_attributes :commission_amount_total, :display_commission_amount_total,
                           :commission_tax_total, :display_commission_tax_total,
                           :commission_total, :display_commission_total

          # Why the sale was called off, when it was. The reason is the
          # marketplace's vocabulary, so it is rendered as a name rather than
          # an id a seller has nothing else to do with.
          attribute :canceled_at do |order|
            order.canceled_at&.iso8601
          end

          attribute :cancel_reason_name do |order|
            order.cancel_reason&.name
          end

          attributes :cancel_note

          many :line_items, key: :items, resource: proc { Spree.api.seller_order_line_item_serializer }
          many :fulfillments, resource: proc { Spree.api.seller_fulfillment_serializer }
          one :shipping_address, resource: proc { Spree.api.address_serializer }
          one :billing_address, resource: proc { Spree.api.address_serializer }
        end
      end
    end
  end
end

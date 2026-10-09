module Spree
  module Api
    module V3
      # Store API Order Group Serializer
      #
      # What the customer bought in one checkout, when it was fulfilled by more
      # than one seller. They made one purchase and paid once, so this is what
      # their order history shows them — with the per-seller orders nested
      # inside it, each carrying its own items, delivery and tracking.
      class OrderGroupSerializer < BaseSerializer
        typelize number: :string, email: [:string, nullable: true], currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'],
                 fulfillment_status: [:string, nullable: true, enum: Spree::Order::FULFILLMENT_STATUSES],
                 payment_status: [:string, nullable: true, enum: Spree::Order::PAYMENT_STATUSES],
                 completed_at: [:string, nullable: true],
                 store_credit_total: [:string, nullable: true],
                 display_store_credit_total: [:string, nullable: true],
                 covered_by_store_credit: :boolean,
                 billing_address: { nullable: true }, shipping_address: { nullable: true }

        attributes :number, :email, :currency

        # The same money lines an order carries, so one summary renders either
        # shape without asking which it got. Every figure but the two the group
        # stores is rolled up from the children, never prorated back down.
        money_attributes :total, :display_total, :item_total, :display_item_total,
                         :delivery_total, :display_delivery_total,
                         :discount_total, :display_discount_total,
                         :tax_total, :display_tax_total,
                         :included_tax_total, :display_included_tax_total,
                         :additional_tax_total, :display_additional_tax_total,
                         :fee_total, :display_fee_total,
                         :gift_card_total, :display_gift_card_total,
                         :amount_due, :display_amount_due

        # Read off the group's own payments. A child reports zero for these:
        # the one payment a split checkout took belongs to the group, so only
        # the group can say what store credit or a gift card covered.
        attribute :store_credit_total do |group|
          group.total_applied_store_credit.to_s unless params[:hide_prices]
        end

        attribute :display_store_credit_total do |group|
          group.display_total_applied_store_credit.to_s unless params[:hide_prices]
        end

        attribute :covered_by_store_credit, &:covered_by_store_credit?

        # Rolled up across the children rather than stored, so it can never
        # disagree with the orders it describes.
        attributes :fulfillment_status, :payment_status

        attribute :completed_at do |group|
          group.created_at
        end

        one :billing_address, resource: proc { Spree.api.address_serializer }
        one :shipping_address, resource: proc { Spree.api.address_serializer }

        # The card itself is deliberately not nested here — the split copies it
        # onto every child, so it is already in the payload, and a group this
        # deep pushes the generated Zod schema past what TypeScript will
        # serialize into a declaration file. `gift_card_total` is the figure a
        # summary needs, and only the group can answer it.

        # How the customer paid. The payment is made once, against the group,
        # so this is the only place a split checkout's payments are reachable —
        # without it a confirmation could not say what card was charged.
        many :payments, resource: proc { Spree.api.payment_serializer }

        # The whole point of the group: the customer sees one purchase, and the
        # seller orders inside it are how it will arrive.
        many :orders, resource: proc { Spree.api.order_serializer }
      end
    end
  end
end

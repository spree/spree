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
                 fulfillment_status: [:string, nullable: true, enum: Spree::Order::FULFILLMENT_STATUSES, enum_type_name: 'OrderFulfillmentStatus'],
                 payment_status: [:string, nullable: true, enum: Spree::Order::PAYMENT_STATUSES, enum_type_name: 'OrderPaymentStatus'],
                 completed_at: [:string, nullable: true],
                 billing_address: { nullable: true }, shipping_address: { nullable: true }

        attributes :number, :email, :currency

        # Every figure is rolled up from the children, never prorated back
        # down. The payments are the group's own: a split checkout pays once,
        # against the group, so a child holds none.
        include Spree::Api::V3::PurchaseSummary

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

        # The whole point of the group: the customer sees one purchase, and the
        # seller orders inside it are how it will arrive.
        many :orders, resource: proc { Spree.api.order_serializer }
      end
    end
  end
end

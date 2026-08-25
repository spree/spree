module Spree
  module Api
    module V3
      module Seller
        # An order placed with this seller.
        #
        # Built from the base rather than the store serializer: that one is
        # written for the shopper who placed the order, and carries payments —
        # how the customer paid the marketplace is not the seller's business,
        # and what they are owed is the commission ledger, not this.
        #
        # The customer's contact details are here because the seller packs and
        # posts the parcel, so they need the address and a way to reach the
        # buyer about it.
        class OrderSerializer < V3::BaseSerializer
          typelize number: :string,
                   email: [:string, nullable: true],
                   customer_note: [:string, nullable: true],
                   currency: :string,
                   total_quantity: :number,
                   fulfillment_status: [:string, nullable: true],
                   payment_status: [:string, nullable: true],
                   status: :string

          attributes :number, :email, :customer_note, :currency, :total_quantity,
                     :status, :fulfillment_status, :payment_status,
                     completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          # What this seller is owed for the goods, and what the buyer paid for
          # them. Deliberately not the whole money surface: gift cards, store
          # credit and the payment breakdown belong to the marketplace.
          money_attributes :item_total, :display_item_total,
                           :tax_total, :display_tax_total,
                           :total, :display_total

          many :line_items, key: :items, resource: proc { Spree.api.seller_order_line_item_serializer }
          many :fulfillments, resource: proc { Spree.api.seller_fulfillment_serializer }
          one :shipping_address, resource: proc { Spree.api.address_serializer }
          one :billing_address, resource: proc { Spree.api.address_serializer }
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::OrderGroup for the back office — the checkout that
        # produced several orders, and what ties them together.
        #
        # Extends the store serializer, so what a customer sees stays in one
        # place and this adds only what an operator needs on top: the payment
        # shares, and the timestamps every admin surface carries.
        class OrderGroupSerializer < V3::OrderGroupSerializer
          typelize customer_id: 'string | null',
                   cart_id: 'string | null',
                   seller_count: :number,
                   includes_first_party: :boolean,
                   created_at: :string, updated_at: :string

          attribute :customer_id do |group|
            group.customer&.prefixed_id
          end

          attribute :cart_id do |group|
            Spree::Cart.prefixed_id_for(group.cart_id)
          end

          # How many sellers this checkout reached — the operator's headline
          # question about a group, and cheaper than counting the orders client
          # side once a group is large.
          attribute :seller_count do |group|
            group.seller_count
          end

          attribute :includes_first_party do |group|
            group.includes_first_party?
          end

          attributes :created_at, :updated_at

          # Re-declared against the admin serializers. Inheriting the store
          # ones would render a customer-facing record inside a back-office
          # response, which is the one thing an admin serializer must never do.
          one :billing_address, resource: proc { Spree.api.admin_address_serializer }
          one :shipping_address, resource: proc { Spree.api.admin_address_serializer }
          many :orders, resource: proc { Spree.api.admin_order_serializer }
          many :payments, resource: proc { Spree.api.admin_payment_serializer }
        end
      end
    end
  end
end

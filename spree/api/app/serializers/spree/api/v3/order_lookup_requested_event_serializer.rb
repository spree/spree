module Spree
  module Api
    module V3
      # The event shape for `order.lookup_requested`: what a storefront needs to
      # email a guest the link to their order itself. `order_token` opens the
      # order, so the event reaches only endpoints that name it.
      class OrderLookupRequestedEventSerializer < BaseSerializer
        typelize email: :string, number: :string, order_token: :string, store_id: [:string, nullable: true]

        attributes :email, :number

        attribute :order_token, &:token

        attribute :store_id do |order|
          order.store&.prefixed_id
        end
      end
    end
  end
end

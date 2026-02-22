# frozen_string_literal: true

module Spree
  module Events
    class PaymentSessionSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          status: resource.status.to_s,
          amount: money(resource.amount),
          currency: resource.currency,
          external_id: resource.external_id,
          order_id: public_id(resource.order),
          payment_method_id: public_id(resource.payment_method),
          customer_id: public_id(resource.customer),
          expires_at: timestamp(resource.expires_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

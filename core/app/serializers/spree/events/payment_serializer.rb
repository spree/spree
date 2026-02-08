# frozen_string_literal: true

module Spree
  module Events
    class PaymentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          state: resource.state.to_s,
          amount: money(resource.amount),
          order_id: public_id(resource.order),
          payment_method_id: public_id(resource.payment_method),
          source_type: resource.source_type,
          source_id: public_id(resource.source),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

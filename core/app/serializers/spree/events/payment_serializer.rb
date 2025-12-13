# frozen_string_literal: true

module Spree
  module Events
    class PaymentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          state: resource.state.to_s,
          amount: money(resource.amount),
          order_id: resource.order_id,
          payment_method_id: resource.payment_method_id,
          source_type: resource.source_type,
          source_id: resource.source_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

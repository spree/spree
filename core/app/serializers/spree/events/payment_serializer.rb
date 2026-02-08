# frozen_string_literal: true

module Spree
  module Events
    class PaymentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          state: resource.state.to_s,
          amount: money(resource.amount),
          order_id: association_prefix_id(:order),
          payment_method_id: association_prefix_id(:payment_method),
          source_type: resource.source_type,
          source_id: association_prefix_id(:source),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

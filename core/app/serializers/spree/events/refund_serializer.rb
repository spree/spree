# frozen_string_literal: true

module Spree
  module Events
    class RefundSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          amount: money(resource.amount),
          transaction_id: resource.transaction_id,
          payment_id: association_prefix_id(:payment),
          refund_reason_id: association_prefix_id(:reason),
          reimbursement_id: association_prefix_id(:reimbursement),
          refunder_id: association_prefix_id(:refunder),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

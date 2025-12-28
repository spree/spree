# frozen_string_literal: true

module Spree
  module Events
    class RefundSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          amount: money(resource.amount),
          transaction_id: resource.transaction_id,
          payment_id: resource.payment_id,
          refund_reason_id: resource.refund_reason_id,
          reimbursement_id: resource.reimbursement_id,
          refunder_id: resource.refunder_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

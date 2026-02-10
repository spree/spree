# frozen_string_literal: true

module Spree
  module Events
    class RefundSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          amount: money(resource.amount),
          transaction_id: resource.transaction_id,
          payment_id: public_id(resource.payment),
          refund_reason_id: public_id(resource.reason),
          reimbursement_id: public_id(resource.reimbursement),
          refunder_id: public_id(resource.refunder),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

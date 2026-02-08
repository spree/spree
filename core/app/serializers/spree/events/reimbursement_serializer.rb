# frozen_string_literal: true

module Spree
  module Events
    class ReimbursementSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          reimbursement_status: resource.reimbursement_status,
          total: money(resource.total),
          order_id: public_id(resource.order),
          customer_return_id: public_id(resource.customer_return),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

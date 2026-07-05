# frozen_string_literal: true

module Spree
  module Api
    module V3
      class RefundSerializer < BaseSerializer
        typelize amount: [:string, nullable: true], transaction_id: [:string, nullable: true],
                 payment_id: [:string, nullable: true], refund_reason_id: [:string, nullable: true],
                 reimbursement_id: [:string, nullable: true]

        attributes :transaction_id

        attribute :amount do |refund|
          refund.amount&.to_s
        end

        attribute :payment_id do |refund|
          refund.payment&.prefixed_id
        end

        attribute :refund_reason_id do |refund|
          refund.reason&.prefixed_id
        end

        attribute :reimbursement_id do |refund|
          refund.reimbursement&.prefixed_id
        end
      end
    end
  end
end
